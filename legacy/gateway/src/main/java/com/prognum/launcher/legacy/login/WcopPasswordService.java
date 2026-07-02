package com.prognum.launcher.legacy.login;

import com.prognum.launcher.auth.PasswordVerifier;
import com.prognum.launcher.auth.policy.PasswordPolicy;
import com.prognum.launcher.legacy.db.LauncherEnvReader;
import com.prognum.launcher.legacy.db.SccDbConfig;
import com.prognum.launcher.legacy.db.SccPasswordRepository;
import com.prognum.launcher.legacy.db.SccPasswordRepository.Senhas;
import org.apache.commons.codec.digest.Md5Crypt;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Troca de senha nativa (PASSWD do loginbd.pas / ExecutaPasswdBD), contra a base real do ambiente:
 *  1. verifica a senha ATUAL (md5crypt);
 *  2. aplica a POLITICA de complexidade (regras.md);
 *  3. checa o RODIZIO (nova != atual e != NO_SENHA1..5);
 *  4. GRAVA a nova (md5crypt $1$) rotacionando o historico.
 * Sem flag: o isolamento e o proprio ambiente operacional (de teste).
 */
@Service
public class WcopPasswordService {

    private static final Logger log = LoggerFactory.getLogger(WcopPasswordService.class);
    // Alfabeto de salt do md5crypt (igual ao crypt(3)).
    private static final char[] SALT = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".toCharArray();

    private final LauncherEnvReader env;
    private final SccPasswordRepository repo;
    private final PasswordVerifier passwords;
    private final PasswordPolicy policy;
    private final SecureRandom rnd = new SecureRandom();

    public WcopPasswordService(LauncherEnvReader env, SccPasswordRepository repo,
                               PasswordVerifier passwords, PasswordPolicy policy) {
        this.env = env;
        this.repo = repo;
        this.passwords = passwords;
        this.policy = policy;
    }

    public record Resultado(boolean sucesso, String mensagem) {
    }

    public Resultado trocar(String usuario, String senhaAtual, String novaSenha, String ambiente) {
        usuario = usuario == null ? "" : usuario.trim();
        if (usuario.isBlank() || senhaAtual == null || novaSenha == null) {
            return new Resultado(false, "Dados incompletos para a troca de senha.");
        }

        SccDbConfig cfg = env.ler(ambiente);
        Optional<Senhas> os = repo.ler(cfg, usuario);
        if (os.isEmpty()) {
            return new Resultado(false, "Usuario ou senha invalidos.");
        }
        Senhas s = os.get();

        // 1) senha atual
        if (!passwords.matches(senhaAtual, s.atual())) {
            return new Resultado(false, "Senha atual incorreta.");
        }
        // 2) politica
        PasswordPolicy.Resultado pr = policy.validar(novaSenha);
        if (!pr.ok()) {
            return new Resultado(false, pr.mensagem());
        }
        // 3) rodizio (atual + NO_SENHA1..5)
        if (jaUsada(novaSenha, s)) {
            return new Resultado(false, "Esta senha ja foi usada anteriormente.");
        }
        // 4) grava (md5crypt $1$<salt6>$) rotacionando o historico.
        // UTF-8 para casar com a verificacao do login (PasswordVerifier.matches usa UTF-8);
        // para senha ASCII e identico, mas com acento os bytes precisam bater.
        String novoHash = Md5Crypt.md5Crypt(novaSenha.getBytes(StandardCharsets.UTF_8), "$1$" + salt6() + "$");
        repo.gravar(cfg, usuario, novoHash);
        log.info("web_passwd", kv("usuario", usuario), kv("ambiente", ambiente), kv("driver", cfg.driver()));
        return new Resultado(true, "Senha alterada com sucesso.");
    }

    /** Igual ao TestaSenhaRepetida: a nova nao pode bater com a atual nem com NO_SENHA1..5. */
    boolean jaUsada(String novaSenha, Senhas s) {
        if (passwords.matches(novaSenha, s.atual())) {
            return true;
        }
        for (String h : s.anteriores()) {
            if (h != null && !h.isBlank() && passwords.matches(novaSenha, h)) {
                return true;
            }
        }
        return false;
    }

    private String salt6() {
        StringBuilder sb = new StringBuilder(6);
        for (int i = 0; i < 6; i++) {
            sb.append(SALT[rnd.nextInt(SALT.length)]);
        }
        return sb.toString();
    }
}
