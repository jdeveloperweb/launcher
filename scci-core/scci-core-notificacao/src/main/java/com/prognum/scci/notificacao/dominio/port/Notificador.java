package com.prognum.scci.notificacao.dominio.port;

import com.prognum.scci.notificacao.dominio.model.Email;

/**
 * Porta PUBLICA do contexto notificacao — o que os outros contextos do scci-core reaproveitam
 * (acesso: recuperacao de senha; documentos: entrega; alertas; ...). Mantida atras de interface para
 * que o "quem entrega" seja SMTP direto HOJE ou uma fila/servico (SES/SNS) DEPOIS, sem tocar o consumidor.
 */
public interface Notificador {

    /** Envia um e-mail. Lanca RuntimeException se a entrega falhar (o consumidor decide como tratar). */
    void enviarEmail(Email email);
}
