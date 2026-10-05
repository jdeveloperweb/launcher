package com.prognum.scci;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/** Trava o extrator de versao do corpo do wverificascci (tolerante ao formato: JSON/XML/kv). */
class VersaoSistemaPascalTest {

    @Test
    void extrai_de_json_chave_capitalizada() {
        assertThat(VersaoSistemaPascal.extrairVersao("{\"success\":true,\"Versao\":\"984\"}")).isEqualTo("984");
    }

    @Test
    void extrai_de_json_chave_minuscula_pontuada() {
        assertThat(VersaoSistemaPascal.extrairVersao("{\"versao\":\"9.84\"}")).isEqualTo("9.84");
    }

    @Test
    void extrai_de_xml_pmemory() {
        assertThat(VersaoSistemaPascal.extrairVersao("<PMEMORY><Versao>984</Versao></PMEMORY>")).isEqualTo("984");
    }

    @Test
    void sem_versao_ou_erro_devolve_null() {
        // corpo de erro NAO deve casar (mensagem com "Versão" mas sem valor numerico apos :/=/>)
        assertThat(VersaoSistemaPascal.extrairVersao(
                "{\"success\":false,\"message\":\"Versão do Banco incompatível\"}")).isNull();
        assertThat(VersaoSistemaPascal.extrairVersao("{\"success\":false}")).isNull();
        assertThat(VersaoSistemaPascal.extrairVersao(null)).isNull();
    }
}
