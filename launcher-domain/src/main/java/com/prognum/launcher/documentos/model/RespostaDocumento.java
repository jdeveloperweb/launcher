package com.prognum.launcher.documentos.model;

/**
 * Resposta do canal de documentos (sccidoc). O programa devolve metadados (Tipo/Nome/DOW) + o
 * conteudo binario do arquivo; ou, quando nao e arquivo, um texto/JSON. Erro vem embrulhado.
 *
 *  - erro=true    -> textoErro tem o JSON de erro ({"success":false,"message":...}).
 *  - arquivo=true -> tipo/nome/download/conteudo (streaming binario com mime + Content-Disposition).
 *  - senao        -> texto (JSON/texto de passagem).
 */
public record RespostaDocumento(
        boolean erro,
        boolean arquivo,
        String tipo,        // extensao, ex.: ".PDF"
        String nome,        // nome do arquivo
        boolean download,   // attachment (baixar) vs inline (exibir)
        byte[] conteudo,    // bytes do arquivo (quando arquivo=true)
        String texto        // resposta texto/JSON (quando arquivo=false ou erro)
) {
}
