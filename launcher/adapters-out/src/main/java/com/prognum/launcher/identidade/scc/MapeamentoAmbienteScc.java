package com.prognum.launcher.identidade.scc;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import com.prognum.launcher.identidade.model.AmbienteOperacional;
import com.prognum.launcher.identidade.port.out.MapeamentoAmbiente;
import org.springframework.stereotype.Component;

/**
 * Adapter de saida: carrega o AmbienteOperacional a partir do launcherenv.ini [USERS], delegando
 * ao LauncherEnvReader compartilhado (o mesmo que autenticacao usa). Sem duplicar o parser INI.
 */
@Component
public class MapeamentoAmbienteScc implements MapeamentoAmbiente {

    private final LauncherEnvReader env;

    public MapeamentoAmbienteScc(LauncherEnvReader env) {
        this.env = env;
    }

    @Override
    public AmbienteOperacional carregar(String ambientePath) {
        SccDbConfig c = env.ler(ambientePath);
        return new AmbienteOperacional(ambientePath, c.driver(), c.host(), c.database());
    }
}
