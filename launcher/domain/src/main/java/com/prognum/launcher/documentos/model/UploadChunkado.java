package com.prognum.launcher.documentos.model;

/**
 * Doc Final de Requisitos (Upload/Download): metadados de uma sessão de upload em blocos (chunked),
 * criada em {@code iniciar} e usada em cada bloco recebido / na montagem final. {@code corpoBinario}
 * do {@code ComandoExecucao} final é montado a partir dos blocos gravados no staging (ver
 * {@link com.prognum.launcher.documentos.port.out.RepositorioUploadChunked}).
 */
public record UploadChunkado(
        String id,
        String nomeArquivo,
        long tamanhoTotalBytes,
        int tamanhoBlocoBytes,
        int totalBlocos,
        String ambiente,
        String usuario,
        String programName,
        String methodName,
        String requestMethod,
        String paramsJson,
        String ip,
        long criadoEmEpochMs) {
}
