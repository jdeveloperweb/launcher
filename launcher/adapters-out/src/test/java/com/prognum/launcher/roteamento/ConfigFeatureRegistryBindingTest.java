package com.prognum.launcher.roteamento;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;

/**
 * Trava o bind da flag do roteador (Strangler) vindo do {@code application.yml}: a chave com ponto
 * ({@code documentos.GetDocumento}) precisa da notação de colchetes {@code [...]} para virar chave
 * LITERAL do mapa {@code flags} — senão o Spring a trataria como aninhamento e o roteador (que consulta
 * exatamente "documentos.GetDocumento") não acharia a flag.
 */
class ConfigFeatureRegistryBindingTest {

    private ConfigFeatureRegistry bind(Map<String, String> props) {
        Binder binder = new Binder(new MapConfigurationPropertySource(props));
        ConfigFeatureRegistry reg = new ConfigFeatureRegistry();
        binder.bind("launcher.roteamento", Bindable.ofInstance(reg));
        return reg;
    }

    @Test
    void chave_com_ponto_em_colchetes_vira_chave_literal() {
        ConfigFeatureRegistry reg = bind(Map.of(
                "launcher.roteamento.flags[documentos.GetDocumento].habilitado", "true"));
        // o roteador consulta exatamente este nome:
        assertThat(reg.consultar("documentos.GetDocumento")).isPresent();
        assertThat(reg.consultar("documentos.GetDocumento").orElseThrow().habilitado()).isTrue();
    }
}
