package com.prognum.gateway.compartilhado.web;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.RecargaAmbiente;
import com.prognum.common.environment.ResolvedorAmbiente;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Admin operacional: RECARREGA a configuracao em RUNTIME, sem reiniciar o processo nem esperar o TTL —
 * o SIGHUP do launcher legado (ver {@link RecargaAmbiente}). Aqui: o launcher.conf ([DIRETORIOS], via
 * {@link ResolvedorAmbiente#recarregar}) e o cache do launcherenv.ini. Cada servico (gateway/scci-core/
 * pascal-executor) tem o seu cache e o mesmo endpoint.
 *
 * <p>Deixe atras da borda (Kong/rede interna) — é operação administrativa, nao pública.</p>
 */
@RestController
public class AdminAmbienteController {

    private static final Logger log = LoggerFactory.getLogger(AdminAmbienteController.class);

    private final ResolvedorAmbiente resolvedor;
    private final RecargaAmbiente recarga;

    public AdminAmbienteController(LauncherEnvReader env, ResolvedorAmbiente resolvedor) {
        this.resolvedor = resolvedor;
        this.recarga = new RecargaAmbiente(env);
    }

    /**
     * Recarrega TODOS os ambientes (sem ?ambiente) ou apenas um (?ambiente=/cdhu-launcher-java/api, virtual ou
     * fisico). {@code ?variavel=DATAH} (repetivel) mostra o valor que o programa vai receber.
     */
    @PostMapping("/admin/env/reload")
    public ResponseEntity<Map<String, Object>> reload(@RequestParam(required = false) String ambiente,
                                                      @RequestParam(name = "variavel", required = false)
                                                      List<String> variaveis) {
        resolvedor.recarregar();   // antes de traduzir: o [DIRETORIOS] pode ter mudado
        String fisico = ambiente == null || ambiente.isBlank() ? null : resolvedor.resolver(ambiente);
        Map<String, Object> r = recarga.recarregar(fisico, variaveis);
        log.info("env_reload", kv("escopo", r.get("reloaded")));
        return ResponseEntity.ok(r);
    }
}
