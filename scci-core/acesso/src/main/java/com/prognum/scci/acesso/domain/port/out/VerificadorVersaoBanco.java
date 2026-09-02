package com.prognum.scci.acesso.domain.port.out;

import java.util.Optional;

/**
 * Porta de saida: valida no login a compatibilidade da versao do BANCO com a versao do SISTEMA
 * (porte do {@code TestaVersaoBanco} do wae.pas, disparado pela variavel {@code VERIFICAVERSAOBANCO}
 * do launcherenv.ini). O legado roda essa checagem dentro do {@code CarregaAmbiente} (pos-login);
 * como o login do reator e Java, o coordenador a chama apos autenticar.
 *
 * <p>Devolve a MENSAGEM de bloqueio quando incompativel (o coordenador nega o login com ela);
 * {@link Optional#empty()} = ok — versao casa OU a verificacao esta desligada.</p>
 */
public interface VerificadorVersaoBanco {

    /** Mensagem de bloqueio (versao incompativel / instalacao pendente), ou vazio se pode logar. */
    Optional<String> incompatibilidade(String ambiente);
}
