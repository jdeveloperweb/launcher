package com.prognum.gateway.documentos.port.out;

import java.nio.file.Path;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import com.prognum.gateway.documentos.model.UploadChunkado;

/**
 * Port de saída do staging de upload chunked (Doc Final de Requisitos: armazenamento temporário
 * seguro + tolerância a falhas). Implementação típica grava um diretório por upload, um arquivo por
 * bloco recebido — permite retomar (reenviar só os blocos faltantes) e limpar por idade.
 */
public interface RepositorioUploadChunked {

    void iniciar(UploadChunkado sessao);

    Optional<UploadChunkado> metadados(String uploadId);

    void gravarBloco(String uploadId, int numero, byte[] dados);

    Set<Integer> blocosRecebidos(String uploadId);

    long bytesRecebidos(String uploadId);

    /**
     * Monta os blocos (em ordem) num único arquivo temporário e devolve o caminho — a montagem é
     * feita em DISCO (streaming), nunca carregando o arquivo inteiro em memória, para suportar
     * arquivos grandes (>10GB) sem risco de OutOfMemory nesta etapa.
     */
    Path montar(String uploadId);

    /** Remove o staging (blocos + metadados) de um upload — usado no concluir/abortar e na limpeza. */
    void remover(String uploadId);

    /** IDs de uploads com staging em disco (para o job de limpeza varrer por idade). */
    List<String> idsExistentes();
}
