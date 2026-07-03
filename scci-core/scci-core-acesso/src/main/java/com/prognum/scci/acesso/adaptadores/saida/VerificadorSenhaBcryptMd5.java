package com.prognum.scci.acesso.adaptadores.saida;

import com.prognum.scci.acesso.dominio.port.out.VerificadorSenha;
import org.apache.commons.codec.digest.Md5Crypt;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;

/**
 * Adapter de saida: verificacao/geracao de hash. Porte fiel do PasswordVerifier do legado
 * (matches) + a geracao de md5crypt que estava no WcopPasswordService (salt6 + $1$).
 *  - matches: bcrypt ($2...) do fluxo Java + md5crypt ($1$...) do loginbd.pas.
 *  - gerarHashMd5Crypt: $1$<salt6>$ em UTF-8 (casa com o matches do login).
 */
@Component
public class VerificadorSenhaBcryptMd5 implements VerificadorSenha {

    // Alfabeto de salt do md5crypt (igual ao crypt(3)).
    private static final char[] SALT =
            "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".toCharArray();

    private final BCryptPasswordEncoder bcrypt = new BCryptPasswordEncoder();
    private final SecureRandom rnd = new SecureRandom();

    @Override
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

    @Override
    public String gerarHashMd5Crypt(String senha) {
        // UTF-8 para casar com o matches do login (senha ASCII e identico; com acento os bytes batem).
        return Md5Crypt.md5Crypt(senha.getBytes(StandardCharsets.UTF_8), "$1$" + salt6() + "$");
    }

    private String salt6() {
        StringBuilder sb = new StringBuilder(6);
        for (int i = 0; i < 6; i++) {
            sb.append(SALT[rnd.nextInt(SALT.length)]);
        }
        return sb.toString();
    }
}
