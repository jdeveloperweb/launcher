package com.prognum.launcher.autenticacao;

import java.util.Optional;

import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.port.in.TrocarSenhaUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Roteador da TROCA DE SENHA (Strangler) — decorator do {@link TrocarSenhaUseCase}. Flag
 * {@code acesso.TrocaSenha} → {@code acesso} → LOCAL. scci-core fora → fallback local. POJO puro.
 */
public class RoteadorTrocarSenha implements TrocarSenhaUseCase {

    private final TrocarSenhaUseCase local;
    private final AcessoJavaPort java;
    private final FeatureRegistry flags;

    public RoteadorTrocarSenha(TrocarSenhaUseCase local, AcessoJavaPort java, FeatureRegistry flags) {
        this.local = local;
        this.java = java;
        this.flags = flags;
    }

    @Override
    public ResultadoTroca trocar(String usuario, String senhaAtual, String novaSenha, String ambiente) {
        if (usaJava()) {
            Optional<ResultadoTroca> r = java.trocarSenha(usuario, senhaAtual, novaSenha, ambiente);
            if (r.isPresent()) {
                return r.get();
            }
        }
        return local.trocar(usuario, senhaAtual, novaSenha, ambiente);
    }

    private boolean usaJava() {
        Optional<FeatureFlag> especifica = flags.consultar("acesso.TrocaSenha");
        if (especifica.isPresent()) {
            return especifica.get().habilitado();
        }
        return flags.consultar("acesso").map(FeatureFlag::habilitado).orElse(false);
    }
}
