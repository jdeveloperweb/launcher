package com.prognum.launcher.gateway;

import java.util.List;

/**
 * Feature Registry (regras.md RF11): fonte das decisoes de rota e do kill-switch.
 * Hoje in-memory; depois banco + cache (Redis), mantendo esta porta.
 */
public interface FeatureRegistry {

    boolean killSwitchGlobal();

    void setKillSwitchGlobal(boolean on);

    boolean isNativeJava(String wTela, String usuario, String ambiente);

    boolean isLegacyProxyRequired(String wTela, String usuario, String ambiente);

    List<FeatureFlag> list();

    void upsert(FeatureFlag flag);

    boolean remove(String id);
}
