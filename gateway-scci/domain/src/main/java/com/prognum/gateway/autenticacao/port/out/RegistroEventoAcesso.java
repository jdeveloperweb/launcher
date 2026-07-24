package com.prognum.gateway.autenticacao.port.out;

/**
 * Port de saida do LOG DE EVENTOS de acesso (login/logout/erro/troca de senha). O adapter dispara o
 * programa configurado na secao [LOG] do launcherenv.ini (ex.: sccilog) via pascal-executor. E
 * best-effort e assincrono: NUNCA pode bloquear nem quebrar o login. Cliente sem [LOG] -> no-op.
 */
public interface RegistroEventoAcesso {

    /** evento: {@code "login"} | {@code "logout"} | {@code "loginerr"} | {@code "passwd"}. */
    void registrar(String ambiente, String evento, String usuario, String ip, String origem, String sessionKey);
}
