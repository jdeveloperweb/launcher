package com.prognum.launcher.autenticacao;

import java.util.Optional;

import com.prognum.launcher.autenticacao.port.in.ValidarAcessoUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Roteador do VALIDA-ACESSO (Strangler) — decorator do {@link ValidarAcessoUseCase} (ValidaCpf/
 * ValidaProtocolo). Flag {@code acesso.ValidaAcesso} → {@code acesso} → LOCAL. scci-core fora →
 * fallback local. POJO puro.
 */
public class RoteadorValidarAcesso implements ValidarAcessoUseCase {

    private final ValidarAcessoUseCase local;
    private final AcessoJavaPort java;
    private final FeatureRegistry flags;

    public RoteadorValidarAcesso(ValidarAcessoUseCase local, AcessoJavaPort java, FeatureRegistry flags) {
        this.local = local;
        this.java = java;
        this.flags = flags;
    }

    @Override
    public boolean cpfValido(String valor, String ambiente) {
        if (usaJava()) {
            Optional<Boolean> r = java.validarCpf(valor, ambiente);
            if (r.isPresent()) {
                return r.get();
            }
        }
        return local.cpfValido(valor, ambiente);
    }

    @Override
    public boolean protocoloValido(String valor, String ambiente) {
        if (usaJava()) {
            Optional<Boolean> r = java.validarProtocolo(valor, ambiente);
            if (r.isPresent()) {
                return r.get();
            }
        }
        return local.protocoloValido(valor, ambiente);
    }

    private boolean usaJava() {
        Optional<FeatureFlag> especifica = flags.consultar("acesso.ValidaAcesso");
        if (especifica.isPresent()) {
            return especifica.get().habilitado();
        }
        return flags.consultar("acesso").map(FeatureFlag::habilitado).orElse(false);
    }
}
