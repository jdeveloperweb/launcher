package com.prognum.launcher.execucao.port.in;

import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.execucao.model.ResultadoExecucao;

/**
 * Port de entrada: despacho /w. Valida a sessao (papel do launcher) e EXECUTA o programa real.
 * NENHUMA logica de programa aqui — so orquestracao.
 */
public interface DespachoUseCase {

    ResultadoExecucao despachar(ComandoExecucao comando);
}
