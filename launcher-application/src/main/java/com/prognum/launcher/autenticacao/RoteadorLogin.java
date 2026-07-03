package com.prognum.launcher.autenticacao;

import java.util.Optional;

import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.port.in.LoginUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Roteador do LOGIN (Strangler) — decorator do {@link LoginUseCase}. Pela feature-flag decide entre:
 * <ul>
 *   <li><b>JAVA</b> — o contexto acesso do scci-core ({@link AcessoJavaPort}); ou</li>
 *   <li><b>LOCAL</b> — o login Java do próprio launcher (fallback), como hoje.</li>
 * </ul>
 * Flag: {@code acesso.Login} (override) → {@code acesso} (default do domínio) → LOCAL. Fallback seguro:
 * scci-core fora → {@link Optional} vazio → LOCAL. POJO puro.
 */
public class RoteadorLogin implements LoginUseCase {

    private final LoginUseCase local;
    private final AcessoJavaPort java;
    private final FeatureRegistry flags;

    public RoteadorLogin(LoginUseCase local, AcessoJavaPort java, FeatureRegistry flags) {
        this.local = local;
        this.java = java;
        this.flags = flags;
    }

    @Override
    public ResultadoLogin login(String usuario, String senha, String ambiente, String ip) {
        if (usaJava()) {
            Optional<ResultadoLogin> r = java.login(usuario, senha, ambiente, ip);
            if (r.isPresent()) {
                return r.get();
            }
        }
        return local.login(usuario, senha, ambiente, ip);
    }

    private boolean usaJava() {
        Optional<FeatureFlag> especifica = flags.consultar("acesso.Login");
        if (especifica.isPresent()) {
            return especifica.get().habilitado();
        }
        return flags.consultar("acesso").map(FeatureFlag::habilitado).orElse(false);
    }
}
