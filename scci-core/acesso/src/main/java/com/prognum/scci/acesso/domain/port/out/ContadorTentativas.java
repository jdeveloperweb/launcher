package com.prognum.scci.acesso.domain.port.out;

/**
 * Port de saida: contador de tentativas erradas (bloqueio progressivo por excesso de tentativas).
 * Copia do LoginAttemptStore do legado. Redis (distribuido, TTL de auto-reset).
 * (Doc Final de Requisitos: escalonamento para captcha removido — fora do escopo inicial.)
 */
public interface ContadorTentativas {

    int registerFailure(String usuario);

    int get(String usuario);

    void reset(String usuario);
}
