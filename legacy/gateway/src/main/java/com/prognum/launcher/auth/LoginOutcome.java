package com.prognum.launcher.auth;

/**
 * Catalogo formal de estados de login (regras.md secao 1.1 / nossa doc secao 21).
 * Formaliza todos os desfechos possiveis do login do launcher legado em um enum,
 * para a API responder de forma padronizada (em vez de apenas success|fail).
 */
public enum LoginOutcome {

    OK("Login efetuado", true),
    SENHA_VAI_EXPIRAR("Sua senha expira em breve", true),   // aviso, mas login permitido

    SENHA_INCORRETA("Usuario ou senha invalidos", false),   // mesma msg p/ inexistente e senha errada (hardening)
    USUARIO_INATIVO("Usuario inativo, acesso nao permitido", false),
    SENHA_EXPIRADA("Senha/conta expirada", false),
    TROCA_OBRIGATORIA("E necessario trocar a senha", false),
    SENHA_EM_BRANCO("Senha em branco", false),
    BLOQUEADO("Usuario bloqueado por tentativas", false),
    CAPTCHA_OBRIGATORIO("Captcha obrigatorio", false),
    LIMITE_ACESSOS("Limite de acessos simultaneos atingido", false),

    SENHA_FRACA("A senha nao atende a politica", false),     // troca de senha
    SENHA_JA_USADA("Esta senha ja foi usada anteriormente", false);

    public final String mensagem;
    public final boolean sucesso;

    LoginOutcome(String mensagem, boolean sucesso) {
        this.mensagem = mensagem;
        this.sucesso = sucesso;
    }
}
