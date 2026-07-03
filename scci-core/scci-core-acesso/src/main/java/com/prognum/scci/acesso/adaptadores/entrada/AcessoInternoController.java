package com.prognum.scci.acesso.adaptadores.entrada;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.acesso.dominio.model.ResultadoLogin;
import com.prognum.scci.acesso.dominio.port.in.LoginUseCase;

/**
 * REST INTERNO do contexto acesso (consumido pelo launcher-edge quando a flag {@code acesso.Login}
 * aponta JAVA/scci-core). NÃO faz W_COP — o edge decifra e manda TEXTO pela rede interna confiável.
 * NÃO registra sessão aqui (o ciclo de vida da sessão é do contexto {@code sessao}, Fase 2): devolve o
 * {@link ResultadoLogin} cru (inclui o sessionKey emitido) para o edge montar a resposta do front.
 *
 * <ul>
 *   <li>POST {@code /interno/acesso/login} — coordena bloqueio/captcha/estados e verifica a credencial.</li>
 * </ul>
 */
@RestController
public class AcessoInternoController {

    private final LoginUseCase login;

    public AcessoInternoController(LoginUseCase login) {
        this.login = login;
    }

    @PostMapping("/interno/acesso/login")
    public ResponseEntity<ResultadoLogin> login(@RequestBody LoginRequest req) {
        return ResponseEntity.ok(login.login(req.usuario(), req.senha(), req.ambiente(), req.ip()));
    }

    /** Corpo do login interno (texto; sem W_COP). */
    public record LoginRequest(String usuario, String senha, String ambiente, String ip) {
    }
}
