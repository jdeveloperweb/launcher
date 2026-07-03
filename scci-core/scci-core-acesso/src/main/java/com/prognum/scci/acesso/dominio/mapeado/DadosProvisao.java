package com.prognum.scci.acesso.dominio.mapeado;

/**
 * Resultado de uma estratégia de provisionamento (a parte específica de cada loginXXX payload-mapeado).
 * {@code usuarioEfetivo} é a grafia real do usuário na base (login case-insensitive) — o legado devolve
 * isso ao front via {@code 'T'+token+':'+Usuario}; aqui vira o NO_USUARIO da sessão e o USER injetado.
 * {@code sessionToken} é o token gerado (GeraToken) que vira a SESSION_KEY.
 */
public record DadosProvisao(String usuarioEfetivo, String sessionToken) {
}
