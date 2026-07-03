package com.prognum.scci.acesso.domain.mapeado;

/**
 * Dados para o provisionamento JIT (Just-In-Time) de um USUARIO novo no SCCI — o INSERT que
 * loginitau/loginc6/loginailos fazem quando o usuário autenticado no IdP ainda não existe na base.
 * {@code entSecundaria} é opcional (só ailos usa; nulo => coluna nula). {@code noAutenticacaoAd} idem
 * (só c6). {@code senhaToken} é o token gerado (o legado grava o token na coluna SENHA — nunca usada
 * para login nesses clientes, mas a coluna é NOT NULL).
 */
public record NovoUsuario(
        String usuario,
        int perfPrimario,
        int entPrimaria,
        Integer entSecundaria,
        String coSetor,
        String nome,
        String senhaToken,
        String noAutenticacaoAd) {
}
