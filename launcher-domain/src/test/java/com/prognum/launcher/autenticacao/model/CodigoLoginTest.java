package com.prognum.launcher.autenticacao.model;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Trava o catálogo formal de estados de login (contrato = caractere). */
class CodigoLoginTest {

    @Test
    void mapeia_o_caractere_do_contrato() {
        assertThat(CodigoLogin.de('T')).isEqualTo(CodigoLogin.OK);
        assertThat(CodigoLogin.de('M')).isEqualTo(CodigoLogin.TROCA_OBRIGATORIA);
        assertThat(CodigoLogin.de('X')).isEqualTo(CodigoLogin.BLOQUEADO);
    }

    @Test
    void so_T_e_C_sao_sucesso() {
        for (CodigoLogin c : CodigoLogin.values()) {
            boolean esperadoSucesso = c == CodigoLogin.OK || c == CodigoLogin.AVISO_EXPIRACAO;
            assertThat(c.sucesso()).as(c.name()).isEqualTo(esperadoSucesso);
        }
    }

    @Test
    void round_trip_codigo() {
        for (CodigoLogin c : CodigoLogin.values()) {
            assertThat(CodigoLogin.de(c.codigo())).isEqualTo(c);
            assertThat(c.descricao()).isNotBlank();
        }
    }

    @Test
    void codigo_desconhecido_estoura() {
        assertThatThrownBy(() -> CodigoLogin.de('Z')).isInstanceOf(IllegalArgumentException.class);
    }
}
