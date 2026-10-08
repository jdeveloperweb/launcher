package com.prognum.gateway.compartilhado;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Charset da resposta plaintext (canais /w e /sccidoc). Programas de integração forçam UTF-8 (ex.:
 * wintegracaoCDHU) -> não pode re-encodar, senão dobra ("informaÃ§Ã£o").
 */
class RespostaCharsetTest {

    @Test
    void detecta_utf8_valido_e_rejeita_iso() {
        assertThat(RespostaCharset.ehUtf8Valido("informação".getBytes(StandardCharsets.UTF_8))).isTrue();
        assertThat(RespostaCharset.ehUtf8Valido("informação".getBytes(StandardCharsets.ISO_8859_1))).isFalse();
        assertThat(RespostaCharset.ehUtf8Valido("Contrato nao encontrado".getBytes(StandardCharsets.UTF_8)))
                .isTrue();   // ASCII puro = valido (identico nos dois)
        assertThat(RespostaCharset.ehUtf8Valido(new byte[0])).isTrue();   // vazio = valido
    }

    /**
     * Round-trip do {@code corpoPlaintext}: qualquer que seja o charset do programa, o front (que
     * decodifica UTF-8) tem que ver o texto CORRETO — sem mojibake.
     */
    @Test
    void roundtrip_preserva_acento_para_programa_utf8_e_iso() {
        assertThat(frontVe("informação".getBytes(StandardCharsets.UTF_8))).isEqualTo("informação"); // força UTF-8 -> repassa
        assertThat(frontVe("informação".getBytes(StandardCharsets.ISO_8859_1))).isEqualTo("informação"); // ISO -> converte
        assertThat(frontVe("sem acento".getBytes(StandardCharsets.UTF_8))).isEqualTo("sem acento");  // ASCII
    }

    /** SDK lê os bytes do Pascal como ISO-8859-1 -> corpoPlaintext -> front decodifica UTF-8. */
    private static String frontVe(byte[] bytesDoPascal) {
        String corpo = new String(bytesDoPascal, StandardCharsets.ISO_8859_1);
        return new String(RespostaCharset.corpoPlaintext(corpo), StandardCharsets.UTF_8);
    }
}
