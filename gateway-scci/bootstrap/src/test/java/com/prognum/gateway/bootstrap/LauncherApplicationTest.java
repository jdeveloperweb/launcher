package com.prognum.gateway.bootstrap;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * Valida que o contexto do reator SOBE com todo o wiring domain-first (controllers, casos de uso
 * POJO, adapters @Component, WcopCrypto/PasswordPolicy). webEnvironment MOCK: nao abre a porta 8083
 * nem conecta no banco (a conexao e por-request). Se algum bean/port faltar, este teste quebra.
 */
@SpringBootTest
class LauncherApplicationTest {

    @Test
    void contextLoads() {
        // sobe o contexto completo; sem asserts — a subida ja e a verificacao
    }
}
