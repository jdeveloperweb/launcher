package com.prognum.gateway.documentos.port.in;

import com.prognum.gateway.execucao.model.ComandoExecucao;

import java.util.List;

/**
 * Caso de uso de UPLOAD de documentos (canal sccidoc / putDoc). Fiel ao DoMultiPartRemoteCall do
 * sccidoc.pas: uma chamada ao programa POR ARQUIVO do multipart, cada uma com os params (XML PMEMORY
 * com prefixo de tamanho) + os bytes do arquivo anexados. Devolve o corpo JSON de cada chamada, na
 * ordem dos arquivos (o adapter de entrada junta as respostas como o CGI faz).
 */
public interface EnviarDocumentoUseCase {

    List<String> enviar(List<ComandoExecucao> arquivos);
}
