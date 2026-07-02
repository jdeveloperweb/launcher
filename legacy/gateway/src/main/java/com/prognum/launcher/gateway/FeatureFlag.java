package com.prognum.launcher.gateway;

/**
 * Regra do Feature Registry (regras.md RF11).
 * Define que uma (wTela / usuario / ambiente) deve ir para uma rota — com rollout percentual.
 * Campos de escopo nulos/vazios/"*" significam "qualquer". 'rota' usual: NATIVE_JAVA (A) ou
 * LEGACY_PROXY (C); a rota B (ProcessBuilder) e o default e nao precisa de flag.
 */
public record FeatureFlag(
        String id,
        String wTela,
        String usuario,
        String ambiente,
        RouteDecision rota,
        Integer rolloutPercent,   // null = 100 (full); 0..100 = canary (sticky por usuario+wTela)
        Integer prioridade        // maior vence quando varias regras casam
) {
}
