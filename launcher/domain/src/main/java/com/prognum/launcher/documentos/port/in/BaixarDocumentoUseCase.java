package com.prognum.launcher.documentos.port.in;

import com.prognum.launcher.documentos.model.RespostaDocumento;
import com.prognum.launcher.execucao.model.ComandoExecucao;

/**
 * Port de entrada do canal de DOCUMENTOS (sccidoc): despacha para o programa (ex.: wdoc.getDoc) e
 * devolve o arquivo (binario + metadados) ou o texto/JSON de resposta.
 */
public interface BaixarDocumentoUseCase {

    RespostaDocumento baixar(ComandoExecucao comando);
}
