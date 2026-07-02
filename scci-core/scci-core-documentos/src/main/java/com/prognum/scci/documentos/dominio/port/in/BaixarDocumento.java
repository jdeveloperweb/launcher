package com.prognum.scci.documentos.dominio.port.in;

import com.prognum.scci.documentos.dominio.Documento;

/**
 * Caso de uso: baixar/visualizar um documento pelo id (a última versão). {@code download=true} marca como
 * anexo (attachment); false = inline. Corresponde ao GetDocumento/GetDocumentoPorId do wdoc, mas devolvendo
 * um {@link Documento} idiomático (bytes + mime), sem o framing Pascal.
 */
public interface BaixarDocumento {

    Documento baixar(int id, boolean download, String ambiente);
}
