package com.prognum.launcher.documentos.rest;

import java.util.Map;
import java.util.Optional;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.prognum.common.crypto.LogAnonimizador;
import com.prognum.launcher.autenticacao.model.Sessao;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.ArquivoMuitoGrande;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.BlocoInvalido;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.ExtensaoNaoPermitida;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.IniciarUploadComando;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.ResultadoBloco;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.ResultadoIniciarUpload;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.ResultadoStatus;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.UploadIncompleto;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase.UploadNaoEncontrado;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Doc Final de Requisitos (Upload/Download): upload em blocos (chunking) para arquivos grandes
 * (>10GB) — armazenamento temporário, monitoramento de progresso e tolerância a falhas (reenviar só
 * os blocos faltantes).
 *
 * <p><b>Endpoint ADITIVO/PROPOSTO:</b> não substitui {@code POST /sccidoc} (que preserva o contrato
 * byte-a-byte do front hoje). Este contrato ainda não foi validado com quem consome (front-end, fora
 * deste repositório) — tratar como proposta até essa validação, antes de expor em produção real.</p>
 *
 * <p>Fluxo: {@code POST .../iniciar} → N × {@code PUT .../blocos/{numero}} → (opcional)
 * {@code GET .../status} → {@code POST .../concluir} (ou {@code DELETE} para abortar).</p>
 *
 * <p>Autorização: a sessão é validada em {@code iniciar} (igual ao {@code /sccidoc} hoje). O
 * {@code uploadId} devolvido é um token aleatório de 128 bits — funciona como capability para as
 * chamadas seguintes (bloco/status/concluir/abortar), sem repetir a validação de sessão completa a
 * cada bloco (mesmo padrão de outros protocolos de upload resumível). Decisão deliberada: revisar se
 * o modelo de ameaça exigir revalidação por chamada.</p>
 */
@Tag(name = "Upload Chunked (proposta)", description = "Upload em blocos para arquivos grandes — endpoint "
        + "ADITIVO, ainda não validado com o front-end. Não substitui POST /sccidoc.")
@RestController
@RequestMapping("/sccidoc/upload-chunked")
public class UploadChunkadoController {

    private static final Logger log = LoggerFactory.getLogger(UploadChunkadoController.class);

    private final ObjectMapper mapper;
    private final SessaoUseCase sessoes;
    private final UploadChunkadoUseCase uploads;

    public UploadChunkadoController(ObjectMapper mapper, SessaoUseCase sessoes, UploadChunkadoUseCase uploads) {
        this.mapper = mapper;
        this.sessoes = sessoes;
        this.uploads = uploads;
    }

    @Operation(summary = "Inicia uma sessão de upload em blocos",
            description = "Valida sessão, tamanho/extensão; devolve uploadId (capability) e tamanho de bloco.")
    @PostMapping("/iniciar")
    public ResponseEntity<String> iniciar(@RequestBody Map<String, Object> body, HttpServletRequest req) {
        String sessionKey = texto(body, "sessionKey");
        String usuarioParam = texto(body, "userName", "usuario");
        String ambienteParam = texto(body, "ambienteOperacional", "ambiente");

        Optional<Sessao> s = sessoes.validar(sessionKey, usuarioParam, ambienteParam);
        if (sessionKey != null && s.isEmpty()) {
            return erro(401, "Sessao expirada. Faca login novamente.");
        }
        String usuario = s.map(Sessao::usuario).orElse(usuarioParam);
        String ambiente = s.map(Sessao::ambienteOperacional).orElse(ambienteParam);

        String programName = texto(body, "programName", "programa");
        String methodName = texto(body, "methodName", "metodo");
        String requestMethod = texto(body, "requestMethod");
        if (requestMethod == null) {
            requestMethod = "POST";
        }
        String fileName = texto(body, "fileName", "nomeArquivo");
        long tamanhoTotal = numero(body, "tamanhoTotalBytes");
        int tamanhoBloco = (int) numero(body, "tamanhoBlocoBytes");
        String paramsJson = montaParamsJson(body, fileName);

        try {
            ResultadoIniciarUpload r = uploads.iniciar(new IniciarUploadComando(ambiente, usuario,
                    req.getRemoteAddr(), programName, methodName, requestMethod, paramsJson, fileName,
                    tamanhoTotal, tamanhoBloco));
            log.info("upload_chunked_iniciado", kv("uploadId", r.uploadId()), kv("arquivo", fileName),
                    kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                    kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                    kv("tamanhoTotalBytes", tamanhoTotal));
            return ResponseEntity.ok("{\"success\":true,\"uploadId\":\"" + r.uploadId()
                    + "\",\"tamanhoBlocoBytes\":" + r.tamanhoBlocoBytes()
                    + ",\"totalBlocos\":" + r.totalBlocos() + "}");
        } catch (ArquivoMuitoGrande | ExtensaoNaoPermitida e) {
            return erro(400, e.getMessage());
        }
    }

