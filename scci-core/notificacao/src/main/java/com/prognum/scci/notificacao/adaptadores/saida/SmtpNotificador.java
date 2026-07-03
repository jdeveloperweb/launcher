package com.prognum.scci.notificacao.adaptadores.saida;

import com.prognum.scci.notificacao.dominio.model.Email;
import com.prognum.scci.notificacao.dominio.port.Notificador;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Component;

import java.util.Properties;

/**
 * Adapter de saida: envio SMTP DIRETO (fiel ao EnviaEmail do loginbd.pas). O host/usuario/senha vem
 * da ENTIDADE (por-requisicao, dentro do {@link Email}), entao construimos o sender na hora. Para
 * desacoplar no futuro (fila/SES/SNS), basta outro @Component implementando {@link Notificador}.
 */
@Component
public class SmtpNotificador implements Notificador {

    @Override
    public void enviarEmail(Email email) {
        JavaMailSenderImpl sender = new JavaMailSenderImpl();
        sender.setHost(email.smtpHost());
        sender.setPort(587);   // STARTTLS padrao; ajustar se a entidade usar 25/465
        boolean autentica = email.smtpUsuario() != null && !email.smtpUsuario().isBlank();
        if (autentica) {
            sender.setUsername(email.smtpUsuario());
            sender.setPassword(email.smtpSenha());
        }
        Properties p = sender.getJavaMailProperties();
        p.put("mail.transport.protocol", "smtp");
        p.put("mail.smtp.auth", String.valueOf(autentica));
        p.put("mail.smtp.starttls.enable", "true");
        p.put("mail.smtp.connectiontimeout", "10000");
        p.put("mail.smtp.timeout", "10000");

        SimpleMailMessage msg = new SimpleMailMessage();
        String from = (email.smtpUsuario() != null && email.smtpUsuario().contains("@"))
                ? email.smtpUsuario() : "nao-responder@scci.local";
        msg.setFrom(from);
        msg.setTo(email.para());
        msg.setSubject(email.assunto());
        msg.setText(email.corpo());
        sender.send(msg);
    }
}
