package com.prognum.scci.documentos.domain;

/**
 * Documento do domínio — representação <b>idiomática em Java</b> (não o framing Pascal
 * {@code [len][XML][binário]}, que é só transporte e fica na borda do launcher).
 *
 * <ul>
 *   <li>{@code nome}     : nome do arquivo (ex.: {@code relatorio.pdf});</li>
 *   <li>{@code tipoMime} : content-type real (ex.: {@code application/pdf});</li>
 *   <li>{@code conteudo} : os bytes crus do documento;</li>
 *   <li>{@code download} : se o front deve baixar (attachment) em vez de exibir inline.</li>
 * </ul>
 *
 * Objeto de valor imutável. A ORIGEM dos bytes (blob em banco, arquivo em disco, ou geração por
 * relatório) fica atrás do port {@code RepositorioDocumento} — a ser implementado conforme o wdoc real.
 */
public record Documento(String nome, String tipoMime, byte[] conteudo, boolean download) {

    public Documento {
        if (nome == null || nome.isBlank()) {
            throw new IllegalArgumentException("documento sem nome");
        }
        if (conteudo == null) {
            throw new IllegalArgumentException("documento sem conteudo");
        }
    }

    public int tamanho() {
        return conteudo.length;
    }
}
