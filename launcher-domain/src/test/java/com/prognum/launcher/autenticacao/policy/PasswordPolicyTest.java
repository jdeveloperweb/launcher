package com.prognum.launcher.autenticacao.policy;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Regras de complexidade de senha (RN-010..012). Porte do teste do legado. */
class PasswordPolicyTest {

    private final PasswordPolicy p = new PasswordPolicy(8, true, 1, 1, 1, 1, 3, 3);

    @Test
    void senhaForte_passa() {
        assertTrue(p.validar("Xy7#kqLm").ok());
    }

    @Test
    void curtaDemais_falha() {
        assertFalse(p.validar("Ab1#").ok());
    }

    @Test
    void semMaiuscula_falha() {
        assertFalse(p.validar("xy7#kqlm").ok());
    }

    @Test
    void semDigito_falha() {
        assertFalse(p.validar("Xy#kqLmn").ok());
    }

    @Test
    void semEspecial_falha() {
        assertFalse(p.validar("Xy7kqLmn").ok());
    }

    @Test
    void tresRepetidos_falha() {
        assertFalse(p.validar("Xaaa@1bc").ok());   // "aaa"
    }

    @Test
    void tresSequenciais_falha() {
        assertFalse(p.validar("Xabc@1de").ok());   // "abc"
    }
}
