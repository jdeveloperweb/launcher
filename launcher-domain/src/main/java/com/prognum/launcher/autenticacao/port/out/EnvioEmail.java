package com.prognum.launcher.autenticacao.port.out;

/**
 * Port de saida de ENVIO DE E-MAIL. Mantido atras de interface de proposito para que o "quem
 * entrega" possa ser SMTP direto (fiel ao loginbd) HOJE, ou uma fila/servico de notificacao
 * (SES/SNS/microservico) DEPOIS — sem tocar no caso de uso.
 */
public interface EnvioEmail {

    void enviar(String smtpHost, String smtpUsuario, String smtpSenha, String para, String assunto, String corpo);
}
