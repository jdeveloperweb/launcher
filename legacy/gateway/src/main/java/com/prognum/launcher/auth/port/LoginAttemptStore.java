package com.prognum.launcher.auth.port;

/**
 * Porta de saida: contador de tentativas erradas (bloqueio progressivo).
 * Hoje in-memory; depois Redis para o contador distribuido/persistente.
 */
public interface LoginAttemptStore {
    int registerFailure(String usuario);

    int get(String usuario);

    void reset(String usuario);
}
