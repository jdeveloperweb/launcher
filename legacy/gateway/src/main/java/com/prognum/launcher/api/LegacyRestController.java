package com.prognum.launcher.api;

import com.prognum.launcher.api.dto.ExecuteRequest;
import com.prognum.launcher.gateway.ExecutionRouter;
import com.prognum.launcher.gateway.RouteDecision;
import com.prognum.launcher.legacy.executor.ProcessBuilderExecutor;
import com.prognum.launcher.legacy.proxy.LegacyProxyClient;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Compatibilidade com o front legado (regras.md): o Apache encaminha
 * /aejs-l/rest/&lt;...&gt;/&lt;programa&gt;/&lt;metodo&gt; para ca (ja sem o prefixo /aejs-l/rest/).
 *
 * Catch-all: pega QUALQUER caminho nao mapeado pelos controllers /v1, /actuator e
 * /__wcop-sim, extrai os 2 ULTIMOS segmentos como programa/metodo (igual o W_COP),
 * decide a rota A/B/C e:
 *   - Rota C (LEGACY_PROXY): repassa a requisicao TRANSPARENTE para o W_COP e
 *     devolve a resposta crua (status + corpo) — o front nem percebe o gateway.
 *   - Rota B (PROCESS_BUILDER): executa o .exe Pascal (hoje simulado).
 *   - Rota A (NATIVE_JAVA): ainda nao implementada por programa/metodo.
 */
@RestController
public class LegacyRestController {

    private static final Logger log = LoggerFactory.getLogger(LegacyRestController.class);

    private final ExecutionRouter router;
    private final LegacyProxyClient legacy;
    private final ProcessBuilderExecutor executor;

    public LegacyRestController(ExecutionRouter router, LegacyProxyClient legacy, ProcessBuilderExecutor executor) {
        this.router = router;
        this.legacy = legacy;
        this.executor = executor;
    }

    @RequestMapping("/**")
    public ResponseEntity<?> handle(HttpServletRequest req, @RequestBody(required = false) byte[] body) {
        String uri = req.getRequestURI();                 // ex.: /w/login  (Apache ja tirou /aejs-l/rest/)

        // Guarda anti-recursao: nunca re-proxiar uma chamada que ja saiu do proprio gateway,
        // nem caminhos internos do simulador (evita o loop /__wcop-sim/__wcop-sim/...).
        if (req.getHeader("X-Gateway-Forwarded") != null || uri.startsWith("/__wcop-sim")) {
            return ResponseEntity.status(404).body("rota nao encontrada: " + uri);
        }

        String[] seg = Arrays.stream(uri.split("/"))
                .filter(s -> !s.isBlank())
                .toArray(String[]::new);

        if (seg.length == 0) {
            return ResponseEntity.ok("Launcher Gateway no ar. Use /aejs-l/rest/<programa>/<metodo>.");
        }
        String programa = seg.length >= 2 ? seg[seg.length - 2] : seg[0];
        String metodo   = seg[seg.length - 1];

        ExecuteRequest er = new ExecuteRequest(
                programa, metodo, programa,
                req.getHeader("X-Ambiente"),
                req.getHeader("X-Usuario"),
                null);

        RouteDecision rota = router.route(er);
        log.info("rest_compat", kv("uri", uri), kv("programa", programa), kv("metodo", metodo),
                kv("metodoHttp", req.getMethod()), kv("rota", rota));

        return switch (rota) {
            case LEGACY_PROXY   -> legacy.forward(req, body, uri);          // transparente -> W_COP
            case PROCESS_BUILDER -> ResponseEntity.ok(executor.run(er));    // .exe (simulado)
            case NATIVE_JAVA    -> ResponseEntity.status(501).body(
                    "Rota A (Java nativo) ainda nao implementada para " + programa + "/" + metodo);
        };
    }
}
