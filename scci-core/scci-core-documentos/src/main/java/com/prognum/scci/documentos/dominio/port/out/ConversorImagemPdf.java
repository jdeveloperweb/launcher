package com.prognum.scci.documentos.dominio.port.out;

/**
 * Conversão imagem→PDF do wdoc (ARISP: {@code /usr/bin/convert} do ImageMagick), como HOOK externo. Se o
 * arquivo for imagem e a conversão estiver ligada, devolve o PDF; senão devolve o conteúdo original. A
 * impl default é pass-through (não converte) até plugar o ImageMagick real.
 */
public interface ConversorImagemPdf {

    /** {nome/conteúdo} → PDF se for imagem e a conversão estiver habilitada; senão o próprio conteúdo. */
    Resultado converter(byte[] conteudo, String nome);

    /** Resultado: bytes (possivelmente convertidos) + nome (extensão pode virar .pdf). */
    record Resultado(byte[] conteudo, String nome) {
    }
}
