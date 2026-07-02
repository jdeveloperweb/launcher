package com.prognum.launcher.autenticacao.mapeado;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Parser do payload dos logins payload-mapeado (XML e CommaText), fiel a TrataParamsEntrada/ParseSenha. */
class PayloadMapeadoTest {

    @Test
    void xml_le_perfil_ip_expiresIn_e_token() {
        String corpo = "PREFI<r><perfil>ADMINISTRADOR</perfil><ipAddr>10.0.0.9</ipAddr>"
                + "<expiresIn>3600</expiresIn><token>abc.def.ghi</token></r>";
        PayloadMapeado p = PayloadMapeado.deXml(corpo);
        assertThat(p.perfil()).isEqualTo("ADMINISTRADOR");
        assertThat(p.ipAddr()).isEqualTo("10.0.0.9");
        assertThat(p.expiresIn()).isEqualTo(3600);
        assertThat(p.token()).isEqualTo("abc.def.ghi");
    }

    @Test
    void xml_expiresIn_ausente_vira_zero() {
        PayloadMapeado p = PayloadMapeado.deXml("_____<r><perfil>X</perfil></r>");
        assertThat(p.expiresIn()).isZero();
        assertThat(p.token()).isEmpty();
    }

    @Test
    void ip_e_truncado_em_30() {
        String ip = "123.456.789.012.345.678.901.234.567";   // > 30
        PayloadMapeado p = PayloadMapeado.deXml("_____<r><ipAddr>" + ip + "</ipAddr></r>");
        assertThat(p.ipAddrTruncado()).hasSize(30).isEqualTo(ip.substring(0, 30));
    }

    @Test
    void commatext_le_chaves_e_valores_com_aspas() {
        PayloadMapeado p = PayloadMapeado.deCommaText(
                "!#___memberof=0012ABC045,Givename=Fulano,PhysicalDeliveryOfficeName=\"PA 00123\"");
        assertThat(p.valor("memberof")).isEqualTo("0012ABC045");
        assertThat(p.valor("Givename")).isEqualTo("Fulano");
        assertThat(p.valor("PhysicalDeliveryOfficeName")).isEqualTo("PA 00123");
        assertThat(p.valor("inexistente")).isEmpty();
    }

    @Test
    void commatext_jwt_id_identifier_e_token_tag() {
        PayloadMapeado p = PayloadMapeado.deCommaText(
                "!#___jwt_id_identifier=nome.sobrenome.0060,token_tag=xyz");
        assertThat(p.valor("jwt_id_identifier")).isEqualTo("nome.sobrenome.0060");
        assertThat(p.valor("token_tag")).isEqualTo("xyz");
    }

    @Test
    void semPrefixo_remove_5_chars() {
        assertThat(PayloadMapeado.semPrefixo("!#___resto")).isEqualTo("resto");
        assertThat(PayloadMapeado.semPrefixo("abc")).isEmpty();     // menor que o prefixo
    }
}
