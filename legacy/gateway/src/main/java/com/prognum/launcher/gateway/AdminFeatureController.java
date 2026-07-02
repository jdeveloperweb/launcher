package com.prognum.launcher.gateway;

import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.UUID;

/**
 * Admin do Feature Registry (regras.md RF11). Gestao de flags e kill-switch (rollback instantaneo).
 * IMPORTANTE: em producao deve ser protegido (Kong / Spring Security) — Fase 1 deixa aberto.
 */
@RestController
@RequestMapping("/v1/admin")
public class AdminFeatureController {

    private final FeatureRegistry registry;

    public AdminFeatureController(FeatureRegistry registry) {
        this.registry = registry;
    }

    @GetMapping("/features")
    public Map<String, Object> list() {
        return Map.<String, Object>of(
                "killSwitchGlobal", registry.killSwitchGlobal(),
                "flags", registry.list());
    }

    @PostMapping("/features")
    public FeatureFlag upsert(@RequestBody FeatureFlag flag) {
        String id = (flag.id() == null || flag.id().isBlank()) ? UUID.randomUUID().toString() : flag.id();
        FeatureFlag f = new FeatureFlag(id, flag.wTela(), flag.usuario(), flag.ambiente(),
                flag.rota(), flag.rolloutPercent(), flag.prioridade());
        registry.upsert(f);
        return f;
    }

    @DeleteMapping("/features/{id}")
    public Map<String, Object> remove(@PathVariable String id) {
        return Map.<String, Object>of("removed", registry.remove(id));
    }

    @PostMapping("/kill-switch")
    public Map<String, Object> killSwitch(@RequestParam boolean on) {
        registry.setKillSwitchGlobal(on);
        return Map.<String, Object>of("killSwitchGlobal", on);
    }
}
