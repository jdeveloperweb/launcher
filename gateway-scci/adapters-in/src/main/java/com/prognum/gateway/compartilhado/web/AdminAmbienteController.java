package com.prognum.gateway.compartilhado.web;

import com.prognum.common.environment.LauncherEnvReader;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Admin operacional: RECARREGA o cache do launcherenv.ini em RUNTIME, sem reiniciar o processo nem
 * esperar o TTL. Util quando alteram o .ini de um ambiente (troca de banco, colunas, política) e
 * querem efeito imediato. Delega ao {@link LauncherEnvReader#invalidar}/{@link LauncherEnvReader#invalidarTudo}
 * (a releitura acontece na proxima requisicao daquele ambiente). Cada serviço (launcher/scci-core/
 * pascal-executor) tem o seu cache — exponha o mesmo endpoint onde precisar do efeito.
 *
 * <p>Deixe atras da borda (Kong/rede interna) — é operação administrativa, nao pública.</p>
 */
@RestController
public class AdminAmbienteController {

    private static final Logger log = LoggerFactory.getLogger(AdminAmbienteController.class);

    private final LauncherEnvReader env;

    public AdminAmbienteController(LauncherEnvReader env) {
        this.env = env;
    }

    /** Recarrega TODOS os ambientes (sem ?ambiente) ou apenas um (?ambiente=/u10/.../scatXXXX). */
    @PostMapping("/admin/env/reload")
    public ResponseEntity<String> reload(@RequestParam(required = false) String ambiente) {
        if (ambiente == null || ambiente.isBlank()) {
            env.invalidarTudo();
            log.info("env_reload", kv("escopo", "todos"));
            return ResponseEntity.ok("{\"success\":true,\"reloaded\":\"all\"}");
        }
        env.invalidar(ambiente);
        log.info("env_reload", kv("escopo", ambiente));
        return ResponseEntity.ok("{\"success\":true,\"reloaded\":\"" + ambiente.replace("\"", "") + "\"}");
    }
}
