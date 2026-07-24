package com.prognum.gateway.documentos.port.in;

import com.prognum.gateway.documentos.model.RespostaDocumento;
import com.prognum.gateway.execucao.model.ComandoExecucao;

/**
 * Port de entrada do canal de DOCUMENTOS (sccidoc): despacha para o programa (ex.: wdoc.getDoc) e
 * devolve o arquivo (binario + metadados) ou o texto/JSON de resposta.
 */
public interface BaixarDocumentoUseCase {

    RespostaDocumento baixar(ComandoExecucao comando);
}
