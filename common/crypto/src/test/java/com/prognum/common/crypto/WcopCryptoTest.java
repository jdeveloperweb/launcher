package com.prognum.common.crypto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Evidência da cripto W_COP (AES no request, XOR na resposta, WebDeCrypt do DB_PASS).
 * Trava contra um request REAL capturado do /aejs-l e faz round-trips.
 */
class WcopCryptoTest {

    private final WcopCrypto crypto = new WcopCrypto();

    // Blob REAL de um POST /w/login (modo CRIPTOGRAFA) capturado do /aejs-l.
    private static final String BLOB_LOGIN_REAL =
            "____130618705hwgrOc7L6ipwaTtNLfZq42BZ2kUn4mBk9vjkE8w0x3szAJt0hDrjhcmKxhFoDLDAbK2ASWoY/"
            + "FA6MaX4fZJCyqkwUZc0ITWONTmT9+LQKFre6FddrNp9qv1W6IoWAs4bSpvzg3RnkEvWoqQuUY/"
            + "picUxsVQihCVWxfvyRcVoeNq/EBX+C/ovv5JG2nYqUjS/";

    @Test
    @DisplayName("decifra AES de um request REAL do login (evidência ponta a ponta)")
    void decifra_request_real() {
        String json = crypto.decifraRequest(BLOB_LOGIN_REAL);
        assertThat(json).isEqualTo(
                "{\"userName\":\"supervisor\",\"password\":\"112934\","
                + "\"ambienteOperacional\":\"/u10/c6bank/suporte/scat112934\","
                + "\"captcha\":\"\",\"requestMethod\":\"POST\"}");
    }

    @Test
    @DisplayName("estaCifrado: só quando começa com ____")
    void esta_cifrado() {
        assertThat(crypto.estaCifrado("____abc")).isTrue();
        assertThat(crypto.estaCifrado("{\"a\":1}")).isFalse();
        assertThat(crypto.estaCifrado("")).isFalse();
        assertThat(crypto.estaCifrado(null)).isFalse();
    }

    @Test
    @DisplayName("resposta XOR: prefixo .*(@ e round-trip (auto-inverso) nos bytes ASCII")
    void resposta_xor_round_trip() {
        String original = "{\"success\":\"true\",\"sessionKey\":\"ABC123\",\"contexto\":\"CORP_WEB\"}";
        byte[] enc = crypto.cifraResposta(original);

        assertThat(new String(enc, 0, 4, StandardCharsets.ISO_8859_1)).isEqualTo(".*(@");

        // Reaplica o MESMO XOR (auto-inverso) após o prefixo -> volta ao original.
        byte[] body = new byte[enc.length - 4];
        System.arraycopy(enc, 4, body, 0, body.length);
        int j = 0;
        for (int i = 0; i < body.length; i++) {
            if ((body[i] & 0x80) == 0) {
                j = (j + 1) & 0xFF;
                body[i] = (byte) (body[i] ^ (0x70 + (j & 15)));
            }
        }
        assertThat(new String(body, StandardCharsets.UTF_8)).isEqualTo(original);
    }

    @Test
    @DisplayName("resposta XOR: bytes estendidos (ISO-8859-1, acento) passam intactos")
    void resposta_xor_preserva_acentos() {
        byte[] enc = crypto.cifraResposta("ção");     // 'ç','ã','o'
        // após o prefixo (4 bytes), os bytes >= 0x80 não são alterados pelo XOR.
        byte[] orig = "ção".getBytes(StandardCharsets.ISO_8859_1);
        // 'ç'=0xE7, 'ã'=0xE3 são >=0x80 -> devem aparecer intactos em algum lugar do corpo cifrado.
        assertThat(enc).contains(orig[0]).contains(orig[1]);
    }

    @Test
    @DisplayName("modo dev (sem ____): passthrough + converte \\uXXXX")
    void dev_sem_cripto() {
        assertThat(crypto.decifraRequest("{\"a\":1}")).isEqualTo("{\"a\":1}");
        assertThat(crypto.decifraRequest("caf\\u00e9")).isEqualTo("café");
        assertThat(crypto.decifraRequest(null)).isEmpty();
    }

    @Test
    @DisplayName("DB_PASS: texto puro passa; [..] é WebDeCrypt (round-trip com WebCrypt)")
    void trata_senha_encriptografada() {
        // texto puro (dev) -> passthrough
        assertThat(WcopCrypto.trataSenhaEncriptografada("wpostgres")).isEqualTo("wpostgres");

        // round-trip: cifra com o inverso do WebDeCrypt, embrulha em [..], e decifra de volta.
        String claro = "S3nh@Banco";
        String cifrada = "[" + webCrypt(claro) + "]";
        assertThat(WcopCrypto.trataSenhaEncriptografada(cifrada)).isEqualTo(claro);
    }

    /** Inverso do WcopCrypto.webDeCrypt — só para o teste gerar um vetor cifrado. */
    private static String webCrypt(String claro) {
        StringBuilder sb = new StringBuilder();
        for (int p = 1; p <= claro.length(); p++) {
            int orig = claro.charAt(p - 1) & 0xFF;
            int x = (orig + p * 5) & 0xFF;
            int ch = x ^ 0x96;
            sb.append((char) (((ch >> 4) & 0x0F) + 65));
            sb.append((char) ((ch & 0x0F) + 65));
        }
        return sb.toString();
    }
}
