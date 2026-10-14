package com.prognum.launcher.rest;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.RecargaAmbiente;

/**
 * Admin operacional do pascal-executor: RECARREGA a configuracao em RUNTIME — o SIGHUP do launcher legado
 * (ver {@link RecargaAmbiente}). {@code ?variavel=DATAH} mostra o valor que o programa vai receber.
 * NAO exposto ao front.
 */
@RestController
public class AdminAmbienteController {

    private final RecargaAmbiente recarga;

    public AdminAmbienteController(LauncherEnvReader env) {
        this.recarga = new RecargaAmbiente(env);
    }

    /** Sem ?ambiente: todos. ?ambiente= e o caminho FISICO do ambiente. */
    @PostMapping("/admin/env/reload")
    public ResponseEntity<Map<String, Object>> reload(@RequestParam(required = false) String ambiente,
                                                      @RequestParam(name = "variavel", required = false)
                                                      List<String> variaveis) {
        return ResponseEntity.ok(recarga.recarregar(ambiente, variaveis));
    }
}
