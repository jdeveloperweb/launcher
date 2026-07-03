package com.prognum.scci.acesso.adapters.out;

import com.prognum.scci.acesso.domain.port.out.MetodoLoginResolver;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Collections;
import java.util.Map;

/**
 * Resolve o método de login por CONFIGURAÇÃO do cliente (application.yml
 * {@code scci.auth.metodos}: mapa "trecho-do-ambiente -> METODO"). Se nenhum casar, usa BANCO
 * (loginbd) — como a maioria dos clientes hoje. Ex.:
 * <pre>
 * scci.auth.metodos:
 *   c6bank: OAUTH
 *   sicredi: API_SICREDI
 * </pre>
 * A chave casa se aparecer no caminho do ambiente (ex.: "/u10/c6bank/..." casa "c6bank").
 */
@Component
public class MetodoLoginPadrao implements MetodoLoginResolver {

    private final Map<String, String> metodos;

    public MetodoLoginPadrao(
            @Value("#{${scci.auth.metodos:{:}}}") Map<String, String> metodos) {
        this.metodos = metodos == null ? Collections.emptyMap() : metodos;
    }

    @Override
    public String metodoDe(String ambiente) {
        if (ambiente != null) {
            for (Map.Entry<String, String> e : metodos.entrySet()) {
                if (ambiente.contains(e.getKey())) {
                    return e.getValue();
                }
            }
        }
        return "BANCO";
    }
}
