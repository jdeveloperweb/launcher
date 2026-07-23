package com.prognum.scci.acesso.adapters.out;

import com.prognum.common.environment.PoliticaSenhaIni;
import com.prognum.scci.acesso.domain.policy.PasswordPolicy;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Mapeamento das chaves de politica do launcherenv.ini -> PasswordPolicy (SccPoliticaSenhaResolver.montar). */
class SccPoliticaSenhaResolverTest {

    @Test
    void semChaves_permissiva_aceitaAteSenhaCurta() {
        PasswordPolicy p = SccPoliticaSenhaResolver.montar(new PoliticaSenhaIni(0, 0, 0, 0, 0, 0, 0));
        assertTrue(p.validar("a").ok(), "sem chaves -> aceita ate 1 caractere (fiel ao legado sem config)");
    }

    @Test
    void comMinimos_exigente_rejeitaFraca_aceitaForte() {
        // USERMINCARACPASS=8, CARMINALFAPASS=1, CARMINALFAMAISPASS=1, CARMINNUMPASS=1, CARMINESPPASS=1
        PasswordPolicy p = SccPoliticaSenhaResolver.montar(new PoliticaSenhaIni(8, 1, 1, 1, 1, 3, 3));
        assertFalse(p.validar("abc").ok(), "min 8 + composicao -> rejeita 'abc'");
        assertTrue(p.validar("Ab1@Cd2$").ok(), "senha forte (8, maiusc, digito, especial) passa");
    }
}
