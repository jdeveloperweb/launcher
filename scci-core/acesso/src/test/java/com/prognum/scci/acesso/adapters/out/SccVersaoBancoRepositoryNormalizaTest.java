package com.prognum.scci.acesso.adapters.out;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** Normalizacao de versao: alinha compacto x pontuado tirando so o ponto, PRESERVANDO a letra do patch. */
class SccVersaoBancoRepositoryNormalizaTest {

    @Test
    void alinha_compacto_e_pontuado_tirando_so_o_ponto() {
        // sistema compacto "984" x banco pontuado "9.84" -> iguais depois de alinhar
        assertThat(SccVersaoBancoRepository.normalizaVersao("9.84")).isEqualTo("984");
        assertThat(SccVersaoBancoRepository.normalizaVersao("984")).isEqualTo("984");
        assertThat(SccVersaoBancoRepository.normalizaVersao(" 9.85 ")).isEqualTo("985");
        assertThat(SccVersaoBancoRepository.normalizaVersao(null)).isEmpty();
    }

    @Test
    void a_letra_do_patch_conta() {
        // cenario CDHU: banco 9.83a, binario 9.83 -> NAO podem ser iguais (a letra conta)
        assertThat(SccVersaoBancoRepository.normalizaVersao("9.83a")).isEqualTo("983a");
        assertThat(SccVersaoBancoRepository.normalizaVersao("9.83a"))
                .isNotEqualTo(SccVersaoBancoRepository.normalizaVersao("9.83"));   // 983a != 983 -> bloqueia
        // mesmo patch dos dois lados (compacto x pontuado) -> igual -> passa
        assertThat(SccVersaoBancoRepository.normalizaVersao("9.83a"))
                .isEqualTo(SccVersaoBancoRepository.normalizaVersao("983a"));
    }
}
