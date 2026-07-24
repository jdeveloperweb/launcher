package com.prognum.scci;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

import com.prognum.launcher.oserver.ProgramExecutor;

/**
 * Modo HÍBRIDO do scci-core. Quando {@code scci.sdk.habilitado=true}, embute o {@code launcher-sdk}
 * (registra o {@link ProgramExecutor}) para rodar programas Pascal DIRETO, in-process, via o transporte
 * v2 UDS+shim (Java puro, VT-friendly — sem JNA/pinning/chdir global). O código de domínio que precisar
 * do legado injeta a porta {@code com.prognum.launcher.port.ExecutorPrograma}.
 *
 * <p>Default (flag ausente/false) = modo PURO: o {@code ProgramExecutor} NÃO é registrado; nenhum código
 * Pascal roda — o scci-core segue stateless e escalável. O MESMO artefato serve os dois modos; a
 * diferença é só o deploy (a flag). Config em application.yml: {@code scci.sdk} e {@code executor.*}
 * (transporte=uds por padrão no híbrido).</p>
 *
 * <p><b>Escopo desta fase:</b> a capacidade fica DISPONÍVEL (opt-in). Ainda não há operação de domínio
 * que a consuma nem roteamento no Gateway — isso vem com a primeira operação que precisar do Pascal.</p>
 */
@Configuration
@ConditionalOnProperty(name = "scci.sdk.habilitado", havingValue = "true")
@Import(ProgramExecutor.class)
class SdkHibridoConfig {
}
