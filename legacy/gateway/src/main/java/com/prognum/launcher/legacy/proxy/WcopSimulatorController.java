package com.prognum.launcher.legacy.proxy;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Simulador embutido do W_COP (apenas para desenvolvimento).
 * Recebe o que a Rota C encaminharia e devolve uma resposta JSON simulada.
 *
 * Aceita QUALQUER profundidade sob /__wcop-sim/** (extrai os 2 ultimos segmentos como
 * programa/metodo). Isso evita que chamadas com 3+ segmentos "vazem" para o catch-all
 * e causem recursao.
 *
 * Liga/desliga por 'launcher.legacy.wcop.simulator.enabled' (default true).
 */
@RestController
@ConditionalOnProperty(name = "launcher.legacy.wcop.simulator.enabled", havingValue = "true", matchIfMissing = true)
public class WcopSimulatorController {

    private static final String PREFIXO = "/__wcop-sim";

    @RequestMapping("/__wcop-sim/**")
    public Map<String, Object> handle(HttpServletRequest req) {
        String uri = req.getRequestURI();
        String sub = uri.length() > PREFIXO.length() ? uri.substring(PREFIXO.length()) : "";
        String[] seg = Arrays.stream(sub.split("/")).filter(s -> !s.isBlank()).toArray(String[]::new);
        String programa = seg.length >= 2 ? seg[seg.length - 2] : (seg.length == 1 ? seg[0] : "");
        String metodo = seg.length >= 1 ? seg[seg.length - 1] : "";

        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("simulador", "W_COP (simulado)");
        resp.put("programa", programa);
        resp.put("metodo", metodo);
        resp.put("caminho", sub);
        resp.put("obs", "Resposta simulada. Troque launcher.legacy.wcop.base-url pela URL real do W_COP "
                + "e desligue launcher.legacy.wcop.simulator.enabled para usar o servico de verdade.");
        return resp;
    }
}
