package com.prognum.gateway.execucao.rest;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Deteccao de UTF-8 na resposta plaintext do /w (o caminho do React/loginintegracao). Programas de
 * integracao forcam UTF-8 (ex.: wintegracaoCDHU) -> nao pode re-encodar, senao dobra ("informaÃ§Ã£o").
 */
class DespachoControllerUtf8Test {

    @Test
    void detecta_utf8_valido_e_rejeita_iso() {
        assertThat(DespachoController.ehUtf8Valido("informação".getBytes(StandardCharsets.UTF_8))).isTrue();
        assertThat(DespachoController.ehUtf8Valido("informação".getBytes(StandardCharsets.ISO_8859_1))).isFalse();
        assertThat(DespachoController.ehUtf8Valido("Contrato nao encontrado".getBytes(StandardCharsets.UTF_8)))
                .isTrue();   // ASCII puro = valido (identico nos dois)
        assertThat(DespachoController.ehUtf8Valido(new byte[0])).isTrue();   // vazio = valido
    }

    /**
     * Round-trip da lógica do {@code resposta} plaintext: qualquer que seja o charset do programa, o React
     * (que decodifica UTF-8) tem que ver o texto CORRETO — sem mojibake.
     */
    @Test
    void roundtrip_preserva_acento_para_programa_utf8_e_iso() {
        // programa que FORCA UTF-8 (wintegracaoCDHU): antes dobrava; agora repassa -> correto
        assertThat(reactVe("informação".getBytes(StandardCharsets.UTF_8))).isEqualTo("informação");
        // programa ISO-8859-1 legado: converte ISO->UTF -> correto
        assertThat(reactVe("informação".getBytes(StandardCharsets.ISO_8859_1))).isEqualTo("informação");
        // ASCII: igual nos dois
        assertThat(reactVe("sem acento".getBytes(StandardCharsets.UTF_8))).isEqualTo("sem acento");
    }

    /** Reproduz o fluxo: SDK lê os bytes do Pascal como ISO-8859-1 -> resposta plaintext -> React decodifica UTF-8. */
    private static String reactVe(byte[] bytesDoPascal) {
        String corpo = new String(bytesDoPascal, StandardCharsets.ISO_8859_1);          // como o SDK lê
        byte[] bytes = corpo.getBytes(StandardCharsets.ISO_8859_1);                      // bytes originais
        byte[] saida = DespachoController.ehUtf8Valido(bytes) ? bytes : corpo.getBytes(StandardCharsets.UTF_8);
        return new String(saida, StandardCharsets.UTF_8);                                // como o React decodifica
    }
}
