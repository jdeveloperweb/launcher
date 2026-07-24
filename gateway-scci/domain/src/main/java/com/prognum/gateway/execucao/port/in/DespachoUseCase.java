package com.prognum.gateway.execucao.port.in;

import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;

/**
 * Port de entrada: despacho /w. Valida a sessao (papel do launcher) e EXECUTA o programa real.
 * NENHUMA logica de programa aqui — so orquestracao.
 */
public interface DespachoUseCase {

    ResultadoExecucao despachar(ComandoExecucao comando);
}
