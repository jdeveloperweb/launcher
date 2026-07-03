package com.prognum.scci.acesso.dominio.port.out;

/**
 * Port de saida: verificacao e geracao de hash de senha.
 *  - matches: confere senha contra hash (bcrypt $2 ou md5crypt $1$ do loginbd).
 *  - gerarHashMd5Crypt: gera o hash md5crypt ($1$<salt>$) para GRAVAR na troca de senha.
 * Mantem o algoritmo fora da camada de aplicacao (infra).
 */
public interface VerificadorSenha {

    boolean matches(String senha, String hash);

    String gerarHashMd5Crypt(String senha);
}
