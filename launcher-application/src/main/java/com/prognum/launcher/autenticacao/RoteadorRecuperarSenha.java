package com.prognum.launcher.autenticacao;

import java.util.Optional;

import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.port.in.RecuperarSenhaUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Roteador da RECUPERAÇÃO DE SENHA (Strangler) — decorator do {@link RecuperarSenhaUseCase}. Flag
 * {@code acesso.EmailPwd} → {@code acesso} → LOCAL. scci-core fora → fallback local. POJO puro.
 */
public class RoteadorRecuperarSenha implements RecuperarSenhaUseCase {

    private final RecuperarSenhaUseCase local;
    private final AcessoJavaPort java;
    private final FeatureRegistry flags;

    public RoteadorRecuperarSenha(RecuperarSenhaUseCase local, AcessoJavaPort java, FeatureRegistry flags) {
        this.local = local;
        this.java = java;
        this.flags = flags;
    }

    @Override
    public ResultadoTroca recuperar(String usuario, String cpf, String ambiente) {
        if (usaJava()) {
            Optional<ResultadoTroca> r = java.recuperar(usuario, cpf, ambiente);
            if (r.isPresent()) {
                return r.get();
            }
        }
        return local.recuperar(usuario, cpf, ambiente);
    }

    private boolean usaJava() {
        Optional<FeatureFlag> especifica = flags.consultar("acesso.EmailPwd");
        if (especifica.isPresent()) {
            return especifica.get().habilitado();
        }
        return flags.consultar("acesso").map(FeatureFlag::habilitado).orElse(false);
    }
}
