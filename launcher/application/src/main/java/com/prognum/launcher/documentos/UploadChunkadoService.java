package com.prognum.launcher.documentos;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import com.prognum.launcher.documentos.model.UploadChunkado;
import com.prognum.launcher.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.launcher.documentos.port.in.UploadChunkadoUseCase;
import com.prognum.launcher.documentos.port.out.RepositorioUploadChunked;
import com.prognum.launcher.execucao.model.ComandoExecucao;

/**
 * Doc Final de Requisitos (Upload/Download): orquestra o upload em blocos — inicia a sessão de
 * staging, recebe cada bloco, reporta progresso e, na conclusão, monta o arquivo e entrega ao MESMO
 * {@link EnviarDocumentoUseCase} do upload de hoje (reaproveita toda a validação/roteamento
 * Strangler existentes). POJO puro, testável com fakes.
 *
 * <p><b>Limite conhecido (documentado, não escondido):</b> a montagem final em disco é streaming
 * (sem risco de OutOfMemory nesta etapa, ver {@link RepositorioUploadChunked#montar}), mas a entrega
 * ao {@code EnviarDocumentoUseCase} exige carregar o arquivo montado em um único {@code byte[]}
 * (limite do {@link ComandoExecucao#corpoBinario()}, usado por TODO o pipeline de documentos hoje —
 * Pascal/wdoc e scci-core/JDBC BLOB). Streaming verdadeiro de ponta a ponta para arquivos >10GB
 * exigiria rever esses dois pipelines (fora do escopo desta mudança) — TODO para uma iniciativa
 * separada. Por isso {@code tamanhoMaximoBytes} deve ser calibrado pela equipe de operação conforme
 * o heap disponível no processo.</p>
 */
public class UploadChunkadoService implements UploadChunkadoUseCase {

    private final RepositorioUploadChunked staging;
    private final EnviarDocumentoUseCase envio;
    private final long tamanhoMaximoBytes;
    private final int tamanhoBlocoMaximoBytes;
    private final Set<String> extensoesPermitidas;
    private final SecureRandom rnd = new SecureRandom();

    public UploadChunkadoService(RepositorioUploadChunked staging, EnviarDocumentoUseCase envio,
                                 long tamanhoMaximoBytes, int tamanhoBlocoMaximoBytes,
                                 Set<String> extensoesPermitidas) {
        this.staging = staging;
        this.envio = envio;
        this.tamanhoMaximoBytes = tamanhoMaximoBytes;
        this.tamanhoBlocoMaximoBytes = tamanhoBlocoMaximoBytes;
        this.extensoesPermitidas = extensoesPermitidas == null ? Set.of() : extensoesPermitidas;
    }

    @Override
    public ResultadoIniciarUpload iniciar(IniciarUploadComando c) {
        if (c.tamanhoTotalBytes() <= 0 || c.tamanhoTotalBytes() > tamanhoMaximoBytes) {
            throw new ArquivoMuitoGrande(c.tamanhoTotalBytes(), tamanhoMaximoBytes);
        }
        validarExtensao(c.nomeArquivo());

        int bloco = c.tamanhoBlocoBytesSolicitado() > 0
                ? Math.min(c.tamanhoBlocoBytesSolicitado(), tamanhoBlocoMaximoBytes)
                : tamanhoBlocoMaximoBytes;
        int totalBlocos = (int) Math.ceil(c.tamanhoTotalBytes() / (double) bloco);
        String id = novoId();

        staging.iniciar(new UploadChunkado(id, c.nomeArquivo(), c.tamanhoTotalBytes(), bloco, totalBlocos,
                c.ambiente(), c.usuario(), c.programName(), c.methodName(), c.requestMethod(),
                c.paramsJson(), c.ip(), System.currentTimeMillis()));

        return new ResultadoIniciarUpload(id, bloco, totalBlocos);
    }

    @Override
    public ResultadoBloco receberBloco(String uploadId, int numero, byte[] dados) {
        UploadChunkado meta = metadadosOuFalha(uploadId);
        if (numero < 0 || numero >= meta.totalBlocos()) {
            throw new BlocoInvalido(numero, meta.totalBlocos());
        }
        staging.gravarBloco(uploadId, numero, dados);
        long total = staging.bytesRecebidos(uploadId);
        boolean completo = staging.blocosRecebidos(uploadId).size() >= meta.totalBlocos();
        return new ResultadoBloco(numero, total, completo);
    }

    @Override
    public ResultadoStatus status(String uploadId) {
        UploadChunkado meta = metadadosOuFalha(uploadId);
        int recebidos = staging.blocosRecebidos(uploadId).size();
        return new ResultadoStatus(staging.bytesRecebidos(uploadId), meta.tamanhoTotalBytes(),
                recebidos, meta.totalBlocos(), recebidos >= meta.totalBlocos());
    }

    @Override
    public String concluir(String uploadId) {
        UploadChunkado meta = metadadosOuFalha(uploadId);
        int recebidos = staging.blocosRecebidos(uploadId).size();
        if (recebidos < meta.totalBlocos()) {
            throw new UploadIncompleto(uploadId, recebidos, meta.totalBlocos());
        }

        Path montado = staging.montar(uploadId);
        try {
            // Ver limite documentado na Javadoc da classe: materializa em byte[] aqui porque
            // ComandoExecucao/ExecutorPrograma/JDBC BLOB (pipeline existente) sao byte[]-based.
            byte[] conteudo = Files.readAllBytes(montado);
            ComandoExecucao cmd = new ComandoExecucao(meta.ambiente(), meta.programName(), meta.methodName(),
                    meta.requestMethod(), meta.paramsJson(), meta.usuario(), meta.ip(), true, conteudo);
            List<String> respostas = envio.enviar(List.of(cmd));
            return respostas.isEmpty()
                    ? "{\"success\":false,\"message\":\"Sem resposta do programa.\"}"
                    : respostas.get(0);
        } catch (java.io.IOException e) {
            throw new IllegalStateException("falha ao ler o arquivo montado do upload " + uploadId, e);
        } finally {
            staging.remover(uploadId);
        }
    }

    @Override
    public void abortar(String uploadId) {
        staging.remover(uploadId);
    }

    private UploadChunkado metadadosOuFalha(String uploadId) {
        return staging.metadados(uploadId).orElseThrow(() -> new UploadNaoEncontrado(uploadId));
    }

    private void validarExtensao(String nomeArquivo) {
        if (extensoesPermitidas.isEmpty()) {
            return;
        }
        String nome = nomeArquivo == null ? "" : nomeArquivo;
        int p = nome.lastIndexOf('.');
        String ext = p < 0 ? "" : nome.substring(p + 1).toLowerCase(Locale.ROOT);
        if (!extensoesPermitidas.contains(ext)) {
            throw new ExtensaoNaoPermitida(ext);
        }
    }

    private String novoId() {
        byte[] b = new byte[16];
        rnd.nextBytes(b);
        return java.util.HexFormat.of().formatHex(b);
    }
}
