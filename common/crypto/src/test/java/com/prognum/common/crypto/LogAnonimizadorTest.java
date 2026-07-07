package com.prognum.common.crypto;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class LogAnonimizadorTest {

    @Test
    void mesmo_usuario_gera_sempre_o_mesmo_pseudonimo() {
        String a = LogAnonimizador.pseudonimizarUsuario("joao.silva");
        String b = LogAnonimizador.pseudonimizarUsuario("JOAO.SILVA");   // case-insensitive
        assertThat(a).isEqualTo(b).startsWith("u_").hasSize(14);
    }

    @Test
    void usuarios_diferentes_geram_pseudonimos_diferentes() {
        assertThat(LogAnonimizador.pseudonimizarUsuario("joao"))
                .isNotEqualTo(LogAnonimizador.pseudonimizarUsuario("maria"));
    }

    @Test
    void pseudonimo_nao_expoe_o_usuario_em_texto_puro() {
        assertThat(LogAnonimizador.pseudonimizarUsuario("supervisor")).doesNotContain("supervisor");
    }

    @Test
    void mascara_ipv4_zera_o_ultimo_octeto() {
        assertThat(LogAnonimizador.mascararIp("10.20.30.99")).isEqualTo("10.20.30.0");
    }

    @Test
    void mascara_ipv6_mantem_so_os_3_primeiros_grupos() {
        assertThat(LogAnonimizador.mascararIp("2001:db8:85a3:0:0:8a2e:370:7334")).isEqualTo("2001:db8:85a3::0");
    }

    @Test
    void entradas_vazias_ou_invalidas_nao_quebram() {
        assertThat(LogAnonimizador.pseudonimizarUsuario(null)).isEmpty();
        assertThat(LogAnonimizador.pseudonimizarUsuario("")).isEmpty();
        assertThat(LogAnonimizador.mascararIp(null)).isEmpty();
        assertThat(LogAnonimizador.mascararIp("nao-e-um-ip")).isEmpty();
        assertThat(LogAnonimizador.pseudonimizarSessao(null)).isEmpty();
        assertThat(LogAnonimizador.pseudonimizarSessao("")).isEmpty();
    }

    @Test
    void mesma_sessao_gera_sempre_o_mesmo_pseudonimo_e_e_case_sensivel() {
        String a = LogAnonimizador.pseudonimizarSessao("ABC123xyz");
        String b = LogAnonimizador.pseudonimizarSessao("ABC123xyz");
        assertThat(a).isEqualTo(b).startsWith("s_").hasSize(14);
        assertThat(LogAnonimizador.pseudonimizarSessao("abc123xyz")).isNotEqualTo(a);
    }

    @Test
    void pseudonimo_de_sessao_nunca_expoe_o_token_bruto() {
        String token = "SESSIONKEYSECRETA123456789AB";
        assertThat(LogAnonimizador.pseudonimizarSessao(token)).doesNotContain(token);
    }
}
