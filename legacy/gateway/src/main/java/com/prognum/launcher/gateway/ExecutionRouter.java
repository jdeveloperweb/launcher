package com.prognum.launcher.gateway;

import com.prognum.launcher.api.dto.ExecuteRequest;
import org.springframework.stereotype.Component;

/**
 * Roteador Strangler (regras.md DA04), agora alimentado pelo Feature Registry.
 * Precedencia: kill-switch global (C) -> legado forcado por escopo (C) -> nativo (A) -> ProcessBuilder (B).
 */
@Component
public class ExecutionRouter {

    private final FeatureRegistry registry;

    public ExecutionRouter(FeatureRegistry registry) {
        this.registry = registry;
    }

    public RouteDecision route(ExecuteRequest req) {
        if (registry.killSwitchGlobal()) {
            return RouteDecision.LEGACY_PROXY;                     // C (rollback global / fallback)
        }
        if (registry.isLegacyProxyRequired(req.wTela(), req.usuario(), req.ambiente())) {
            return RouteDecision.LEGACY_PROXY;                     // C (rollback por escopo)
        }
        if (registry.isNativeJava(req.wTela(), req.usuario(), req.ambiente())) {
            return RouteDecision.NATIVE_JAVA;                      // A (migrado, com rollout)
        }
        return RouteDecision.PROCESS_BUILDER;                      // B (default p/ Pascal)
    }
}
