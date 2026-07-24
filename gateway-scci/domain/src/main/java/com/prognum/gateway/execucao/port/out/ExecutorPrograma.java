package com.prognum.gateway.execucao.port.out;

import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;

/**
 * Port de saida: executa o binario "w" real (wmenu/wtela/...) falando o protocolo de blocos do
 * oserver (socketpair + posix_spawn via JNA). O adapter NAO contem logica de programa.
 */
public interface ExecutorPrograma {

    ResultadoExecucao executar(ComandoExecucao comando);
}
