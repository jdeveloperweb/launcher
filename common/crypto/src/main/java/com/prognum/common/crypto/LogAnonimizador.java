package com.prognum.common.crypto;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Locale;

/**
 * Doc Final de Requisitos (Logs e Auditoria): pseudonimização de usuário e mascaramento de IP para
 * uso em logs de auditoria — resolve a tensão entre "não gravar dados pessoais em texto puro" e
 * "logs precisam ter usuário/IP para troubleshooting". {@code pseudonimizarUsuario} é DETERMINÍSTICO
 * (o mesmo usuário sempre produz o mesmo valor), então dois eventos do mesmo usuário continuam
 * correlacionáveis num incidente, sem expor o identificador real no log. Não é criptografia — é
 * pseudonimização (hash truncado, sem salt): suficiente para o objetivo de auditoria/troubleshooting
 * sem literal em texto puro; não é um mecanismo de segurança contra ataque dedicado de força bruta
 * sobre nomes de usuário conhecidos.
 */
public final class LogAnonimizador {

    private LogAnonimizador() {
    }

    /** Hash SHA-256 truncado (12 hex chars, prefixo "u_") — mesmo usuário -> mesmo valor sempre. */
    public static String pseudonimizarUsuario(String usuario) {
        if (usuario == null || usuario.isBlank()) {
            return "";
        }
        byte[] hash = sha256(usuario.trim().toLowerCase(Locale.ROOT));
        return "u_" + HexFormat.of().formatHex(hash).substring(0, 12);
    }

    /**
     * Doc Final de Requisitos (Logs e Auditoria): identificador de CORRELAÇÃO da sessão para logs —
     * hash determinístico do {@code sessionKey} (nunca o token bruto, que é uma credencial viva).
     * Permite juntar todos os eventos de uma mesma sessão num incidente sem expor o token. Case
     * SENSÍVEL (sessionKey não é normalizado como usuário) e sem sufixo temporal — dois logins da
     * mesma sessão sempre correlacionam para o mesmo valor.
     */
    public static String pseudonimizarSessao(String sessionKey) {
        if (sessionKey == null || sessionKey.isBlank()) {
            return "";
        }
        byte[] hash = sha256(sessionKey.trim());
        return "s_" + HexFormat.of().formatHex(hash).substring(0, 12);
    }

    /**
     * Mascara o IP mantendo a topologia (útil para agrupar por rede/origem sem apontar o host exato):
     * IPv4 zera o último octeto ({@code 10.20.30.99 -> 10.20.30.0}); IPv6 mantém só os 3 primeiros
     * grupos. Formato desconhecido -> devolve string vazia (nunca arrisca vazar o dado bruto).
     */
    public static String mascararIp(String ip) {
        if (ip == null || ip.isBlank()) {
            return "";
        }
        String valor = ip.trim();
        if (valor.contains(":")) {
            String[] grupos = valor.split(":");
            if (grupos.length < 3) {
                return "";
            }
            return grupos[0] + ":" + grupos[1] + ":" + grupos[2] + "::0";
        }
        String[] octetos = valor.split("\\.");
        if (octetos.length != 4) {
            return "";
        }
        return octetos[0] + "." + octetos[1] + "." + octetos[2] + ".0";
    }

    private static byte[] sha256(String texto) {
        try {
            return MessageDigest.getInstance("SHA-256").digest(texto.getBytes(StandardCharsets.UTF_8));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 indisponivel na JVM", e);
        }
    }
}
