package com.prognum.scci;

import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.RecargaAmbiente;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Admin operacional do scci-core: RECARREGA a configuracao em RUNTIME — o SIGHUP do launcher legado (ver
 * {@link RecargaAmbiente}). E aqui que o Pascal roda no modo hibrido, entao e este o endpoint para conferir
 * o ambiente que o programa recebe ({@code ?variavel=DATAH}). Recarrega o cache do launcherenv.ini e a
 * versao do sistema (scciver). NAO exposto ao front.
 */
@RestController
class AdminAmbienteController {

    private static final Logger log = LoggerFactory.getLogger(AdminAmbienteController.class);

    private final RecargaAmbiente recarga;

    AdminAmbienteController(LauncherEnvReader env, VersaoSistemaPascal versao) {
        this.recarga = new RecargaAmbiente(env, versao::limparCache);
    }

    /** Sem ?ambiente: todos. ?ambiente= e o caminho FISICO (ex.: /home/scci_data/dados/api). */
    @PostMapping("/admin/env/reload")
    public ResponseEntity<Map<String, Object>> reload(@RequestParam(required = false) String ambiente,
                                                      @RequestParam(name = "variavel", required = false)
                                                      List<String> variaveis) {
        Map<String, Object> r = recarga.recarregar(ambiente, variaveis);
        log.info("env_reload", kv("escopo", r.get("reloaded")));
        return ResponseEntity.ok(r);
    }
}
