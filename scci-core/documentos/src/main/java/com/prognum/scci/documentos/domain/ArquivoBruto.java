package com.prognum.scci.documentos.domain;

/**
 * Arquivo já RESOLVIDO do storage: nome + bytes prontos (descomprimidos e materializados, venham eles
 * de BLOB no banco, filesystem ou S3). Toda a complexidade de "onde/como está guardado" fica no adapter
 * de saída ({@code RepositorioDocumento}); o domínio só recebe nome + conteúdo.
 */
public record ArquivoBruto(String nome, byte[] conteudo) {

    public ArquivoBruto {
        if (nome == null) {
            nome = "";
        }
        if (conteudo == null) {
            conteudo = new byte[0];
        }
    }
}
