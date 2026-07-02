package com.prognum.scci.documentos.dominio.port.in;

import com.prognum.scci.documentos.dominio.Documento;

/**
 * Casos de uso de LEITURA de documento (a família Get exposta pelo wdoc que resolve um id e transmite o
 * binário): {@code baixar} = última versão (GetDocumento / GetDocumentoContratoAssinatura, este com
 * download); {@code baixarVersao} = versão específica (GetDocumentoVersao). Devolvem um {@link Documento}
 * idiomático (bytes + mime), sem o framing Pascal.
 */
public interface BaixarDocumento {

    Documento baixar(int id, boolean download, String ambiente);

    Documento baixarVersao(int id, int versao, boolean download, String ambiente);
}
