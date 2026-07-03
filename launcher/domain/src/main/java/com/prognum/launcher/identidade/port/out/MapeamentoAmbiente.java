package com.prognum.launcher.identidade.port.out;

import com.prognum.launcher.identidade.model.AmbienteOperacional;

/**
 * Port de saida: carrega o mapeamento do AMBIENTE OPERACIONAL (secao [USERS] do launcherenv.ini,
 * multi-banco). O adapter delega ao LauncherEnvReader (compartilhado) — sem duplicar o parser.
 */
public interface MapeamentoAmbiente {

    AmbienteOperacional carregar(String ambientePath);
}
