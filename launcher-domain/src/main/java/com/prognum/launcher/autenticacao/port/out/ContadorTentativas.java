package com.prognum.launcher.autenticacao.port.out;

/**
 * Port de saida: contador de tentativas erradas (bloqueio progressivo / captcha).
 * Copia do LoginAttemptStore do legado. Hoje in-memory; depois Redis para distribuir.
 */
public interface ContadorTentativas {

    int registerFailure(String usuario);

    int get(String usuario);

    void reset(String usuario);
}
