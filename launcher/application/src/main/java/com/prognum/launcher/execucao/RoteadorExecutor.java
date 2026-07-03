package com.prognum.launcher.execucao;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.execucao.model.ResultadoExecucao;
import com.prognum.launcher.execucao.port.out.ExecutorPrograma;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Roteador da EXECUÇÃO de programas Pascal (Strangler) — decorator do {@link ExecutorPrograma}. Pela
 * flag {@code executor.remoto} decide entre:
 * <ul>
 *   <li><b>REMOTO</b> — o serviço {@code pascal-executor} (JNA fora do launcher); ou</li>
 *   <li><b>LOCAL</b> — a ponte JNA in-process do próprio launcher (fallback / transição).</li>
 * </ul>
 * Fallback seguro: se o pascal-executor estiver fora (erro de transporte), cai no LOCAL. Quando a flag
 * for promovida e o LOCAL removido (launcher Java puro), o fallback deixa de existir. POJO puro.
 */
public class RoteadorExecutor implements ExecutorPrograma {

    private static final Logger log = LoggerFactory.getLogger(RoteadorExecutor.class);

    private final ExecutorPrograma local;
    private final ExecutorPrograma remoto;
    private final FeatureRegistry flags;

    public RoteadorExecutor(ExecutorPrograma local, ExecutorPrograma remoto, FeatureRegistry flags) {
        this.local = local;
        this.remoto = remoto;
        this.flags = flags;
    }

    @Override
    public ResultadoExecucao executar(ComandoExecucao comando) {
        if (usaRemoto()) {
            try {
                return remoto.executar(comando);
            } catch (RuntimeException e) {
                log.warn("pascal_executor_indisponivel programa={} metodo={} erro={} -> fallback local",
                        comando.programName(), comando.methodName(), String.valueOf(e.getMessage()));
            }
        }
        return local.executar(comando);
    }

    private boolean usaRemoto() {
        return flags.consultar("executor.remoto").map(FeatureFlag::habilitado).orElse(false);
    }
}
