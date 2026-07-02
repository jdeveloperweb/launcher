package com.prognum.launcher.api;

import com.prognum.launcher.api.dto.ExecuteRequest;
import com.prognum.launcher.api.dto.ExecuteResponse;
import com.prognum.launcher.service.ExecutionService;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Endpoint unico do front-end (regras.md RF04): POST /v1/launcher/execute.
 * Propaga o request-id (gera se nao vier) para observabilidade (RF09/RNF06).
 */
@RestController
@RequestMapping("/v1/launcher")
public class LauncherExecuteController {

    private final ExecutionService service;

    public LauncherExecuteController(ExecutionService service) {
        this.service = service;
    }

    @PostMapping("/execute")
    public ExecuteResponse execute(@RequestBody ExecuteRequest req,
                                   @RequestHeader(value = "X-Request-Id", required = false) String requestId) {
        return service.execute(req, requestId);
    }
}
