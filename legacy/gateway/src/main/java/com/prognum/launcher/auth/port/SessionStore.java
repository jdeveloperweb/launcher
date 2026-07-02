package com.prognum.launcher.auth.port;

import com.prognum.launcher.auth.domain.Session;

import java.util.Optional;

/** Porta de saida: store de sessao. Hoje in-memory; depois Redis (adapter). */
public interface SessionStore {

    String create(String usuario, String ambiente, String ip, long ttlSegundos);

    Optional<Session> get(String token);

    void invalidate(String token);

    /** Garante o limite de sessoes por usuario (logout automatico ao novo login). */
    void enforceLimit(String usuario, int maxPorUsuario);
}
