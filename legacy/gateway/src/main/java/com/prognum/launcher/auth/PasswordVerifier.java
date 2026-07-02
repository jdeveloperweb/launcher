package com.prognum.launcher.auth;

import org.apache.commons.codec.digest.Md5Crypt;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

/**
 * Verificacao de senha. Suporta:
 *  - bcrypt ($2...) — formato novo do fluxo Java nativo (Rota A);
 *  - md5crypt ($1$...) — formato legado usado pelo loginbd.pas / banco SCCI.
 *
 * Estrategia de migracao (Q8): no login bem-sucedido de um hash legado,
 * o LoginService re-hasheia a senha para bcrypt (ver atualizarHash).
 */
@Component
public class PasswordVerifier {

    private final BCryptPasswordEncoder bcrypt = new BCryptPasswordEncoder();

    public boolean matches(String senha, String hash) {
        if (senha == null || hash == null) {
            return false;
        }
        if (hash.startsWith("$2")) {                 // bcrypt
            return bcrypt.matches(senha, hash);
        }
        if (hash.startsWith("$1$")) {                // md5crypt (Unix MD5, igual ao loginbd)
            try {
                return hash.equals(Md5Crypt.md5Crypt(senha.getBytes(StandardCharsets.UTF_8), hash));
            } catch (RuntimeException e) {
                return false;
            }
        }
        return false;
    }

    /** Hash legado (md5crypt)? Se sim, deve ser migrado para bcrypt no login (Q8). */
    public boolean isLegacy(String hash) {
        return hash != null && hash.startsWith("$1$");
    }

    /** Novo hash — sempre bcrypt. */
    public String hash(String senha) {
        return bcrypt.encode(senha);
    }

    /** Gera um hash md5crypt — apenas para semear usuarios "legados" de teste. */
    public String md5crypt(String senha) {
        return Md5Crypt.md5Crypt(senha.getBytes(StandardCharsets.UTF_8));
    }
}
