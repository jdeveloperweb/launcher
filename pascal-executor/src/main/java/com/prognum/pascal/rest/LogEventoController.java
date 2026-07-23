package com.prognum.pascal.rest;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.pascal.logevento.ExecutorLogEvento;

/**
 * REST interno do log de eventos de acesso: o launcher (edge) dispara no login/logout/erro/troca e o
 * pascal-executor executa o programa configurado na secao [LOG] do launcherenv.ini (ex.: sccilog).
 * NAO exposto ao front. Responde 202 (best-effort — o log nunca deve bloquear o login).
 */
@RestController
public class LogEventoController {

    private final ExecutorLogEvento executor;

    public LogEventoController(ExecutorLogEvento executor) {
        this.executor = executor;
    }

    @PostMapping("/interno/log-evento")
    public ResponseEntity<Void> registrar(@RequestBody EventoRequest req) {
        executor.registrar(req.ambiente(), req.evento(), req.usuario(), req.ip(), req.origem(), req.sessionKey());
        return ResponseEntity.accepted().build();
    }

    /** evento: login | logout | loginerr | passwd. */
    public record EventoRequest(String ambiente, String evento, String usuario, String ip,
                                String origem, String sessionKey) {
    }
}
