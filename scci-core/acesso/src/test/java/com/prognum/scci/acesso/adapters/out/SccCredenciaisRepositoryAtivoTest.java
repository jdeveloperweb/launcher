package com.prognum.scci.acesso.adapters.out;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Interpretacao do valor da coluna USERACTIVE (SccCredenciaisRepository.interpretaAtivo): conservador —
 * so os marcadores explicitos de inativo bloqueiam; ausencia/nulo/valor desconhecido = ativo.
 */
class SccCredenciaisRepositoryAtivoTest {

    @Test
    void marcadoresDeInativo_bloqueiam() {
        for (String v : new String[]{"N", "n", "F", "I", "0", "Nao", "INATIVO", " desativado "}) {
            assertFalse(SccCredenciaisRepository.interpretaAtivo(v), "'" + v + "' deve ser inativo");
        }
    }

    @Test
    void ativoOuDesconhecido_naoBloqueia() {
        for (String v : new String[]{null, "", "  ", "S", "T", "1", "A", "SIM", "ATIVO", "?"}) {
            assertTrue(SccCredenciaisRepository.interpretaAtivo(v),
                    "'" + v + "' nao deve bloquear (default = ativo)");
        }
    }
}
