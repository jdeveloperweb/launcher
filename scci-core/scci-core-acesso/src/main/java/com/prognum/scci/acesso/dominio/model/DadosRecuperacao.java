package com.prognum.scci.acesso.dominio.model;

/**
 * Dados do usuario + SMTP da entidade para a recuperacao de senha (ExecutaEmailPwd do loginbd.pas):
 * CPF cadastrado, e-mail de destino e as credenciais SMTP da entidade primaria do usuario.
 */
public record DadosRecuperacao(String cpf, String email, String smtpHost,
                               String smtpUsuario, String smtpSenha) {
}
