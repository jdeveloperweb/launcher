package com.prognum.launcher.autenticacao.email;

import com.prognum.launcher.autenticacao.port.out.EnvioEmail;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Component;

import java.util.Properties;

/**
 * Adapter de saida: envio SMTP DIRETO (fiel ao EnviaEmail do loginbd.pas). O host/usuario/senha
 * vem da ENTIDADE do usuario (por-requisicao), entao construimos o sender na hora. Para desacoplar
 * no futuro (fila/SES/SNS), basta outro @Component implementando EnvioEmail — o caso de uso nao muda.
 */
@Component
public class SmtpEnvioEmail implements EnvioEmail {

    @Override
    public void enviar(String smtpHost, String smtpUsuario, String smtpSenha,
                       String para, String assunto, String corpo) {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setHost(smtpHost);
        sender.setPort(587);   // STARTTLS padrao; ajustar se a entidade usar 25/465
        boolean autentica = smtpUsuario != null && !smtpUsuario.isBlank();
        if (autentica) {
            sender.setUsername(smtpUsuario);
            sender.setPassword(smtpSenha);
        }
        Properties p = sender.getJavaMailProperties();
        p.put("mail.transport.protocol", "smtp");
        p.put("mail.smtp.auth", String.valueOf(autentica));
        p.put("mail.smtp.starttls.enable", "true");
        p.put("mail.smtp.connectiontimeout", "10000");
        p.put("mail.smtp.timeout", "10000");

        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setFrom((smtpUsuario != null && smtpUsuario.contains("@")) ? smtpUsuario : "nao-responder@scci.local");
        msg.setTo(para);
        msg.setSubject(assunto);
        msg.setText(corpo);
        sender.send(msg);
    }
}
