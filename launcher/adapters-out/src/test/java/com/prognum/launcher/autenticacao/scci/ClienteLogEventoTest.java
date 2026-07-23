package com.prognum.launcher.autenticacao.scci;

import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.slf4j.LoggerFactory;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Robusto: a auditoria de acesso ({@code evento_acesso}) e GARANTIDA e SINCRONA — grava no log do
 * launcher em todo evento, mesmo com o pascal-executor/legado fora do ar (aqui a URL aponta pra uma
 * porta morta). E respeita a anonimizacao (req 2.7): o usuario em claro nao aparece no log.
 */
class ClienteLogEventoTest {

    private ListAppender<ILoggingEvent> appender;
    private Logger logger;

    @BeforeEach
    void anexaAppender() {
        logger = (Logger) LoggerFactory.getLogger(ClienteLogEvento.class);
        appender = new ListAppender<>();
        appender.start();
        logger.addAppender(appender);
    }

    @AfterEach
    void removeAppender() {
        logger.detachAppender(appender);
    }

    private static ILoggingEvent auditoria(List<ILoggingEvent> eventos) {
        return eventos.stream().filter(e -> "evento_acesso".equals(e.getMessage())).findFirst().orElse(null);
    }

    @Test
    void auditaSincrono_mesmoComPascalExecutorFora() {
        // porta 1 = recusa/inalcancavel -> o POST assincrono ao pascal-executor vai falhar
        ClienteLogEvento cliente = new ClienteLogEvento("http://localhost:1");

        cliente.registrar("/u10/cliente/scat1", "login", "supervisor", "10.20.30.40", "CORP_WEB", "SESS-123");

        ILoggingEvent audit = auditoria(appender.list);
        assertTrue(audit != null, "a linha evento_acesso deve ser gravada SINCRONA (antes do POST assincrono)");
        assertEquals("INFO", audit.getLevel().toString());
    }

    @Test
    void naoVazaUsuarioNemSessaoEmClaro() {
        ClienteLogEvento cliente = new ClienteLogEvento("http://localhost:1");
        cliente.registrar("/u10/cliente/scat1", "logout", "supervisor", "10.20.30.40", "CORP_WEB", "SESS-123");

        ILoggingEvent audit = auditoria(appender.list);
        assertTrue(audit != null);
        String linha = audit.getFormattedMessage() + java.util.Arrays.toString(audit.getArgumentArray());
        assertFalse(linha.contains("supervisor"), "usuario deve ir PSEUDONIMIZADO, nunca em claro (req 2.7)");
        assertFalse(linha.contains("SESS-123"), "sessao deve ir pseudonimizada, nunca em claro");
    }

    @Test
    void semSessionKey_naoQuebra() {
        ClienteLogEvento cliente = new ClienteLogEvento("http://localhost:1");
        // loginerr nao tem sessao ainda -> sessionKey null nao pode quebrar a auditoria
        cliente.registrar("/u10/cliente/scat1", "loginerr", "fulano", "1.2.3.4", "CORP_WEB", null);
        assertTrue(auditoria(appender.list) != null, "auditoria deve sair mesmo sem sessionKey");
    }
}
