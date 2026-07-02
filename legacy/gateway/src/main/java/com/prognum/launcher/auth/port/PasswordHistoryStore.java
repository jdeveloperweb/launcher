package com.prognum.launcher.auth.port;

import java.util.List;

/** Porta de saida: historico de hashes de senha (rodizio - RN-013). Hoje in-memory; depois banco. */
public interface PasswordHistoryStore {

    List<String> hashes(String usuario);

    /** Empurra um hash no historico do usuario, mantendo no maximo 'max' itens. */
    void push(String usuario, String hash, int max);
}
