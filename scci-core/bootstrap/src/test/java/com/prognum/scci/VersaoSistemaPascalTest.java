package com.prognum.scci;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** Trava a leitura da versao do stdout do scciver (valida formato, preserva a letra do patch). */
class VersaoSistemaPascalTest {

    @Test
    void le_a_versao_do_stdout() {
        assertThat(VersaoSistemaPascal.primeiraVersao("984")).isEqualTo("984");
        assertThat(VersaoSistemaPascal.primeiraVersao("983a")).isEqualTo("983a");   // letra do patch preservada
        assertThat(VersaoSistemaPascal.primeiraVersao("  9.85  ")).isEqualTo("9.85");
    }

    @Test
    void linha_invalida_ou_vazia_devolve_null() {
        // warning de lib / linha inesperada no stdout NAO vira versao (senao bloquearia login a toa) -> fail-open
        assertThat(VersaoSistemaPascal.primeiraVersao("WARNING: libabc.so not found")).isNull();
        assertThat(VersaoSistemaPascal.primeiraVersao("")).isNull();
        assertThat(VersaoSistemaPascal.primeiraVersao(null)).isNull();
    }
}
