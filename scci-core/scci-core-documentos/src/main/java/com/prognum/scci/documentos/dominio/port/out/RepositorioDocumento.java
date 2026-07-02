package com.prognum.scci.documentos.dominio.port.out;

import java.util.Optional;

import com.prognum.scci.documentos.dominio.ArquivoBruto;

/**
 * Port de saída do storage de documentos — porte fiel dos acessos do apilib.pas (SISTARQ/controleversao).
 * O adapter resolve/materializa/descomprime o binário e devolve nome + bytes prontos. Vazio quando não existe.
 */
public interface RepositorioDocumento {

    /** Última versão do documento {@code id} (GetDocumentoPorId). */
    Optional<ArquivoBruto> buscarUltimaVersao(int id, String ambiente);

    /** Uma versão específica do documento {@code id} (GetDocumentoPorIdVersao: {@code c.versao = ?}). */
    Optional<ArquivoBruto> buscarVersao(int id, int versao, String ambiente);

    /** Remove o documento e todas as versões (ExcluiItem: delete controleversao + sistarq por id). */
    void excluir(int id, String ambiente);
}
