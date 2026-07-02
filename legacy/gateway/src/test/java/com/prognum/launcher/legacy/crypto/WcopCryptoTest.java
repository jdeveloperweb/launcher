package com.prognum.launcher.legacy.crypto;

import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Trava a cripto do W_COP contra um request REAL capturado do /aejs-l. */
class WcopCryptoTest {

    private final WcopCrypto crypto = new WcopCrypto();

    // Blob real de um POST /w/login (modo CRIPTOGRAFA).
    private static final String BLOB =
            "____130618705hwgrOc7L6ipwaTtNLfZq42BZ2kUn4mBk9vjkE8w0x3szAJt0hDrjhcmKxhFoDLDAbK2ASWoY/"
            + "FA6MaX4fZJCyqkwUZc0ITWONTmT9+LQKFre6FddrNp9qv1W6IoWAs4bSpvzg3RnkEvWoqQuUY/"
            + "picUxsVQihCVWxfvyRcVoeNq/EBX+C/ovv5JG2nYqUjS/";

    @Test
    void decifra_request_real() {
        String json = crypto.decifraRequest(BLOB);
        assertEquals(
                "{\"userName\":\"supervisor\",\"password\":\"112934\","
                + "\"ambienteOperacional\":\"/u10/c6bank/suporte/scat112934\","
                + "\"captcha\":\"\",\"requestMethod\":\"POST\"}",
                json);
    }

    @Test
    void resposta_round_trip_xor() {
        String original = "{\"success\":\"true\",\"sessionKey\":\"ABC123\",\"contexto\":\"CORP_WEB\"}";
        byte[] enc = crypto.cifraResposta(original);

        // Prefixo .*(@
        assertTrue(new String(enc, 0, 4, StandardCharsets.ISO_8859_1).equals(".*(@"));

        // Decodifica aplicando o MESMO XOR (e auto-inverso) nos bytes ASCII, apos o prefixo.
        byte[] body = new byte[enc.length - 4];
        System.arraycopy(enc, 4, body, 0, body.length);
        int j = 0;
        for (int i = 0; i < body.length; i++) {
            if ((body[i] & 0x80) == 0) {
                j = (j + 1) & 0xFF;
                body[i] = (byte) (body[i] ^ (0x70 + (j & 15)));
            }
        }
        assertEquals(original, new String(body, StandardCharsets.UTF_8));
    }
}
