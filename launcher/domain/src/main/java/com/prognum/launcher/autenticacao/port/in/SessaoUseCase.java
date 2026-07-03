package com.prognum.launcher.autenticacao.port.in;

import com.prognum.launcher.autenticacao.model.Sessao;

import java.util.Optional;

/**
 * Port de entrada: gestao da sessao emitida no login. O login REGISTRA (Redis + SCCI_SESSION);
 * o despacho /w faz VALIDA (revalida o token antes de executar o programa — papel do launcher).
 */
public interface SessaoUseCase {

    /** Login: registra a sessao (cache Redis + SCCI_SESSION autoritativo). */
    void registrar(String sessionKey, String usuario, String ambienteOperacional, String ip);

    /** Consulta simples pela sessionKey (cache) — usada na troca de senha. */
    Optional<Sessao> consultar(String sessionKey);

    /**
     * VALIDA (despacho /w): revalida o token antes de executar. Cache (Redis) primeiro; no miss,
     * confere na SCCI_SESSION com o usuario informado. Vazio = sessao invalida/expirada.
     */
    Optional<Sessao> validar(String sessionKey, String usuarioInformado, String ambienteInformado);

    /** Logout: encerra a sessao (Redis + SCCI_SESSION). */
    void encerrar(String sessionKey);

    /** Sessoes ativas do usuario (limite de acessos simultaneos — QtMaxLogin do launcher). */
    int contarSessoesAtivas(String usuario, String ambiente);
}
