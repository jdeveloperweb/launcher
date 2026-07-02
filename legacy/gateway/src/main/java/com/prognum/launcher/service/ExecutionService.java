package com.prognum.launcher.service;

import com.prognum.launcher.api.dto.ExecuteRequest;
import com.prognum.launcher.api.dto.ExecuteResponse;
import com.prognum.launcher.gateway.ExecutionRouter;
import com.prognum.launcher.gateway.RouteDecision;
import com.prognum.launcher.legacy.executor.ProcessBuilderExecutor;
import com.prognum.launcher.legacy.proxy.LegacyProxyClient;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.util.UUID;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Orquestra a execucao: decide a rota (A/B/C) e delega ao destino.
 * Mantem o contrato de resposta padronizado (regras.md RF07) e registra um evento
 * estruturado com a rota escolhida e a duracao (RF09/RNF06).
 */
@Service
public class ExecutionService {

    private static final Logger log = LoggerFactory.getLogger(ExecutionService.class);

    private final ExecutionRouter router;
    private final ProcessBuilderExecutor executor;
    private final LegacyProxyClient legacy;

    public ExecutionService(ExecutionRouter router,
                            ProcessBuilderExecutor executor,
                            LegacyProxyClient legacy) {
        this.router = router;
        this.executor = executor;
        this.legacy = legacy;
    }

    public ExecuteResponse execute(ExecuteRequest req, String requestId) {
        if (requestId == null || requestId.isBlank()) {
            requestId = UUID.randomUUID().toString();
        }
        long inicio = System.nanoTime();
        RouteDecision rota = router.route(req);

        ExecuteResponse resp;
        try {
            Object data = switch (rota) {
                case NATIVE_JAVA ->
                        throw new UnsupportedOperationException("Rota A (Java nativo) ainda nao implementada");
                case PROCESS_BUILDER -> executor.run(req);
                case LEGACY_PROXY -> legacy.proxy(req);
            };
            resp = new ExecuteResponse(true, "ok", data, requestId, rota.name());
        } catch (Exception e) {
            // Fase 1 (RF07): erro de negocio retorna 200 + success:false.
            resp = new ExecuteResponse(false, e.getMessage(), null, requestId, rota.name());
        }

        long ms = (System.nanoTime() - inicio) / 1_000_000;
        log.info("execute",
                kv("rota", rota.name()),
                kv("usuario", req.usuario()),
                kv("wTela", req.wTela()),
                kv("programa", req.programa()),
                kv("metodo", req.metodo()),
                kv("sucesso", resp.success()),
                kv("duracaoMs", ms));
        return resp;
    }
}