    @Operation(summary = "Envia um bloco do arquivo",
            description = "Idempotente por número de bloco — reenviar o mesmo número sobrescreve (retomada após falha).")
    @PutMapping("/{uploadId}/blocos/{numero}")
    public ResponseEntity<String> bloco(@PathVariable String uploadId, @PathVariable int numero,
                                        @RequestBody byte[] dados) {
        try {
            ResultadoBloco r = uploads.receberBloco(uploadId, numero, dados == null ? new byte[0] : dados);
            return ResponseEntity.ok("{\"success\":true,\"numero\":" + r.numero()
                    + ",\"bytesTotalRecebidos\":" + r.bytesTotalRecebidos()
                    + ",\"completo\":" + r.completo() + "}");
        } catch (UploadNaoEncontrado e) {
            return erro(404, e.getMessage());
        } catch (BlocoInvalido e) {
            return erro(400, e.getMessage());
        }
    }

    @Operation(summary = "Consulta o progresso de um upload em andamento")
    @GetMapping("/{uploadId}/status")
    public ResponseEntity<String> status(@PathVariable String uploadId) {
        try {
            ResultadoStatus s = uploads.status(uploadId);
            return ResponseEntity.ok("{\"success\":true,\"bytesTotalRecebidos\":" + s.bytesTotalRecebidos()
                    + ",\"bytesTotalEsperado\":" + s.bytesTotalEsperado()
                    + ",\"blocosRecebidos\":" + s.blocosRecebidos()
                    + ",\"totalBlocos\":" + s.totalBlocos()
                    + ",\"completo\":" + s.completo() + "}");
        } catch (UploadNaoEncontrado e) {
            return erro(404, e.getMessage());
        }
    }

    @Operation(summary = "Conclui o upload",
            description = "Monta os blocos e entrega ao mesmo fluxo de envio do upload direto "
                    + "(herda allow-list de extensões e roteamento Pascal/scci-core). Falha se algum bloco faltar.")
    @PostMapping("/{uploadId}/concluir")
    public ResponseEntity<String> concluir(@PathVariable String uploadId) {
        try {
            String resposta = uploads.concluir(uploadId);
            log.info("upload_chunked_concluido", kv("uploadId", uploadId));
            return ResponseEntity.ok(resposta);
        } catch (UploadNaoEncontrado e) {
            return erro(404, e.getMessage());
        } catch (UploadIncompleto e) {
            return erro(409, e.getMessage());
        }
    }

    @Operation(summary = "Aborta o upload e limpa o staging")
    @DeleteMapping("/{uploadId}")
    public ResponseEntity<Void> abortar(@PathVariable String uploadId) {
        uploads.abortar(uploadId);
        return ResponseEntity.noContent().build();
    }

    /** JSON de params do arquivo (mesmo padrão do SccidocController): campos base + FileName. */
    private String montaParamsJson(Map<String, Object> base, String nomeArquivo) {
        ObjectNode obj = mapper.createObjectNode();
        base.forEach((k, v) -> {
            if (v != null) {
                obj.put(k, v.toString());
            }
        });
        obj.put("FileName", nomeArquivo == null ? "" : nomeArquivo);
        return obj.toString();
    }

    private static ResponseEntity<String> erro(int status, String mensagem) {
        String msg = mensagem == null ? "" : mensagem.replace("\\", "\\\\").replace("\"", "\\\"");
        return ResponseEntity.status(status).body("{\"success\":false,\"message\":\"" + msg + "\"}");
    }

    private static String texto(Map<String, Object> m, String... chaves) {
        for (String k : chaves) {
            Object v = m.get(k);
            if (v != null && !v.toString().isBlank()) {
                return v.toString();
            }
        }
        return null;
    }

    private static long numero(Map<String, Object> m, String chave) {
        Object v = m.get(chave);
        if (v instanceof Number n) {
            return n.longValue();
        }
        try {
            return v == null ? 0 : Long.parseLong(v.toString());
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
