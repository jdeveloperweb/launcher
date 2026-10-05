package com.prognum.scci.acesso.adapters.out;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** Normalizacao de versao (so digitos): compara formatos diferentes do sistema x banco. */
class SccVersaoBancoRepositoryNormalizaTest {

    @Test
    void reduz_a_digitos_para_comparar_formatos() {
        // sistema compacto "984" x banco pontuado "9.84" -> iguais depois de normalizar
        assertThat(SccVersaoBancoRepository.soDigitos("9.84")).isEqualTo("984");
        assertThat(SccVersaoBancoRepository.soDigitos("984")).isEqualTo("984");
        assertThat(SccVersaoBancoRepository.soDigitos(" 9.85 ")).isEqualTo("985");
        assertThat(SccVersaoBancoRepository.soDigitos(null)).isEmpty();
    }
}
