package com.prognum.scci;

import com.prognum.common.crypto.LogAnonimizador;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * Aplica no boot a política de anonimização de USUÁRIO nos logs do scci-core, a partir de
 * {@code scci.log.anonimizar-usuario} (default {@code true} = anonimizado, req 2.7). Espelha o
 * {@code LauncherLogConfig} do launcher — em ambiente interno/ops pode-se desligar (usuário real).
 */
@Component
public class SccLogConfig {

    public SccLogConfig(@Value("${scci.log.anonimizar-usuario:true}") boolean anonimizarUsuario) {
        LogAnonimizador.setAnonimizarUsuario(anonimizarUsuario);
    }
}
