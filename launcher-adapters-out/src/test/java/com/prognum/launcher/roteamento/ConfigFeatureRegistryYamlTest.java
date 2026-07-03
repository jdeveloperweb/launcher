package com.prognum.launcher.roteamento;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Bindable;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.ConfigurationPropertySources;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.PropertySource;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.io.ByteArrayResource;

/**
 * Descobre a forma YAML CERTA da flag do roteador — chave de mapa com ponto ({@code documentos.GetDocumento}).
 * Carrega o YAML igual ao Spring Boot (YamlPropertySourceLoader) e verifica o bind no
 * {@link ConfigFeatureRegistry}, do jeito que o roteador consulta.
 */
class ConfigFeatureRegistryYamlTest {

    private ConfigFeatureRegistry bindYaml(String yaml) throws Exception {
        List<PropertySource<?>> sources = new YamlPropertySourceLoader()
                .load("teste", new ByteArrayResource(yaml.getBytes()));
        StandardEnvironment env = new StandardEnvironment();
        sources.forEach(env.getPropertySources()::addFirst);
        ConfigFeatureRegistry reg = new ConfigFeatureRegistry();
        Binder.get(env).bind("launcher.roteamento", Bindable.ofInstance(reg));
        return reg;
    }

    private boolean ligada(ConfigFeatureRegistry reg) {
        return reg.consultar("documentos.GetDocumento").map(f -> f.habilitado()).orElse(false);
    }

    @Test
    void forma_colchetes_como_chave_yaml() throws Exception {
        // "[documentos.GetDocumento]" como chave do mapa flags (docs do Spring: colchetes p/ chave com ponto)
        ConfigFeatureRegistry reg = bindYaml("""
                launcher:
                  roteamento:
                    flags:
                      "[documentos.GetDocumento]":
                        habilitado: true
                """);
        assertThat(ligada(reg)).as("colchetes como chave YAML").isTrue();
    }

    @Test
    void forma_chave_plana_com_colchetes() throws Exception {
        // chave plana pontilhada com colchetes no proprio path
        ConfigFeatureRegistry reg = bindYaml("""
                "launcher.roteamento.flags[documentos.GetDocumento].habilitado": true
                """);
        assertThat(ligada(reg)).as("chave plana com colchetes").isTrue();
    }
}
