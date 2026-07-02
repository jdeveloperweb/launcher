package com.prognum.launcher.legacy.executor;

import com.prognum.launcher.api.dto.ExecuteRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Rota B (regras.md DA05/RF05): executa o programa Pascal (.exe) via ProcessBuilder,
 * por CLI/arquivo + TLV via stdin/stdout, SEM handoff de socket.
 *
 * Por enquanto roda em modo SIMULACAO ('launcher.executor.simulate=true'), devolvendo
 * uma resposta simulada. Com simulate=false, executaria o .exe real (gancho abaixo).
 */
@Component
public class ProcessBuilderExecutor {

    private final boolean simulate;

    public ProcessBuilderExecutor(@Value("${launcher.executor.simulate:true}") boolean simulate) {
        this.simulate = simulate;
    }

    public Object run(ExecuteRequest req) {
        if (simulate) {
            Map<String, Object> resp = new LinkedHashMap<>();
            resp.put("executor", "ProcessBuilder (simulado)");
            resp.put("programa", nz(req.programa()));
            resp.put("metodo", nz(req.metodo()));
            resp.put("params", req.params() == null ? Map.of() : req.params());
            resp.put("obs", "Execucao simulada. Com launcher.executor.simulate=false rodaria o .exe Pascal "
                    + "(CLI/arquivo + TLV stdin/stdout + encoding + timeout).");
            return resp;
        }
        // TODO: execucao real — ProcessBuilder do .exe (informar caminho/args), TLV stdin/stdout,
        // encoding UTF-8 <-> CP850, timeout e captura de stdout/stderr/exit code.
        throw new UnsupportedOperationException(
                "Execucao real (ProcessBuilder) ainda nao implementada — informe o caminho do .exe");
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
