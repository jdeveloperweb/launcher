package com.prognum.gateway.autenticacao.scc;

import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.gateway.autenticacao.port.out.SegurancaIntegracao;
import org.springframework.stereotype.Component;

/**
 * Adapter de saida: le o {@code SEG_IDENTIFICACAO} do {@code [SEGURANCA]} do launcherenv.ini do ambiente
 * (via o {@link LauncherEnvReader} compartilhado) — a chave fixa da conta de integracao {@code loginintegracao}.
 */
@Component
public class SegurancaIntegracaoScc implements SegurancaIntegracao {

    private final LauncherEnvReader env;

    public SegurancaIntegracaoScc(LauncherEnvReader env) {
        this.env = env;
    }

    @Override
    public String identificacao(String ambiente) {
        return ambiente == null ? null : env.segIdentificacao(ambiente);
    }
}
