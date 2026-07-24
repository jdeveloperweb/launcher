package com.prognum.pascal.model;

/**
 * Comando para EXECUTAR um programa "w" (papel do launcher). rawJson = o JSON original do front
 * (preserva null/numeros); os campos de roteamento sao removidos antes de virar o bloco DATA.
 *
 * streamComTamanho: true para o canal de DOCUMENTOS (metodos TStream do apilib — GetErroExec,
 * GetRelGerados, GetRotinaLogs...), que leem os params com {@code LoadFromStreamWithSize}, ou seja,
 * o bloco DATA precisa ser [tamanho(4, little-endian)][XML PMEMORY]. No /w normal (metodos TPXML)
 * fica false: os params vao como XML cru (LoadFromStream, sem prefixo).
 *
 * corpoBinario: quando != null (UPLOAD/putDoc), o bloco DATA vira
 * [tamanho(4, little-endian)][XML PMEMORY] + [bytes do arquivo] — fiel ao DoMultiPartRemoteCall do
 * sccidoc.pas (writeAnsiString(Params.Code) + writeBuffer(binario)). Implica size-prefix nos params.
 */
public record ComandoExecucao(
        String ambiente,
        String programName,
        String methodName,
        String requestMethod,
        String rawJson,
        String usuario,
        String ip,
        boolean streamComTamanho,
        byte[] corpoBinario) {

    /** Canal /w normal (TPXML): params como XML cru, sem prefixo de tamanho. */
    public ComandoExecucao(String ambiente, String programName, String methodName,
                           String requestMethod, String rawJson, String usuario, String ip) {
        this(ambiente, programName, methodName, requestMethod, rawJson, usuario, ip, false, null);
    }

    /** Canal DOCUMENTOS download (TStream): params com prefixo de tamanho, sem binario anexado. */
    public ComandoExecucao(String ambiente, String programName, String methodName,
                           String requestMethod, String rawJson, String usuario, String ip,
                           boolean streamComTamanho) {
        this(ambiente, programName, methodName, requestMethod, rawJson, usuario, ip, streamComTamanho, null);
    }
}
