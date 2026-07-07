package com.prognum.launcher.documentos.rest;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.prognum.launcher.autenticacao.model.Sessao;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.common.crypto.LogAnonimizador;
import com.prognum.common.crypto.WcopCrypto;
import com.prognum.launcher.documentos.model.RespostaDocumento;
import com.prognum.launcher.documentos.port.in.BaixarDocumentoUseCase;
import com.prognum.launcher.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.launcher.execucao.model.ComandoExecucao;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.MultipartHttpServletRequest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter de entrada do dominio DOCUMENTOS — canal /sccidoc (equivalente ao CGI sccidoc.pas do SCCI).
 * Diferente do /w (que devolve JSON), aqui a resposta pode ser um ARQUIVO (streaming binario com
 * Content-Type por extensao + Content-Disposition). Feito do jeito Java (Spring cuida do streaming).
 *
 * <p><b>Doc Final de Requisitos (Upload/Download):</b> allow-list de extensões
 * ({@code launcher.documentos.extensoes-permitidas}) aplicada aqui, na borda — é o único ponto de
 * entrada de upload independente de qual backend (Pascal ou scci-core) a feature-flag escolher.</p>
 */
@Tag(name = "SCCIDOC", description = "Canal de documentos (getDoc/putDoc) — integração SCCIDOC/wcorp. "
        + "Protocolo W_COP (AES no request, XOR na resposta); corpo binário do arquivo nunca é cifrado.")
@RestController
public class SccidocController {

    private static final Logger log = LoggerFactory.getLogger(SccidocController.class);

    private final ObjectMapper mapper;
    private final WcopCrypto crypto;
    private final SessaoUseCase sessoes;
    private final BaixarDocumentoUseCase documentos;
    private final EnviarDocumentoUseCase envio;
    private final Set<String> extensoesPermitidas;
    // Doc Final de Requisitos (2.9.3): fora do modo dev, a requisicao deve ser cifrada (W_COP).
    // Aplicado so no /sccidoc JSON (metodo sccidoc()) -- NAO no upload multipart (sccidocUpload):
    // ali a cifragem e por header opcional "application-data", com fallback documentado para
    // form/query fields (fluxo ja validado ao vivo); forcar cifrado ali arriscaria quebrar upload
    // real em producao sem necessidade, ja que a sessao e validada da mesma forma nos dois casos.
    private final boolean exigirCifrado;

    public SccidocController(ObjectMapper mapper, WcopCrypto crypto, SessaoUseCase sessoes,
                            BaixarDocumentoUseCase documentos, EnviarDocumentoUseCase envio,
                            @Value("${launcher.documentos.extensoes-permitidas:}") String[] extensoesPermitidas,
                            @Value("${launcher.wcop.exigir-cifrado:false}") boolean exigirCifrado) {
        this.mapper = mapper;
        this.crypto = crypto;
        this.sessoes = sessoes;
        this.documentos = documentos;
        this.envio = envio;
        this.extensoesPermitidas = Arrays.stream(extensoesPermitidas)
                .map(e -> e.trim().toLowerCase(Locale.ROOT))
                .filter(e -> !e.isEmpty())
                .collect(Collectors.toSet());
        this.exigirCifrado = exigirCifrado;
    }

