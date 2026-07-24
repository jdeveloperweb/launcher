package com.prognum.launcher.port;

import com.prognum.launcher.model.ComandoExecucao;
import com.prognum.launcher.model.ResultadoExecucao;

/**
 * Port de saida: executa o binario "w" real (wmenu/wtela/...) falando o protocolo de blocos do
 * oserver (socketpair + posix_spawn via JNA). O adapter NAO contem logica de programa.
 */
public interface ExecutorPrograma {

    ResultadoExecucao executar(ComandoExecucao comando);
}
