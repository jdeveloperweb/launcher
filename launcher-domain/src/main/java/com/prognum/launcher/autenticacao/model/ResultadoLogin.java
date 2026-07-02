package com.prognum.launcher.autenticacao.model;

/**
 * Resultado do login. codErro segue o loginbd.pas: T=ok, C=vai expirar, E=expirada, M=troca,
 * B=branco, F=incorreta, K=captcha, X=bloqueado. Copia fiel do WcopLoginService.Resultado.
 *
 * {@code usuarioEfetivo} é a grafia real do usuário na base (login case-insensitive nos clientes
 * payload-mapeado); null quando não se aplica (o caller usa o usuário informado). O legado devolve
 * isso via {@code 'T'+token+':'+Usuario}.
 */
public record ResultadoLogin(boolean sucesso, char codErro, String sessionKey,
                             String mensagem, Integer diasRestantes, String usuarioEfetivo) {

    /** Compat: a maioria dos autenticadores não corrige a grafia do usuário (usuarioEfetivo=null). */
    public ResultadoLogin(boolean sucesso, char codErro, String sessionKey,
                          String mensagem, Integer diasRestantes) {
        this(sucesso, codErro, sessionKey, mensagem, diasRestantes, null);
    }
}
