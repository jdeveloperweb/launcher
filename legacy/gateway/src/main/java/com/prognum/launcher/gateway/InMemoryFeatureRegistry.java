package com.prognum.launcher.gateway;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Implementacao in-memory do Feature Registry. Resolve por escopo (wTela/usuario/ambiente),
 * aplica rollout percentual sticky (mesmo usuario+tela cai sempre do mesmo lado) e mantem
 * o kill-switch global. Depois: adapter DB+Redis com a mesma interface.
 */
@Component
public class InMemoryFeatureRegistry implements FeatureRegistry {

    private final Map<String, FeatureFlag> flags = new ConcurrentHashMap<>();
    private final AtomicBoolean killSwitch;

    public InMemoryFeatureRegistry(
            @Value("${launcher.routing.global-legacy-fallback:true}") boolean inicial) {
        this.killSwitch = new AtomicBoolean(inicial);
    }

    @Override
    public boolean killSwitchGlobal() {
        return killSwitch.get();
    }

    @Override
    public void setKillSwitchGlobal(boolean on) {
        killSwitch.set(on);
    }

    @Override
    public boolean isNativeJava(String wTela, String usuario, String ambiente) {
        return melhorFlag(RouteDecision.NATIVE_JAVA, wTela, usuario, ambiente)
                .map(f -> passaRollout(f, usuario, wTela))
                .orElse(false);
    }

    @Override
    public boolean isLegacyProxyRequired(String wTela, String usuario, String ambiente) {
        return melhorFlag(RouteDecision.LEGACY_PROXY, wTela, usuario, ambiente)
                .map(f -> passaRollout(f, usuario, wTela))
                .orElse(false);
    }

    @Override
    public List<FeatureFlag> list() {
        return new ArrayList<>(flags.values());
    }

    @Override
    public void upsert(FeatureFlag flag) {
        flags.put(flag.id(), flag);
    }

    @Override
    public boolean remove(String id) {
        return flags.remove(id) != null;
    }

    private Optional<FeatureFlag> melhorFlag(RouteDecision rota, String wTela, String usuario, String ambiente) {
        return flags.values().stream()
                .filter(f -> f.rota() == rota)
                .filter(f -> casa(f.wTela(), wTela) && casa(f.usuario(), usuario) && casa(f.ambiente(), ambiente))
                .max(Comparator.comparingInt((FeatureFlag f) -> f.prioridade() == null ? 0 : f.prioridade()));
    }

    private static boolean casa(String flagVal, String reqVal) {
        if (flagVal == null || flagVal.isBlank() || "*".equals(flagVal)) {
            return true;
        }
        return reqVal != null && flagVal.equalsIgnoreCase(reqVal.trim());
    }

    /** Rollout sticky por (usuario|wTela): o mesmo usuario na mesma tela cai sempre do mesmo lado. */
    private static boolean passaRollout(FeatureFlag f, String usuario, String wTela) {
        int p = (f.rolloutPercent() == null) ? 100 : f.rolloutPercent();
        if (p >= 100) {
            return true;
        }
        if (p <= 0) {
            return false;
        }
        int bucket = Math.floorMod((nz(usuario) + "|" + nz(wTela)).hashCode(), 100);
        return bucket < p;
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
