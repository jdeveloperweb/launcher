package com.prognum.scci.documentos.domain.port.in;

import com.prognum.scci.documentos.domain.Documento;

/**
 * Leitura de documento por ENTIDADE de negócio (resolve o id no SISTARQ e transmite o binário):
 * {@code porOperacao} = GetDocumentoOperacao/…Assinatura; {@code porSisat} = GetDocumentoSisat.
 */
public interface BaixarDocumentoEntidade {

    Documento porOperacao(String nuPretendente, String nuDocumento, boolean caseSensitive,
                          boolean download, String ambiente);

    Documento porSisat(int nuOcorrencia, String nuDocumento, boolean download, String ambiente);
}
