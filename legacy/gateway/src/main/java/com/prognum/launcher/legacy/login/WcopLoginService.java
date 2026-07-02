package com.prognum.launcher.legacy.login;

import com.prognum.launcher.auth.PasswordVerifier;
import com.prognum.launcher.auth.port.LoginAttemptStore;
import com.prognum.launcher.legacy.db.LauncherEnvReader;
import com.prognum.launcher.legacy.db.SccDbConfig;
import com.prognum.launcher.legacy.db.SccLoginRepository;
import com.prognum.launcher.legacy.db.SccLoginRepository.SccUser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Login nativo do W_COP/loginbd (Rota A), contra a base real do ambiente (somente leitura).
 * Replica TestaUsuario/ExecutaLoginBD do loginbd.pas + hardening do regras.md (bloqueio/captcha/atraso).
 * NAO altera o banco (sem re-hash md5crypt->bcrypt).
 */
@Service
public class WcopLoginService {

    private static final Logger log = LoggerFactory.getLogger(WcopLoginService.class);
    private static final char[] ALFABETO = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".toCharArray();

    private final LauncherEnvReader env;
    private final SccLoginRepository repo;
    private final PasswordVerifier passwords;
    private final LoginAttemptStore attempts;
    private final SecureRandom rnd = new SecureRandom();

    private final long delayMs;
    private final int maxErros;
    private final int maxErrosCaptcha;
    private final boolean captchaHabilitado;
    private final int diasAviso;

    public WcopLoginService(LauncherEnvReader env,
                            SccLoginRepository repo,
                            PasswordVerifier passwords,
                            LoginAttemptStore attempts,
                            @Value("${launcher.auth.login-err-delay-ms:1000}") long delayMs,
                            @Value("${launcher.auth.max-erros:5}") int maxErros,
                            @Value("${launcher.auth.max-erros-captcha:3}") int maxErrosCaptcha,
                            @Value("${launcher.auth.captcha-habilitado:true}") boolean captchaHabilitado,
                            @Value("${launcher.auth.dias-aviso-expiracao:5}") int diasAviso) {
        this.env = env;
        this.repo = repo;
        this.passwords = passwords;
        this.attempts = attempts;
        this.delayMs = delayMs;
        this.maxErros = maxErros;
        this.maxErrosCaptcha = maxErrosCaptcha;
        this.captchaHabilitado = captchaHabilitado;
        this.diasAviso = diasAviso;
    }

    /** codErro segue o loginbd: T=ok, C=vai expirar, E=expirada, M=troca, B=branco, F=incorreta, K=captcha, X=bloqueado. */
    public record Resultado(boolean sucesso, char codErro, String sessionKey, String mensagem, Integer diasRestantes) {
    }

    public Resultado login(String usuarioRaw, String senha, String ambiente, String ip) {
        String usuario = usuarioRaw == null ? "" : usuarioRaw.trim();

        if (attempts.get(usuario) > maxErros) {
            return new Resultado(false, 'X', null, "Usuario bloqueado por excesso de tentativas.", null);
        }

        SccDbConfig cfg = env.ler(ambiente);
        Optional<SccUser> ou = repo.buscar(cfg, usuario);

        // inexistente: conta o erro e responde igual a senha errada (RN-031)
        if (ou.isEmpty()) {
            attempts.registerFailure(usuario);
            delay();
            return new Resultado(false, 'F', null, "Usuario ou senha invalidos.", null);
        }

        SccUser u = ou.get();
        boolean senhaBranca = u.senhaHash() == null || u.senhaHash().isBlank();

        // verifica a senha ANTES de revelar estado
        if (senhaBranca || !passwords.matches(senha, u.senhaHash())) {
            int n = attempts.registerFailure(usuario);
            delay();
            if (n > maxErros) {
                return new Resultado(false, 'X', null, "Usuario bloqueado por excesso de tentativas.", null);
            }
            if (captchaHabilitado && n > maxErrosCaptcha) {
                return new Resultado(false, 'K', null, "Captcha obrigatorio.", null);
            }
            return new Resultado(false, 'F', null, "Usuario ou senha invalidos.", null);
        }

        attempts.reset(usuario);

        // estados (TestaUsuario do loginbd.pas)
        LocalDate hoje = LocalDate.now();
        if (u.dtValidade() != null && u.dtValidade().isBefore(hoje)) {
            return new Resultado(false, 'E', null, "Conta expirada.", null);
        }
        if (u.maxDias() != null && u.maxDias() > 0 && u.ultimaTroca() != null
                && hoje.isAfter(u.ultimaTroca().plusDays(u.maxDias()))) {
            return new Resultado(false, 'M', null, "Sua senha deve ser trocada.", null);
        }
        String mc = u.mustChange() == null ? "" : u.mustChange().trim().toUpperCase();
        if (mc.equals("T") || mc.equals("V")) {
            return new Resultado(false, 'M', null, "Sua senha deve ser trocada no proximo login.", null);
        }

        // vai expirar (C): passou do minimo, mas ainda dentro do maximo -> login permitido com aviso
        Integer dias = null;
        char cod = 'T';
        if (u.minDias() != null && u.minDias() > 0 && u.ultimaTroca() != null
                && hoje.isAfter(u.ultimaTroca().plusDays(u.minDias()))) {
            int base = (u.maxDias() != null && u.maxDias() > 0) ? u.maxDias() : u.minDias();
            long faltam = ChronoUnit.DAYS.between(hoje, u.ultimaTroca().plusDays(base));
            if (faltam >= 0 && faltam <= diasAviso) {
                dias = (int) faltam;
                cod = 'C';
            }
        }

        String token = novaSessionKey();
        log.info("wcop_login_ok", kv("usuario", usuario), kv("ambiente", ambiente),
                kv("driver", cfg.driver()), kv("codErro", String.valueOf(cod)));
        return new Resultado(true, cod, token, cod == 'C' ? "Senha expira em breve." : "OK", dias);
    }

    private String novaSessionKey() {
        StringBuilder sb = new StringBuilder(29);
        for (int i = 0; i < 29; i++) {
            sb.append(ALFABETO[rnd.nextInt(ALFABETO.length)]);
        }
        return sb.toString();
    }

    private void delay() {
        if (delayMs > 0) {
            try {
                Thread.sleep(delayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }
}
