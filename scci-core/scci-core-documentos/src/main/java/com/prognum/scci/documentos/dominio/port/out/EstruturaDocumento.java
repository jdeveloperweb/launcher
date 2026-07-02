package com.prognum.scci.documentos.dominio.port.out;

/**
 * Operações de ESTRUTURA/metadados do SISTARQ — porte de PutNome/PutPasta do apiscci:
 * renomear (UPDATE SISTARQ.NOME, com guardas de TIPO) e criar pasta (INSERT SISTARQ TIPO=1).
 */
public interface EstruturaDocumento {

    /** PutNome: renomeia o nó {@code id}. Recusa raiz/Lixeira(TIPO=3)/aba Documentos(TIPO=0). */
    void renomear(int id, String novoNome, String ambiente);

    /** PutPasta: cria uma pasta (TIPO=1) sob {@code idPai}. Devolve o id da pasta criada. */
    int criarPasta(int idPai, String nome, boolean exibePastas, String ambiente);
}
