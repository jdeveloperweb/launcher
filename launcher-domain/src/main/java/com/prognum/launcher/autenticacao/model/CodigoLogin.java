package com.prognum.launcher.autenticacao.model;

/**
 * Catálogo FORMAL dos estados de login do SCCI (TestaUsuario do loginbd.pas + hardening). O contrato
 * com o front continua sendo o <b>caractere</b> ({@code codigo()}) — este enum só dá nome, descrição e
 * a flag de sucesso a cada estado, para consumo seguro (documentação/OpenAPI, logs, testes).
 */
public enum CodigoLogin {

    OK('T', true, "Login efetuado com sucesso."),
    AVISO_EXPIRACAO('C', true, "Login OK — a senha vai expirar em breve."),
    EXPIRADA('E', false, "Conta ou senha expirada."),
    TROCA_OBRIGATORIA('M', false, "Troca de senha obrigatória no próximo acesso."),
    SENHA_BRANCA('B', false, "Senha em branco — defina uma senha."),
    INVALIDO('F', false, "Usuário ou senha inválidos."),
    CAPTCHA('K', false, "Captcha obrigatório (excesso de tentativas)."),
    BLOQUEADO('X', false, "Usuário bloqueado por excesso de tentativas.");

    private final char codigo;
    private final boolean sucesso;
    private final String descricao;

    CodigoLogin(char codigo, boolean sucesso, String descricao) {
        this.codigo = codigo;
        this.sucesso = sucesso;
        this.descricao = descricao;
    }

    public char codigo() {
        return codigo;
    }

    public boolean sucesso() {
        return sucesso;
    }

    public String descricao() {
        return descricao;
    }

    /** Do caractere do contrato para o estado nomeado. */
    public static CodigoLogin de(char codigo) {
        for (CodigoLogin c : values()) {
            if (c.codigo == codigo) {
                return c;
            }
        }
        throw new IllegalArgumentException("codigo de login desconhecido: " + codigo);
    }
}
