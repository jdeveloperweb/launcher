package com.prognum.scci.sessao.dominio.port.out;

import com.prognum.scci.sessao.dominio.model.Sessao;

import java.util.Optional;

/**
 * Port de saida: cache das sessoes emitidas no login (sessionKey -> Sessao). Redis COMPARTILHADO
 * com o launcher-edge (gate): o formato da chave/valor e o contrato entre os dois processos.
 */
public interface RepositorioSessao {

    void salvar(String sessionKey, Sessao sessao);

    Optional<Sessao> buscar(String sessionKey);

    void remover(String sessionKey);
}
