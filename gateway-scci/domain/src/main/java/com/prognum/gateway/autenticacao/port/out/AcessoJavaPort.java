package com.prognum.gateway.autenticacao.port.out;

import java.util.Optional;

import com.prognum.gateway.autenticacao.model.ResultadoLogin;
import com.prognum.gateway.autenticacao.model.ResultadoTroca;

/**
 * Port de saída do EDGE para o contexto {@code acesso} do scci-core (Java, escalável) — o caminho
 * JAVA/remoto dos roteadores Strangler do launcher. Espelha os use cases de auth.
 *
 * Semântica do {@link Optional} (igual ao {@code DocumentosJavaPort}): vazio = scci-core INDISPONÍVEL
 * (→ fallback para o auth LOCAL do launcher). Um resultado de NEGÓCIO (login negado, CPF inválido, etc.)
 * volta preenchido — não faz fallback, pois o local responderia igual.
 *
 * <p><b>Recuperação de senha ("esqueci minha senha", ExecutaEmailPwd do loginbd)</b> reintroduzida:
 * {@code recuperar} gera senha temporária, grava forçando troca no próximo login e envia por e-mail.</p>
 */
public interface AcessoJavaPort {

    Optional<ResultadoLogin> login(String usuario, String senha, String ambiente, String ip);

    Optional<ResultadoTroca> trocarSenha(String usuario, String senhaAtual, String novaSenha, String ambiente);

    /** Recuperação de senha por e-mail ("esqueci minha senha") — endpoint /w/email-pwd. */
    Optional<ResultadoTroca> recuperar(String usuario, String cpf, String ambiente);

    Optional<Boolean> validarCpf(String valor, String ambiente);

    Optional<Boolean> validarProtocolo(String valor, String ambiente);
}
