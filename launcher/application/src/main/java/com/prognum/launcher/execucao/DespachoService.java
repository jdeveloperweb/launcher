package com.prognum.launcher.execucao;

import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.execucao.model.ResultadoExecucao;
import com.prognum.launcher.execucao.port.in.DespachoUseCase;
import com.prognum.launcher.execucao.port.out.ExecutorPrograma;

/**
 * Caso de uso do despacho /w: o launcher executa o programa "w" real. A validacao de sessao ja foi
 * feita no adapter de entrada (resolve usuario/ambiente da sessao). Aqui delega ao executor.
 *
 * PONTO DE EXTENSAO: quando a AUTORIZACAO por operacao (AutorizacaoPort) for portada, a checagem
 * de permissao entra aqui, ANTES de executar (ver pendencia de contexto de sessao nas REGRAS).
 */
public class DespachoService implements DespachoUseCase {

    private final ExecutorPrograma executor;

    public DespachoService(ExecutorPrograma executor) {
        this.executor = executor;
    }

    @Override
    public ResultadoExecucao despachar(ComandoExecucao comando) {
        return executor.executar(comando);
    }
}
