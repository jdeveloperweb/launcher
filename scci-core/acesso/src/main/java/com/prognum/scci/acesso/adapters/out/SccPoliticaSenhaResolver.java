package com.prognum.scci.acesso.adapters.out;

import org.springframework.stereotype.Component;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.PoliticaSenhaIni;
import com.prognum.scci.acesso.domain.policy.PasswordPolicy;
import com.prognum.scci.acesso.domain.port.out.PoliticaSenhaResolver;

/**
 * Adapter da politica de senha por-ambiente: le as chaves de politica do launcherenv.ini (via
 * {@link LauncherEnvReader#politicaSenha}) e monta a {@link PasswordPolicy}. Sem chaves = politica
 * permissiva (sem composicao), igual ao original quando o cliente nao configura.
 */
@Component
public class SccPoliticaSenhaResolver implements PoliticaSenhaResolver {

    private final LauncherEnvReader env;

    public SccPoliticaSenhaResolver(LauncherEnvReader env) {
        this.env = env;
    }

    @Override
    public PasswordPolicy resolver(String ambiente) {
        return montar(env.politicaSenha(ambiente));
    }

    /** Mapeia as chaves do .ini -> PasswordPolicy. requerComposicao = existe algum minimo de composicao. */
    static PasswordPolicy montar(PoliticaSenhaIni p) {
        boolean composicao = p.minLetras() > 0 || p.minMaiusculas() > 0
                || p.minDigitos() > 0 || p.minEspeciais() > 0;
        return new PasswordPolicy(p.minCaracteres(), composicao, p.minLetras(), p.minMaiusculas(),
                p.minDigitos(), p.minEspeciais(), p.maxRepetidos(), p.maxSequenciais());
    }
}
