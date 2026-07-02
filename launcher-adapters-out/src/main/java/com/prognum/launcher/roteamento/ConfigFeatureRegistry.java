package com.prognum.launcher.roteamento;

import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Registro de feature flags do roteador Strangler dirigido por CONFIGURAÇÃO (application.yml). Vazio
 * por padrão (nenhuma rota alternativa ligada) — então o comportamento é o mesmo do scaffold anterior,
 * mas agora as flags podem ser LIGADAS por config, sem código:
 * <pre>
 * launcher:
 *   roteamento:
 *     flags:
 *       login-legado:  { habilitado: true, percentual: 10 }
 * </pre>
 * Quando houver rota alternativa (ex.: proxy p/ o launcher Pascal), a decisão A/B/C consulta aqui.
 */
@Component
@ConfigurationProperties(prefix = "launcher.roteamento")
public class ConfigFeatureRegistry implements FeatureRegistry {

    private final Map<String, Flag> flags = new LinkedHashMap<>();

    public Map<String, Flag> getFlags() {
        return flags;
    }

    @Override
    public Optional<FeatureFlag> consultar(String nome) {
        Flag f = nome == null ? null : flags.get(nome);
        return f == null ? Optional.empty()
                : Optional.of(new FeatureFlag(nome, f.isHabilitado(), f.getPercentual()));
    }

    /** Config de uma flag: habilitada? e o percentual de rollout (0..100). */
    public static class Flag {
        private boolean habilitado;
        private int percentual;

        public Flag() {
        }

        public Flag(boolean habilitado, int percentual) {
            this.habilitado = habilitado;
            this.percentual = percentual;
        }

        public boolean isHabilitado() {
            return habilitado;
        }

        public void setHabilitado(boolean habilitado) {
            this.habilitado = habilitado;
        }

        public int getPercentual() {
            return percentual;
        }

        public void setPercentual(int percentual) {
            this.percentual = percentual;
        }
    }
}
