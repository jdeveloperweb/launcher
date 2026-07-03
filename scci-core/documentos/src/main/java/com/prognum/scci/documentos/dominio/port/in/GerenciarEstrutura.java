package com.prognum.scci.documentos.dominio.port.in;

/** Casos de uso de estrutura de documentos (PutNome/PutPasta do wdoc): renomear e criar pasta. */
public interface GerenciarEstrutura {

    void renomear(int id, String novoNome, String ambiente);

    int criarPasta(int idPai, String nome, boolean exibePastas, String ambiente);
}
