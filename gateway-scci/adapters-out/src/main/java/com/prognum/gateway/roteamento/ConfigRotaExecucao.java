package com.prognum.gateway.roteamento;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

import com.prognum.gateway.execucao.port.out.RotaExecucaoRegistry;

/**
 * Registro de rotas da EXECUÇÃO dirigido por CONFIGURAÇÃO (feature-flag). Vazio por padrão → tudo cai no
 * {@code rota-default} ({@code pascal}), ou seja, o comportamento legado. Liga-se por config, sem código:
 * <pre>
 * gateway:
 *   execucao:
 *     rota-default: pascal
 *     rotas:
 *       login:  puro       # 100% Java  -> scci-core PURO
 *       wmenu:  hibrido    # Java+Pascal -> scci-core HÍBRIDO
 *       wtelas: pascal     # legado
 * </pre>
 * (também editável em runtime via {@code --gateway.execucao.rotas.<programa>=<trilho>}, como faz o Configurador.)
 */
@Component
@ConfigurationProperties(prefix = "gateway.execucao")
public class ConfigRotaExecucao implements RotaExecucaoRegistry {

    private final Map<String, String> rotas = new LinkedHashMap<>();
    private String rotaDefault = "pascal";

    @Override
    public String trilho(String programa) {
        String t = programa == null ? null : rotas.get(programa);
        return normalizar(t != null ? t : rotaDefault);
    }

    /** Aceita só puro|hibrido|pascal; qualquer outra coisa vira pascal (falha segura para o legado). */
    private static String normalizar(String v) {
        String s = v == null ? "" : v.trim().toLowerCase(Locale.ROOT);
        return switch (s) {
            case "puro", "hibrido", "híbrido" -> s.startsWith("h") ? "hibrido" : "puro";
            default -> "pascal";
        };
    }

    public Map<String, String> getRotas() {
        return rotas;
    }

    public String getRotaDefault() {
        return rotaDefault;
    }

    public void setRotaDefault(String rotaDefault) {
        this.rotaDefault = rotaDefault;
    }
}
