package com.prognum.scci.documentos.dominio.port.out;

/**
 * Grava uma versão binária de um documento EXISTENTE no SISTARQ — porte de GravaBinarioVersao/
 * InsereVersaoBinario/VerificaCriterios (wsistarqlib): decide (pelas flags IN_CRIA_VERSAO_ATUALIZADA/
 * IN_CONTROLE_VERSAO do SISTARQ) entre inserir uma NOVA versão (MAX(VERSAO)+1) ou atualizar a última, e
 * grava em CONTROLEVERSAO ({@code DADO} BLOB + zlib). Devolve a versão gravada.
 *
 * Escopo: storage em BANCO (DB-blob), documento já existente. FileSystem/S3 e a CRIAÇÃO de um documento
 * novo (nó novo na árvore SISTARQ) ficam fora deste port (ponto de extensão).
 */
public interface ArmazenadorDocumento {

    /** Grava uma nova versão de um documento EXISTENTE (id conhecido). Devolve a versão gravada. */
    int gravarVersao(int id, String nome, byte[] conteudo, String usuario, String ambiente);

    /**
     * Upload por PASTA (PostDocumento/InsereArquivoVersao): acha o documento {@code nome} sob {@code idPai}
     * ou CRIA um nó novo no SISTARQ (TIPO=2, herdando as flags da pasta-pai), e grava a versão binária.
     * Devolve o ID do documento (novo ou existente) — o {@code ID_INSERIDO} do wdoc.
     */
    int inserirArquivoVersao(int idPai, String nome, byte[] conteudo, String usuario, String ambiente);
}
