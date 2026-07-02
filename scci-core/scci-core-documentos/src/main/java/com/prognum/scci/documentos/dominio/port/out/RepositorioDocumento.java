package com.prognum.scci.documentos.dominio.port.out;

import java.util.Optional;

import com.prognum.scci.documentos.dominio.ArquivoBruto;

/**
 * Port de saída do storage de documentos — porte do {@code GetDocumentoPorId} do apilib.pas (a leitura do
 * SISTARQ/controleversao). O adapter resolve a ÚLTIMA versão, materializa o binário (BLOB no banco,
 * filesystem ou S3) e o descomprime quando {@code compactado}; devolve nome + bytes prontos. Vazio quando
 * o id não existe.
 */
public interface RepositorioDocumento {

    /** Última versão do documento {@code id} no ambiente, já resolvida e descomprimida. */
    Optional<ArquivoBruto> buscarUltimaVersao(int id, String ambiente);
}
