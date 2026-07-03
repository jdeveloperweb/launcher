package com.prognum.scci.acesso.domain.port.out;

/**
 * Port de saida: contador de tentativas erradas (bloqueio progressivo / captcha).
 * Copia do LoginAttemptStore do legado. Redis (distribuido, TTL de auto-reset).
 */
public interface ContadorTentativas {

    int registerFailure(String usuario);

    int get(String usuario);

    void reset(String usuario);
}
