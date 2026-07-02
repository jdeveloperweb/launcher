package com.prognum.launcher.auth;

import com.prognum.launcher.auth.dto.ChangePasswordRequest;
import com.prognum.launcher.auth.dto.ChangePasswordResponse;
import com.prognum.launcher.auth.dto.LoginRequest;
import com.prognum.launcher.auth.dto.LoginResponse;
import com.prognum.launcher.auth.port.SessionStore;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Autenticacao (regras.md RF01/RF02): /v1/login, /v1/logout e validacao de sessao.
 */
@RestController
@RequestMapping("/v1")
public class AuthController {

    private static final Logger log = LoggerFactory.getLogger(AuthController.class);

    private final LoginService login;
    private final PasswordChangeService passwordChange;
    private final SessionStore sessions;

    public AuthController(LoginService login, PasswordChangeService passwordChange, SessionStore sessions) {
        this.login = login;
        this.passwordChange = passwordChange;
        this.sessions = sessions;
    }

    @PostMapping("/login")
    public LoginResponse login(@RequestBody LoginRequest req,
                               @RequestHeader(value = "X-Request-Id", required = false) String requestId,
                               HttpServletRequest http) {
        String id = (requestId == null || requestId.isBlank()) ? UUID.randomUUID().toString() : requestId;
        LoginResponse r = login.autenticar(req, http.getRemoteAddr(), id);
        log.info("login", kv("usuario", req.usuario()), kv("outcome", r.outcome()), kv("sucesso", r.success()));
        return r;
    }

    @PostMapping("/passwd")
    public ChangePasswordResponse passwd(@RequestBody ChangePasswordRequest req,
                                         @RequestHeader(value = "X-Request-Id", required = false) String requestId) {
        String id = (requestId == null || requestId.isBlank()) ? UUID.randomUUID().toString() : requestId;
        ChangePasswordResponse r = passwordChange.trocar(req, id);
        log.info("passwd", kv("usuario", req.usuario()), kv("outcome", r.outcome()), kv("sucesso", r.success()));
        return r;
    }

    @PostMapping("/logout")
    public Map<String, Object> logout(@RequestHeader(value = "X-Session-Token", required = false) String token) {
        sessions.invalidate(token);
        return Map.<String, Object>of("success", true);
    }

    @GetMapping("/session/validate")
    public Map<String, Object> validate(@RequestHeader(value = "X-Session-Token", required = false) String token) {
        return Map.<String, Object>of("valid", sessions.get(token).isPresent());
    }
}
