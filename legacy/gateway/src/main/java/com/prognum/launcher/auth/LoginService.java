package com.prognum.launcher.auth;

import com.prognum.launcher.auth.domain.User;
import com.prognum.launcher.auth.dto.LoginRequest;
import com.prognum.launcher.auth.dto.LoginResponse;
import com.prognum.launcher.auth.port.LoginAttemptStore;
import com.prognum.launcher.auth.port.SessionStore;
import com.prognum.launcher.auth.port.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

import static com.prognum.launcher.auth.LoginOutcome.*;
import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Regras de login (Rota A) portadas do launcher legado (nossa doc secao 21):
 * verificacao de senha, estados (inativo/expirada/troca), bloqueio progressivo,
 * atraso anti forca-bruta + mensagem indistinguivel, e criacao de sessao.
 */
@Service
public class LoginService {

    private static final Logger log = LoggerFactory.getLogger(LoginService.class);

    private final UserRepository users;
    private final PasswordVerifier passwords;
    private final LoginAttemptStore attempts;
    private final SessionStore sessions;

    private final long delayMs;
    private final int maxErros;
    private final int maxErrosCaptcha;
    private final boolean captchaHabilitado;
    private final int diasAviso;
    private final long ttlSegundos;
    private final int maxSessoes;

    public LoginService(UserRepository users,
                        PasswordVerifier passwords,
                        LoginAttemptStore attempts,
                        SessionStore sessions,
                        @Value("${launcher.auth.login-err-delay-ms:1000}") long delayMs,
                        @Value("${launcher.auth.max-erros:5}") int maxErros,
                        @Value("${launcher.auth.max-erros-captcha:3}") int maxErrosCaptcha,
                        @Value("${launcher.auth.captcha-habilitado:true}") boolean captchaHabilitado,
                        @Value("${launcher.auth.dias-aviso-expiracao:5}") int diasAviso,
                        @Value("${launcher.auth.session.ttl-segundos:1800}") long ttlSegundos,
                        @Value("${launcher.auth.session.max-por-usuario:1}") int maxSessoes) {
        this.users = users;
        this.passwords = passwords;
        this.attempts = attempts;
        this.sessions = sessions;
        this.delayMs = delayMs;
        this.maxErros = maxErros;
        this.maxErrosCaptcha = maxErrosCaptcha;
        this.captchaHabilitado = captchaHabilitado;
        this.diasAviso = diasAviso;
        this.ttlSegundos = ttlSegundos;
        this.maxSessoes = maxSessoes;
    }

    public LoginResponse autenticar(LoginRequest req, String ip, String requestId) {
        String usuario = req.usuario() == null ? "" : req.usuario().trim();

        // ja bloqueado?
        if (attempts.get(usuario) > maxErros) {
            return resp(BLOQUEADO, null, null, requestId);
        }

        Optional<User> ou = users.findByUsuario(usuario, req.ambiente());

        // usuario inexistente: conta o erro e responde igual a senha errada (hardening RN-031)
        if (ou.isEmpty()) {
            attempts.registerFailure(usuario);
            delay();
            return resp(SENHA_INCORRETA, null, null, requestId);
        }

        User u = ou.get();

        // verifica a senha ANTES de revelar qualquer estado da conta
        if (!passwords.matches(req.senha(), u.senhaHash())) {
            int c = attempts.registerFailure(usuario);
            delay();
            LoginOutcome o = (c > maxErros) ? BLOQUEADO
                    : (captchaHabilitado && c > maxErrosCaptcha) ? CAPTCHA_OBRIGATORIO
                    : SENHA_INCORRETA;
            return resp(o, null, null, requestId);
        }

        // senha correta -> zera contador e avalia o estado da conta
        attempts.reset(usuario);

        // migracao transparente do hash legado (md5crypt -> bcrypt) no login bem-sucedido (Q8)
        if (passwords.isLegacy(u.senhaHash())) {
            users.atualizarHash(usuario, u.ambiente(), passwords.hash(req.senha()));
            log.info("rehash", kv("usuario", usuario), kv("de", "md5crypt"), kv("para", "bcrypt"));
        }

        if (!u.ativo()) {
            return resp(USUARIO_INATIVO, null, null, requestId);
        }
        LocalDate hoje = LocalDate.now();
        if (u.dtValidade() != null && u.dtValidade().isBefore(hoje)) {
            return resp(SENHA_EXPIRADA, null, null, requestId);
        }
        if (u.mustChange()) {
            return resp(TROCA_OBRIGATORIA, null, null, requestId);
        }

        Integer diasRestantes = null;
        if (u.ultimaTroca() != null && u.maxDiasTroca() != null && u.maxDiasTroca() > 0) {
            LocalDate vencimento = u.ultimaTroca().plusDays(u.maxDiasTroca());
            long faltam = ChronoUnit.DAYS.between(hoje, vencimento);
            if (faltam < 0) {
                return resp(TROCA_OBRIGATORIA, null, null, requestId);   // idade maxima atingida
            }
            if (faltam <= diasAviso) {
                diasRestantes = (int) faltam;                            // aviso, mas login permitido
            }
        }

        // sucesso: cria a sessao (uma ativa por usuario)
        sessions.enforceLimit(usuario, maxSessoes);
        String token = sessions.create(usuario, u.ambiente(), ip, ttlSegundos);

        LoginOutcome o = (diasRestantes != null) ? SENHA_VAI_EXPIRAR : OK;
        return resp(o, token, diasRestantes, requestId);
    }

    private LoginResponse resp(LoginOutcome o, String token, Integer dias, String requestId) {
        return new LoginResponse(o.sucesso, o.name(), o.mensagem, token, requestId, dias);
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
