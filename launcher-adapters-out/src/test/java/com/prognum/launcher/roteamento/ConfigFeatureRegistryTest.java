package com.prognum.launcher.roteamento;

import com.prognum.launcher.roteamento.model.FeatureFlag;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Registro de feature flags dirigido por config (Strangler). Vazio = nenhuma rota alternativa. */
class ConfigFeatureRegistryTest {

    private final ConfigFeatureRegistry reg = new ConfigFeatureRegistry();

    @Test
    void vazio_por_padrao_nao_liga_nada() {
        assertThat(reg.consultar("qualquer")).isEmpty();
        assertThat(reg.consultar(null)).isEmpty();
    }

    @Test
    void flag_configurada_e_devolvida() {
        reg.getFlags().put("login-legado", new ConfigFeatureRegistry.Flag(true, 25));
        FeatureFlag f = reg.consultar("login-legado").orElseThrow();
        assertThat(f.nome()).isEqualTo("login-legado");
        assertThat(f.habilitado()).isTrue();
        assertThat(f.percentual()).isEqualTo(25);
    }
}
