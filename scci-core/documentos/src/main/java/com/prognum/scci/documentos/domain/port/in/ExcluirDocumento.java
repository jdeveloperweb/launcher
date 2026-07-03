package com.prognum.scci.documentos.domain.port.in;

/** Caso de uso: excluir um documento (todas as versões) — porte do DeleteDocumento/ExcluiItem do wdoc/apilib. */
public interface ExcluirDocumento {

    void excluir(int id, String ambiente);
}
