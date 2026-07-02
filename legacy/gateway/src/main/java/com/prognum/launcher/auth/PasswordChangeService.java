package com.prognum.launcher.auth;

import com.prognum.launcher.auth.domain.User;
import com.prognum.launcher.auth.dto.ChangePasswordRequest;
import com.prognum.launcher.auth.dto.ChangePasswordResponse;
import com.prognum.launcher.auth.policy.PasswordPolicy;
import com.prognum.launcher.auth.port.PasswordHistoryStore;
import com.prognum.launcher.auth.port.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.Optional;

import static com.prognum.launcher.auth.LoginOutcome.OK;
import static com.prognum.launcher.auth.LoginOutcome.SENHA_FRACA;
import static com.prognum.launcher.auth.LoginOutcome.SENHA_INCORRETA;
import static com.prognum.launcher.auth.LoginOutcome.SENHA_JA_USADA;

/**
 * Troca de senha (Rota A): verifica a senha atual, aplica a politica de complexidade,
 * checa o rodizio (atual + historico) e grava o novo hash (bcrypt), zerando "must change".
 */
@Service
public class PasswordChangeService {

    private final UserRepository users;
    private final PasswordVerifier passwords;
    private final PasswordPolicy policy;
    private final PasswordHistoryStore history;
    private final long delayMs;
    private final int historico;

    public PasswordChangeService(UserRepository users,
                                 PasswordVerifier passwords,
                                 PasswordPolicy policy,
                                 PasswordHistoryStore history,
                                 @Value("${launcher.auth.login-err-delay-ms:1000}") long delayMs,
                                 @Value("${launcher.auth.policy.historico:5}") int historico) {
        this.users = users;
        this.passwords = passwords;
        this.policy = policy;
        this.history = history;
        this.delayMs = delayMs;
        this.historico = historico;
    }

    public ChangePasswordResponse trocar(ChangePasswordRequest req, String requestId) {
        String usuario = req.usuario() == null ? "" : req.usuario().trim();

        Optional<User> ou = users.findByUsuario(usuario, req.ambiente());
        if (ou.isEmpty()) {
            delay();
            return resp(SENHA_INCORRETA, SENHA_INCORRETA.mensagem, requestId);
        }
        User u = ou.get();

        if (!passwords.matches(req.senhaAtual(), u.senhaHash())) {
            delay();
            return resp(SENHA_INCORRETA, SENHA_INCORRETA.mensagem, requestId);
        }

        PasswordPolicy.Resultado pr = policy.validar(req.novaSenha());
        if (!pr.ok()) {
            return resp(SENHA_FRACA, pr.mensagem(), requestId);
        }

        if (jaUsada(usuario, u, req.novaSenha())) {
            return resp(SENHA_JA_USADA, SENHA_JA_USADA.mensagem, requestId);
        }

        history.push(usuario, u.senhaHash(), historico);          // guarda a senha atual
        users.trocarSenha(usuario, u.ambiente(), passwords.hash(req.novaSenha()), LocalDate.now());
        return resp(OK, "Senha alterada com sucesso", requestId);
    }

    private boolean jaUsada(String usuario, User u, String nova) {
        if (passwords.matches(nova, u.senhaHash())) {
            return true;
        }
        for (String h : history.hashes(usuario)) {
            if (passwords.matches(nova, h)) {
                return true;
            }
        }
        return false;
    }

    private ChangePasswordResponse resp(LoginOutcome o, String msg, String requestId) {
        return new ChangePasswordResponse(o.sucesso, o.name(), msg, requestId);
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