    @Operation(summary = "getDoc/putDoc via JSON (canal principal)",
            description = "Corpo JSON cifrado (W_COP) com programName/methodName/sessionKey/ambienteOperacional. "
                    + "Resposta: arquivo binário (Content-Type/Content-Disposition conforme o documento) ou JSON de erro.")
    @PostMapping("/sccidoc")
    public ResponseEntity<byte[]> sccidoc(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String rawAscii = body == null ? "" : new String(body, StandardCharsets.ISO_8859_1);
        boolean cifrado = crypto.estaCifrado(rawAscii);
        if (exigirCifrado && !cifrado && body != null && body.length > 0) {
            log.info("wcop_nao_cifrado_rejeitado");
            return resposta(false,
                    "{\"success\":false,\"message\":\"Requisicao deve ser cifrada (W_COP).\",\"codigo\":\"E006\"}");
        }
        String json = cifrado ? crypto.decifraRequest(rawAscii)
                : (body == null || body.length == 0 ? "{}" : new String(body, StandardCharsets.UTF_8));

        Map<String, String> in = camposDoJson(json);
        String programName = primeiro(in, "programName", "programa");
        String methodName = primeiro(in, "methodName", "metodo");
        // Fiel ao sccidoc.pas: default do requestMethod = metodo HTTP (POST); o front faz override
        // com "GET" no corpo para leituras (RelGerados/ErroExec/RotinaLogs).
        String requestMethod = primeiro(in, "requestMethod");
        if (requestMethod == null) {
            requestMethod = req.getMethod();
        }
        String sessionKey = primeiro(in, "sessionKey");
        String usuarioParam = primeiro(in, "userName", "usuario");
        String ambienteParam = primeiro(in, "ambienteOperacional", "ambiente");

        // VALIDA (igual ao /w): revalida a sessao antes de executar.
        Optional<Sessao> s = sessoes.validar(sessionKey, usuarioParam, ambienteParam);
        if (sessionKey != null && s.isEmpty()) {
            return resposta(cifrado,
                    "{\"success\":false,\"message\":\"Sessao expirada. Faca login novamente.\",\"codigo\":\"E004\"}");
        }
        String usuario = s.map(Sessao::usuario).orElse(usuarioParam);
        String ambiente = s.map(Sessao::ambienteOperacional).orElse(ambienteParam);

        log.info("sccidoc", kv("programName", programName), kv("methodName", methodName),
                kv("requestMethod", requestMethod), kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)), kv("sessaoValida", s.isPresent()));

        // streamComTamanho=true: canal de documentos usa metodos TStream (LoadFromStreamWithSize),
        // logo o bloco DATA precisa ir com prefixo de tamanho [LE32][XML PMEMORY].
        RespostaDocumento d = documentos.baixar(new ComandoExecucao(
                ambiente, programName, methodName, requestMethod, json, usuario, req.getRemoteAddr(), true));
        // Doc Final de Requisitos (2.9.5/regra 9): falha de arquivo -> HTML (nao so no GET de
        // navegacao). htmlEmErro so tem efeito quando cifrado==false (ver respostaDocumento): um
        // request CIFRADO espera resposta cifrada (XOR); nao ha como "cifrar HTML" nesse esquema
        // sem quebrar o decode do front, entao nesse caso o erro continua JSON cifrado.
        return respostaDocumento(d, cifrado, true);
    }

    /**
     * VIEW/DOWNLOAD de documento — porte do fluxo AbrirUrl do SCCI: GET de navegador para
     * {@code /sccidoc/{programa}/{metodo}[/...]?params-na-query}. Fiel ao sccidoc.pas: programa/metodo
     * vem do PATH (DecodeProgramNameAndMethod), params da QUERY STRING, e a auth (userName/sessionKey/
     * ambiente) de COOKIES (com fallback para query). requestMethod = GET (metodo HTTP). Segmentos
     * extras apos o metodo sao ignorados (como o DecodeProgramNameAndMethod, que so pega prog e metodo).
     */
    @Operation(summary = "Visualização/download direto pelo navegador (AbrirUrl)",
            description = "Auth via cookie (sessionKey/userName/ambienteOperacional), sem W_COP. "
                    + "Falha de arquivo (não encontrado/corrompido) devolve HTML simples, não JSON.")
    @GetMapping({"/sccidoc/{programa}/{metodo}", "/sccidoc/{programa}/{metodo}/**"})
    public ResponseEntity<byte[]> sccidocView(@PathVariable String programa, @PathVariable String metodo,
                                              HttpServletRequest req) {
        Map<String, String> in = queryParaMapa(req);
        String sessionKey = cookieOuParam(req, in, "sessionKey");
        String usuarioParam = cookieOuParam(req, in, "userName", "usuario");
        String ambienteParam = cookieOuParam(req, in, "ambienteOperacional", "ambiente");

        Optional<Sessao> s = sessoes.validar(sessionKey, usuarioParam, ambienteParam);
        if (sessionKey != null && s.isEmpty()) {
            return resposta(false,
                    "{\"success\":false,\"message\":\"Sessao expirada. Faca login novamente.\",\"codigo\":\"E004\"}");
        }
        String usuario = s.map(Sessao::usuario).orElse(usuarioParam);
        String ambiente = s.map(Sessao::ambienteOperacional).orElse(ambienteParam);

        // os params do programa vem da query string -> vira o rawJson (XML PMEMORY size-prefixed)
        ObjectNode obj = mapper.createObjectNode();
        in.forEach(obj::put);
        String json = obj.toString();

        log.info("sccidoc_view", kv("programName", programa), kv("methodName", metodo),
                kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)), kv("sessaoValida", s.isPresent()));

        // requestMethod=GET (e um GET de navegador) -> Get<metodo>
        RespostaDocumento d = documentos.baixar(new ComandoExecucao(
                ambiente, programa, metodo, "GET", json, usuario, req.getRemoteAddr(), true));
        // Doc Final de Requisitos (2.9.5/regra 9): falha de arquivo -> HTML. Aqui cifrado e sempre
        // false (navegacao direta do browser nunca usa W_COP), entao o HTML sempre se aplica.
        return respostaDocumento(d, false, true);
    }

    /** Monta a resposta HTTP a partir do RespostaDocumento: arquivo (mime+disposition) ou JSON. */
    private ResponseEntity<byte[]> respostaDocumento(RespostaDocumento d, boolean cifrado) {
        return respostaDocumento(d, cifrado, false);
    }

    /**
     * @param htmlEmErro Doc Final de Requisitos (2.9.5/regra 9): falha de ARQUIVO (documento não
     *                   encontrado/corrompido) devolve HTML simples em vez de JSON. Só tem efeito
     *                   quando {@code cifrado==false}: uma resposta cifrada (XOR) não pode carregar
     *                   HTML puro sem quebrar o decode do front, então nesse caso o erro continua
     *                   JSON cifrado (contrato W_COP preservado).
     */
    private ResponseEntity<byte[]> respostaDocumento(RespostaDocumento d, boolean cifrado, boolean htmlEmErro) {
        if (d.erro()) {
            if (htmlEmErro && !cifrado) {
                return paginaErroHtml(d.texto());
            }
            return resposta(cifrado, d.texto());                    // erro do programa -> JSON
        }
        if (d.arquivo()) {
            String disposicao = (d.download() ? "attachment; " : "") + "filename=\"" + nomeSeguro(d.nome()) + "\"";
            // Doc Final de Requisitos (2.9.6): auditoria do documento servido -- metadados apenas,
            // NUNCA o conteudo.
            log.info("sccidoc_documento_servido", kv("extensao", d.tipo()),
                    kv("tamanhoBytes", d.conteudo() == null ? 0 : d.conteudo().length),
                    kv("nomeArquivo", d.nome()), kv("download", d.download()));
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, mime(d.tipo()))
                    .header(HttpHeaders.CONTENT_DISPOSITION, disposicao)
                    .body(d.conteudo());                            // arquivo binario RAW (sccidoc nao cifra o arquivo)
        }
        return resposta(cifrado, d.texto());                        // texto/JSON de passagem
    }

    /**
     * UPLOAD de documentos (multipart/form-data) — porte do DoMultiPartRemoteCall do sccidoc.pas.
     * Uma chamada ao programa POR ARQUIVO, com [LE32 tamanho][XML PMEMORY + FileName] + [bytes]; as
     * respostas JSON sao juntadas (success/message/dados). Os params (userName/sessionKey/ambiente/
     * programName/methodName/requestMethod) vem do header cifrado "application-data" (como o
     * HTTP_APPLICATION_DATA do CGI), com fallback para form fields / query params / headers nomeados.
     */
    @Operation(summary = "putDoc via multipart/form-data (upload)",
            description = "Um POST por arquivo internamente (fiel ao DoMultiPartRemoteCall). Params via header "
                    + "'application-data' (cifrado, prioridade) ou form/query/header nomeado (fallback). "
                    + "Extensão validada contra allow-list configurável antes do envio ao backend.")
    @PostMapping(value = "/sccidoc", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<byte[]> sccidocUpload(MultipartHttpServletRequest req) {
        // params: header "application-data" (cifrado ____ => decifra) tem prioridade, senao form/query/header
        Map<String, String> in = new LinkedHashMap<>();
        boolean cifrado = false;
        String appData = req.getHeader("application-data");
        if (appData == null) {
            appData = req.getHeader("Application-Data");
        }
        if (appData != null && crypto.estaCifrado(appData)) {
            in.putAll(camposDoJson(crypto.decifraRequest(appData)));
            cifrado = true;
        }

        String programName = paramOuHeader(req, in, "programName", "programa");
        String methodName = paramOuHeader(req, in, "methodName", "metodo");
        // Fiel ao sccidoc.pas: RequestMethod := GetEnv('REQUEST_METHOD') (default = metodo HTTP,
        // POST no multipart) e so entao override por Params['requestMethod']. Sem isso o verbo nao
        // era prefixado -> "DocumentoOperacao" em vez de "PostDocumentoOperacao" (upload).
        String requestMethod = paramOuHeader(req, in, "requestMethod");
        if (requestMethod == null) {
            requestMethod = req.getMethod();
        }
        String sessionKey = paramOuHeader(req, in, "sessionKey");
        String usuarioParam = paramOuHeader(req, in, "userName", "usuario");
        String ambienteParam = paramOuHeader(req, in, "ambienteOperacional", "ambiente");

        Optional<Sessao> s = sessoes.validar(sessionKey, usuarioParam, ambienteParam);
        if (sessionKey != null && s.isEmpty()) {
            return resposta(cifrado,
                    "{\"success\":false,\"message\":\"Sessao expirada. Faca login novamente.\",\"codigo\":\"E004\"}");
        }
        String usuario = s.map(Sessao::usuario).orElse(usuarioParam);
        String ambiente = s.map(Sessao::ambienteOperacional).orElse(ambienteParam);

        // um ComandoExecucao por arquivo do multipart (fiel ao laco do DoMultiPartRemoteCall)
        List<ComandoExecucao> comandos = new ArrayList<>();
        int totalArquivos = 0;
        long totalBytes = 0;
        List<String> extensoesEnviadas = new ArrayList<>();
        Iterator<String> nomes = req.getFileNames();
        while (nomes.hasNext()) {
            for (MultipartFile mf : req.getFiles(nomes.next())) {
                if (mf.isEmpty()) {
                    continue;
                }
                totalArquivos++;
                if (!extensaoPermitida(mf.getOriginalFilename())) {
                    log.info("sccidoc_upload_rejeitado", kv("arquivo", mf.getOriginalFilename()),
                            kv("motivo", "extensao_nao_permitida"),
                            kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                            kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                            kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)));
                    return resposta(cifrado, "{\"success\":false,\"message\":\"Extensao de arquivo nao permitida.\"}");
                }
                byte[] bytes;
                try {
                    bytes = mf.getBytes();
                } catch (IOException e) {
                    return resposta(cifrado, "{\"success\":false,\"message\":\"Falha lendo arquivo enviado.\"}");
                }
                totalBytes += bytes.length;
                extensoesEnviadas.add(extensaoDe(mf.getOriginalFilename()));
                String paramsJson = montaParamsUpload(in, mf.getOriginalFilename());
                comandos.add(new ComandoExecucao(ambiente, programName, methodName, requestMethod,
                        paramsJson, usuario, req.getRemoteAddr(), true, bytes));
            }
        }

        if (comandos.isEmpty()) {
            return resposta(cifrado, "{\"success\":false,\"message\":\"Nenhum arquivo enviado.\"}");
        }
        List<String> respostas = envio.enviar(comandos);
        String corpo = juntaRespostas(respostas);
        // Doc Final de Requisitos (2.9.6): auditoria do upload -- tamanho total e extensoes, nunca o
        // conteudo dos arquivos.
        log.info("sccidoc_upload", kv("programName", programName), kv("methodName", methodName),
                kv("arquivos", totalArquivos), kv("tamanhoTotalBytes", totalBytes),
                kv("extensoes", String.join(",", extensoesEnviadas)),
                kv("usuario", LogAnonimizador.pseudonimizarUsuario(usuario)),
                kv("ip", LogAnonimizador.mascararIp(req.getRemoteAddr())),
                kv("sessaoId", LogAnonimizador.pseudonimizarSessao(sessionKey)), kv("sessaoValida", s.isPresent()),
                kv("cifrado", cifrado), kv("temAppData", appData != null),
                kv("respostaPrefixo", corpo.length() > 60 ? corpo.substring(0, 60) : corpo));
        return resposta(cifrado, corpo);
    }

    /** Extensão (com o ponto, minúscula) de um nome de arquivo enviado — só para fins de auditoria/log. */
    private static String extensaoDe(String nomeArquivo) {
        if (nomeArquivo == null) {
            return "";
        }
        int p = nomeArquivo.lastIndexOf('.');
        return p < 0 ? "" : nomeArquivo.substring(p).toLowerCase(Locale.ROOT);
    }

    /**
     * Allow-list de extensões (Doc Final de Requisitos): vazia = sem restrição (mantém compat);
     * não-vazia = extensão do arquivo (ou ausência dela) precisa estar na lista configurada.
     */
    private boolean extensaoPermitida(String nomeArquivo) {
        if (extensoesPermitidas.isEmpty()) {
            return true;
        }
        String nome = nomeArquivo == null ? "" : nomeArquivo;
        int p = nome.lastIndexOf('.');
        String ext = p < 0 ? "" : nome.substring(p + 1).toLowerCase(Locale.ROOT);
        return extensoesPermitidas.contains(ext);
    }

    /** Monta o JSON de params de um arquivo: os campos base do request + FileName (nome original). */
    private String montaParamsUpload(Map<String, String> base, String nomeArquivo) {
        ObjectNode obj = mapper.createObjectNode();
        base.forEach(obj::put);
        obj.put("FileName", nomeArquivo == null ? "" : nomeArquivo.replace("\\", "/")
                .substring(nomeArquivo.replace("\\", "/").lastIndexOf('/') + 1));
        return obj.toString();
    }

    /**
     * Junta as respostas por-arquivo como o DoMultiPartRemoteCall: success (ultimo vence), message
     * (primeira nao-vazia) e dados (concatenados). Uma resposta so -> devolve verbatim.
     */
    private String juntaRespostas(List<String> brutas) {
        List<String> respostas = new ArrayList<>(brutas.size());
        for (String r : brutas) {
            respostas.add(desembrulhaTamanho(r));   // tira o [LE32 tamanho] do SaveToStreamWithSize
        }
        List<JsonNode> jsons = new ArrayList<>();
        for (String r : respostas) {
            try {
                JsonNode n = mapper.readTree(r);
                if (n != null && n.isObject()) {
                    jsons.add(n);
                }
            } catch (Exception ignore) {
                // resposta nao-JSON: ignora na juncao
            }
        }
        if (jsons.isEmpty()) {
            return respostas.isEmpty() ? "{\"success\":false,\"message\":\"Sem resposta do programa.\"}"
                    : respostas.get(respostas.size() - 1);
        }
        if (jsons.size() == 1) {
            return jsons.get(0).toString();
        }
        ObjectNode out = mapper.createObjectNode();
        ArrayNode dados = out.putArray("dados");
        for (JsonNode n : jsons) {
            if (n.has("success")) {
                out.put("success", n.get("success").asBoolean());
            }
            if (n.has("message") && !out.has("message") && !n.get("message").asText().isBlank()) {
                out.put("message", n.get("message").asText());
            }
            JsonNode d = n.get("dados");
            if (d != null && d.isArray()) {
                d.forEach(dados::add);
            } else if (d != null) {
                dados.add(d);
            }
        }
        return out.toString();
    }

    /**
     * Remove o prefixo [tamanho(4, little-endian)] que os metodos TStream escrevem na resposta
     * (ListaOut.SaveToStreamWithSize). Fiel ao ReadAnsiString que o DoMultiPartRemoteCall faz: le o
     * tamanho e devolve so os N bytes seguintes. Se nao houver prefixo valido, devolve como veio.
     */
    static String desembrulhaTamanho(String r) {   // package-private p/ teste
        if (r == null) {
            return "";
        }
        byte[] b = r.getBytes(StandardCharsets.ISO_8859_1);
        if (b.length >= 4) {
            int len = (b[0] & 0xFF) | ((b[1] & 0xFF) << 8) | ((b[2] & 0xFF) << 16) | ((b[3] & 0xFF) << 24);
            if (len >= 0 && 4 + len <= b.length) {
                return new String(b, 4, len, StandardCharsets.ISO_8859_1);
            }
        }
        return r;
    }

    /** Params da query string (1o valor de cada). */
    private static Map<String, String> queryParaMapa(HttpServletRequest req) {
        Map<String, String> m = new LinkedHashMap<>();
        req.getParameterMap().forEach((k, v) -> {
            if (v != null && v.length > 0) {
                m.put(k, v[0]);
            }
        });
        return m;
    }

    /** Auth do GET de navegador (AbrirUrl): cookie -> query param (fiel ao sccidoc.pas que le cookies). */
    private static String cookieOuParam(HttpServletRequest req, Map<String, String> query, String... chaves) {
        Cookie[] cookies = req.getCookies();
        for (String k : chaves) {
            if (cookies != null) {
                for (Cookie c : cookies) {
                    if (c.getName().equalsIgnoreCase(k) && c.getValue() != null && !c.getValue().isBlank()) {
                        return c.getValue();
                    }
                }
            }
            String v = query.get(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
        }
        return null;
    }

    /** Valor de um param: form field / query (getParameter cobre ambos) -> header nomeado -> mapa base. */
    private static String paramOuHeader(MultipartHttpServletRequest req, Map<String, String> base, String... chaves) {
        for (String k : chaves) {
            String v = req.getParameter(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
            v = req.getHeader(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
            v = base.get(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
        }
        return null;
    }

    /** Content-Type pela extensao (subset dos mimes do sccidoc.pas). */
    static String mime(String tipo) {   // package-private p/ teste
        String ext = tipo == null ? "" : tipo.toUpperCase();
        return switch (ext) {
            case ".PDF" -> "application/pdf";
            case ".XML" -> "application/xml";
            case ".TEXT/XML" -> "text/xml";
            case ".JPG", ".JPEG" -> "image/jpeg";
            case ".PNG" -> "image/png";
            case ".GIF" -> "image/gif";
            case ".BMP" -> "image/bmp";
            case ".TIF", ".TIFF" -> "image/tiff";
            case ".HTM", ".HTML" -> "text/html";
            case ".TXT", ".BASE64" -> "text/plain";
            case ".CSV" -> "text/csv";
            case ".RTF" -> "text/rtf";
            case ".ZIP" -> "application/zip";
            case ".DOC", ".DOT" -> "application/msword";
            case ".DOCX" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            case ".XLS", ".XLT", ".XLA" -> "application/vnd.ms-excel";
            case ".XLSX" -> "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            case ".PPT", ".POT", ".PPS", ".PPA" -> "application/vnd.ms-powerpoint";
            case ".PPTX" -> "application/vnd.openxmlformats-officedocument.presentationml.presentation";
            case ".ODT" -> "application/vnd.oasis.opendocument.text";
            case ".ODS" -> "application/vnd.oasis.opendocument.spreadsheet";
            default -> "application/octet-stream";
        };
    }

    private static String nomeSeguro(String nome) {
        return nome == null ? "documento" : nome.replace("\"", "").replace("\r", "").replace("\n", "");
    }

    private ResponseEntity<byte[]> resposta(boolean cifrado, String json) {
        if (cifrado) {
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_TYPE, "application/json; charset=ISO-8859-1")
                    .body(crypto.cifraResposta(json));
        }
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_TYPE, "application/json; charset=UTF-8")
                .body(json.getBytes(StandardCharsets.UTF_8));
    }

    /**
     * Doc Final de Requisitos (Upload/Download): página HTML simples para falha de arquivo no GET de
     * navegação direta do browser (ver {@link #sccidocView}). {@code jsonErro} é o JSON de erro do
     * programa ({@code {"success":false,"message":"..."}}) — extrai só a mensagem para exibição.
     */
    private ResponseEntity<byte[]> paginaErroHtml(String jsonErro) {
        String mensagem = "Nao foi possivel abrir o documento.";
        try {
            JsonNode n = mapper.readTree(jsonErro);
            if (n != null && n.hasNonNull("message") && !n.get("message").asText().isBlank()) {
                mensagem = n.get("message").asText();
            }
        } catch (Exception ignore) {
            // usa a mensagem padrao
        }
        String html = "<!DOCTYPE html><html><head><meta charset=\"UTF-8\">"
                + "<title>Documento indisponivel</title></head><body>"
                + "<h1>Documento indisponivel</h1><p>" + escaparHtml(mensagem) + "</p></body></html>";
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .header(HttpHeaders.CONTENT_TYPE, "text/html; charset=UTF-8")
                .body(html.getBytes(StandardCharsets.UTF_8));
    }

    private static String escaparHtml(String s) {
        return s == null ? "" : s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    /**
     * Doc Final de Requisitos (Upload/Download): falha de INFRA (arquivo maior que o limite do
     * Spring, lançada antes de chegar ao controller) devolve JSON estruturado -- não a página
     * whitelabel padrão do Spring. Aplica-se aos fluxos POST (upload), que continuam JSON.
     */
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<byte[]> uploadMuitoGrande(MaxUploadSizeExceededException e) {
        log.info("sccidoc_upload_rejeitado", kv("motivo", "tamanho_excedido"));
        return resposta(false, "{\"success\":false,\"message\":\"Arquivo excede o tamanho maximo permitido.\"}");
    }

    private Map<String, String> camposDoJson(String json) {
        Map<String, String> m = new LinkedHashMap<>();
        try {
            JsonNode node = mapper.readTree(json);
            if (node != null && node.isObject()) {
                node.fields().forEachRemaining(e -> m.put(e.getKey(), e.getValue().asText()));
            }
        } catch (Exception ignore) {
            // corpo nao-JSON
        }
        return m;
    }

    private static String primeiro(Map<String, String> m, String... chaves) {
        for (String k : chaves) {
            String v = m.get(k);
            if (v != null && !v.isBlank()) {
                return v;
            }
        }
        return null;
    }
}
