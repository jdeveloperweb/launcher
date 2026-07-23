package com.prognum.launcher.bootstrap;

import com.prognum.common.crypto.LogAnonimizador;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Aplica no boot a política de anonimização de USUÁRIO nos logs, a partir da config
 * {@code launcher.log.anonimizar-usuario} (default {@code true} = anonimizado, req 2.7). Em ambiente
 * interno/ops pode-se desligar (ver o usuário real na chamada) sem tocar em IP/sessão, que continuam
 * mascarados/pseudonimizados. Setter estático porque {@link LogAnonimizador} é utilitário puro (sem Spring).
 */
@Component
public class LauncherLogConfig {

    public LauncherLogConfig(@Value("${launcher.log.anonimizar-usuario:true}") boolean anonimizarUsuario) {
        LogAnonimizador.setAnonimizarUsuario(anonimizarUsuario);
    }
}
