package com.prognum.launcher.autenticacao.port.out;

import java.util.Optional;

import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;

/**
 * Port de saída do EDGE para o contexto {@code acesso} do scci-core (Java, escalável) — o caminho
 * JAVA/remoto dos roteadores Strangler do launcher. Espelha os use cases de auth.
 *
 * Semântica do {@link Optional} (igual ao {@code DocumentosJavaPort}): vazio = scci-core INDISPONÍVEL
 * (→ fallback para o auth LOCAL do launcher). Um resultado de NEGÓCIO (login negado, CPF inválido, etc.)
 * volta preenchido — não faz fallback, pois o local responderia igual.
 */
public interface AcessoJavaPort {

    Optional<ResultadoLogin> login(String usuario, String senha, String ambiente, String ip);

    Optional<ResultadoTroca> trocarSenha(String usuario, String senhaAtual, String novaSenha, String ambiente);

    Optional<ResultadoTroca> recuperar(String usuario, String cpf, String ambiente);

    Optional<Boolean> validarCpf(String valor, String ambiente);

    Optional<Boolean> validarProtocolo(String valor, String ambiente);
}
