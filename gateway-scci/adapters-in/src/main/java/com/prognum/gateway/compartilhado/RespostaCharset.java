package com.prognum.gateway.compartilhado;

import java.nio.ByteBuffer;
import java.nio.charset.CharacterCodingException;
import java.nio.charset.CharsetDecoder;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

/**
 * Charset da resposta PLAINTEXT (não-cifrada) dos canais que repassam a saída do Pascal (/w, /sccidoc).
 *
 * <p>O SDK lê a resposta do Pascal como ISO-8859-1 (1 byte = 1 char), então {@code getBytes(ISO_8859_1)}
 * recupera os BYTES ORIGINAIS do programa. Programas de integração/React FORÇAM UTF-8 na saída (ex.:
 * {@code wintegracaoCDHU}: {@code JsonOut.encoding := 'UTF-8'}); re-encodar esses bytes
 * ({@code getBytes(UTF_8)}) DOBRA a codificação → acento quebrado ("informaÃ§Ã£o"). Então: se os bytes JÁ
 * são UTF-8 válido, repassa como vieram; só converte ISO-8859-1→UTF-8 quando NÃO é UTF-8 (programas
 * legados ISO-8859-1). O charset da resposta é sempre {@code UTF-8}.</p>
 */
public final class RespostaCharset {

    private RespostaCharset() {
    }

    /** Bytes do corpo plaintext (charset=UTF-8): repassa se já é UTF-8, senão converte ISO-8859-1→UTF-8. */
    public static byte[] corpoPlaintext(String json) {
        byte[] bytes = json.getBytes(StandardCharsets.ISO_8859_1);
        return ehUtf8Valido(bytes) ? bytes : json.getBytes(StandardCharsets.UTF_8);
    }

    /**
     * Prepara o {@code json} para o canal CIFRADO (W_COP/ExtJS — o {@code cifraResposta} encoda o texto em
     * ISO-8859-1). Se o programa forçou UTF-8 (o SDK leu como ISO-8859-1 → String "double": {@code Ã§}),
     * REINTERPRETA pro Unicode correto ({@code ç}), para que o {@code getBytes(ISO_8859_1)} do
     * {@code cifraResposta} produza o acento CERTO no ExtJS. Programa ISO-8859-1 legado → devolve inalterado.
     */
    public static String paraIso(String json) {
        byte[] bytes = json.getBytes(StandardCharsets.ISO_8859_1);
        return ehUtf8Valido(bytes) ? new String(bytes, StandardCharsets.UTF_8) : json;
    }

    /**
     * True se {@code bytes} já formam UTF-8 VÁLIDO — i.e., o programa Pascal forçou UTF-8 na saída. ASCII
     * puro conta como válido (idêntico nos dois charsets). Acento ISO-8859-1 (ex.: {@code ç}=0xE7) NÃO é
     * UTF-8 válido (byte-líder sem continuação) → false.
     */
    public static boolean ehUtf8Valido(byte[] bytes) {
        CharsetDecoder dec = StandardCharsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT);
        try {
            dec.decode(ByteBuffer.wrap(bytes));
            return true;
        } catch (CharacterCodingException e) {
            return false;
        }
    }
}
