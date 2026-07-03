package com.prognum.launcher.autenticacao.port.out;

import com.prognum.launcher.autenticacao.model.Sessao;

import java.util.Optional;

/**
 * Port de saida: armazenamento das sessoes emitidas no login (sessionKey -> Sessao).
 * No legado era um ConcurrentHashMap dentro do controller; aqui vira port (hoje in-memory).
 */
public interface RepositorioSessao {

    void salvar(String sessionKey, Sessao sessao);

    Optional<Sessao> buscar(String sessionKey);

    void remover(String sessionKey);
}
