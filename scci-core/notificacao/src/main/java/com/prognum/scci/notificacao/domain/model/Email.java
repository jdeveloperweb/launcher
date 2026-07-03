package com.prognum.scci.notificacao.domain.model;

/**
 * Mensagem de e-mail com o servidor SMTP embutido. Fiel ao SCCI (loginbd.pas): o SMTP
 * ({@code smtpHost/smtpUsuario/smtpSenha}) vem da ENTIDADE do cliente (por-requisicao), nao de config
 * global — cada cliente entrega pelo proprio servidor. {@code smtpUsuario/smtpSenha} vazios = sem auth.
 */
public record Email(String smtpHost, String smtpUsuario, String smtpSenha,
                    String para, String assunto, String corpo) {
}
