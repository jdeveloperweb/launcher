package com.prognum.scci.acesso.domain.port.out;

import com.prognum.scci.acesso.domain.policy.PasswordPolicy;

/**
 * Resolve a POLITICA DE SENHA do ambiente (parametrizacao por cliente, lida do launcherenv.ini).
 * Sem chaves de politica no {@code .ini} = politica permissiva (SEM exigencia de composicao) — para
 * nao ser mais rigido que o launcher legado quando o cliente nao configura nada.
 */
public interface PoliticaSenhaResolver {

    PasswordPolicy resolver(String ambiente);
}
