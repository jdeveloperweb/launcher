package com.prognum.launcher.documentos.port.in;

/**
 * Doc Final de Requisitos (Upload/Download): upload em blocos (chunking) para arquivos grandes
 * (>10GB), com armazenamento temporário, monitoramento de progresso e tolerância a falhas (o cliente
 * pode consultar {@link #status} e reenviar só os blocos faltantes).
 *
 * <p><b>Nota de escopo:</b> esta é uma PROPOSTA de contrato — endpoint novo e aditivo, não substitui
 * o {@code POST /sccidoc} existente (que preserva o contrato byte-a-byte do front). O contrato aqui
 * ainda não foi validado com o front-end (fora deste repositório); ajustar se necessário antes de
 * expor em produção.</p>
 */
public interface UploadChunkadoUseCase {

    ResultadoIniciarUpload iniciar(IniciarUploadComando comando);

    ResultadoBloco receberBloco(String uploadId, int numero, byte[] dados);

    ResultadoStatus status(String uploadId);

    /** Monta os blocos, entrega ao fluxo normal de envio (mesma allow-list/anti-malware/roteamento
     *  Strangler do upload de hoje) e limpa o staging. Devolve o corpo de resposta do programa. */
    String concluir(String uploadId);

    void abortar(String uploadId);

    record IniciarUploadComando(
            String ambiente,
            String usuario,
            String ip,
            String programName,
            String methodName,
            String requestMethod,
            String paramsJson,
            String nomeArquivo,
            long tamanhoTotalBytes,
            int tamanhoBlocoBytesSolicitado) {
    }

    record ResultadoIniciarUpload(String uploadId, int tamanhoBlocoBytes, int totalBlocos) {
    }

    record ResultadoBloco(int numero, long bytesTotalRecebidos, boolean completo) {
    }

    record ResultadoStatus(long bytesTotalRecebidos, long bytesTotalEsperado,
                           int blocosRecebidos, int totalBlocos, boolean completo) {
    }

    class UploadNaoEncontrado extends RuntimeException {
        public UploadNaoEncontrado(String uploadId) {
            super("Upload nao encontrado (expirado, concluido ou id invalido): " + uploadId);
        }
    }

    class ArquivoMuitoGrande extends RuntimeException {
        public ArquivoMuitoGrande(long tamanho, long maximo) {
            super("Tamanho do arquivo (" + tamanho + " bytes) excede o maximo configurado (" + maximo + " bytes).");
        }
    }

    class BlocoInvalido extends RuntimeException {
        public BlocoInvalido(int numero, int totalBlocos) {
            super("Numero de bloco invalido: " + numero + " (esperado 0.." + (totalBlocos - 1) + ")");
        }
    }

    class UploadIncompleto extends RuntimeException {
        public UploadIncompleto(String uploadId, int recebidos, int total) {
            super("Upload " + uploadId + " incompleto: " + recebidos + "/" + total + " blocos recebidos.");
        }
    }

    class ExtensaoNaoPermitida extends RuntimeException {
        public ExtensaoNaoPermitida(String extensao) {
            super("Extensao de arquivo nao permitida: " + (extensao == null || extensao.isBlank() ? "(sem extensao)" : "." + extensao));
        }
    }
}
