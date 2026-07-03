package com.prognum.scci.sessao.adapters.in;

import java.util.Optional;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.scci.sessao.domain.model.Sessao;
import com.prognum.scci.sessao.domain.port.in.SessaoUseCase;

/**
 * REST INTERNO do contexto sessao (ciclo de vida). O launcher-edge REGISTRA no login e ENCERRA no
 * logout; o VALIDA por-request (gate) o launcher faz lendo o Redis DIRETO (sem hop). Este {@code validar}
 * existe para o fallback SCCI_SESSION (miss de Redis), a ligar por flag no edge.
 *
 * <ul>
 *   <li>POST   {@code /interno/sessao}                 — registrar (Redis + SCCI_SESSION);</li>
 *   <li>GET    {@code /interno/sessao/validar}         — VALIDA (cache -> SCCI_SESSION); 404 se invalida;</li>
 *   <li>GET    {@code /interno/sessao/{key}}           — consultar (cache);</li>
 *   <li>GET    {@code /interno/sessao/contar}          — sessoes ativas (QtMaxLogin);</li>
 *   <li>DELETE {@code /interno/sessao/{key}}           — encerrar (logout).</li>
 * </ul>
 */
@RestController
public class SessaoInternoController {

    private final SessaoUseCase sessoes;

    public SessaoInternoController(SessaoUseCase sessoes) {
        this.sessoes = sessoes;
    }

    @PostMapping("/interno/sessao")
    public ResponseEntity<Void> registrar(@RequestBody RegistroSessao req) {
        sessoes.registrar(req.sessionKey(), req.usuario(), req.ambiente(), req.ip());
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/interno/sessao/validar")
    public ResponseEntity<Sessao> validar(@RequestParam String sessionKey,
                                          @RequestParam(required = false) String usuario,
                                          @RequestParam(required = false) String ambiente) {
        Optional<Sessao> s = sessoes.validar(sessionKey, usuario, ambiente);
        return s.map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping("/interno/sessao/contar")
    public ResponseEntity<Integer> contar(@RequestParam String usuario,
                                          @RequestParam(required = false) String ambiente) {
        return ResponseEntity.ok(sessoes.contarSessoesAtivas(usuario, ambiente));
    }

    @GetMapping("/interno/sessao/{key}")
    public ResponseEntity<Sessao> consultar(@PathVariable("key") String sessionKey) {
        return sessoes.consultar(sessionKey)
                .map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.notFound().build());
    }

    @DeleteMapping("/interno/sessao/{key}")
    public ResponseEntity<Void> encerrar(@PathVariable("key") String sessionKey) {
        sessoes.encerrar(sessionKey);
        return ResponseEntity.noContent().build();
    }

    /** Corpo do registro de sessao (texto; sem W_COP). */
    public record RegistroSessao(String sessionKey, String usuario, String ambiente, String ip) {
    }
}
