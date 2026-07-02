package com.prognum.launcher.compartilhado.crypto;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * Cripto do W_COP, portado FIEL do SCCI (pcrypt.pas / wcorp.pas). Copia byte-a-byte do legado
 * congelado. Infra COMPARTILHADA (kernel tecnico): fica no dominio por ser Java PURO (sem Spring,
 * so JDK) e por precisar ser vista pelos DOIS adapters (in: controller cifra/decifra; out:
 * LauncherEnvReader trata DB_PASS). O bootstrap expoe como @Bean.
 *
 * REQUEST (front -> legado): AES-128-CBC. Formato: "____" + salt(9) + base64(cifra).
 *   chave = base64decode( mod1("iDajpt6RujmyZhxM7kbVVI==", salt) )   (DescriptografaAES)
 *   iv    = base64decode("8qzYJ7ULNNU6sle9nDAuQg==")  (fixo)
 *   o claro vem padded com #0 ate multiplo de 16 -> removemos o padding.
 *
 * RESPONSE (legado -> front): XOR posicional (funcao 'codifica' do wcorp.pas):
 *   nos bytes UTF-8 ASCII (bit 7 = 0): j++; byte := byte XOR (0x70 + (j and 15));
 *   bytes UTF-8 estendidos (bit 7 = 1) ficam intactos; prefixo ".*(@".
 */
public class WcopCrypto {

    private static final String MARCADOR = "____";
    private static final String CHAVE_BASE = "iDajpt6RujmyZhxM7kbVVI==";   // pcrypt.pas const _
    private static final String IV_BASE = "8qzYJ7ULNNU6sle9nDAuQg==";      // pcrypt.pas const __
    private static final String PREFIXO_RESP = ".*(@";                      // wcorp.pas codifica

    /** A requisicao veio cifrada (modo CRIPTOGRAFA)? */
    public boolean estaCifrado(String body) {
        return body != null && body.startsWith(MARCADOR);
    }

    /**
     * Decifra o corpo do request. Se nao estiver cifrado (dev), só normaliza \\uXXXX.
     * Retorna o claro (JSON), ja sem o padding #0.
     */
    public String decifraRequest(String body) {
        if (body == null) {
            return "";
        }
        if (!estaCifrado(body)) {
            return convBarraU(body);
        }
        String salt = body.substring(4, 13);                 // copy(st,5,9)
        byte[] ct = Base64.getDecoder().decode(body.substring(13));   // copy(st,14,maxint)
        byte[] key = Base64.getDecoder().decode(mod1(CHAVE_BASE, salt));
        byte[] iv = Base64.getDecoder().decode(IV_BASE);
        byte[] claro = aes(Cipher.DECRYPT_MODE, key, iv, ct);
        int fim = claro.length;
        while (fim > 0 && claro[fim - 1] == 0) {              // remove padding #0
            fim--;
        }
        return new String(claro, 0, fim, StandardCharsets.UTF_8);
    }

    /**
     * Cifra a resposta para o front (funcao 'codifica' do wcorp.pas). Retorna os bytes
     * a serem escritos no corpo HTTP (NAO e UTF-8 valido apos o XOR).
     */
    public byte[] cifraResposta(String texto) {
        // O front trata os bytes da resposta como Latin-1 (1 byte = 1 char), entao
        // os acentos vao como ISO-8859-1 (UTF-8 apareceria como "Ã§").
        byte[] dados = texto.getBytes(StandardCharsets.ISO_8859_1);
        int j = 0;
        for (int i = 0; i < dados.length; i++) {
            if ((dados[i] & 0x80) == 0) {                     // só os bytes ASCII
                j = (j + 1) & 0xFF;
                dados[i] = (byte) (dados[i] ^ (0x70 + (j & 15)));
            }
        }
        byte[] pref = PREFIXO_RESP.getBytes(StandardCharsets.ISO_8859_1);
        byte[] out = new byte[pref.length + dados.length];
        System.arraycopy(pref, 0, out, 0, pref.length);
        System.arraycopy(dados, 0, out, pref.length, dados.length);
        return out;
    }

    /**
     * TrataSenhaEncriptografada (crypt.pas): se a senha vier entre [..], o miolo e
     * WebDeCrypt; senao e texto puro. Usado no DB_PASS do launcherenv.ini.
     */
    public static String trataSenhaEncriptografada(String pass) {
        if (pass != null && pass.length() >= 2
                && pass.charAt(0) == '[' && pass.charAt(pass.length() - 1) == ']') {
            return webDeCrypt(pass.substring(1, pass.length() - 1));
        }
        return pass;
    }

    /** Inverso do WebCrypt (loginbd.pas/crypt.pas): pares de letras (base 'A'=65) -> char. */
    public static String webDeCrypt(String enc) {
        StringBuilder r = new StringBuilder();
        int p = 0;
        for (int k = 0; k + 1 < enc.length(); k += 2) {
            p++;
            int ch1 = enc.charAt(k) - 65;
            int ch2 = enc.charAt(k + 1) - 65;
            int ch = ((ch1 << 4) | (ch2 & 0x0F)) & 0xFF;
            int orig = ((ch ^ 0x96) - (p * 5)) & 0xFF;
            r.append((char) orig);
        }
        return r.toString();
    }

    /** mod1 (pcrypt.pas): intercala os 8 primeiros chars do salt na chave base64. */
    static String mod1(String st, String salt) {
        String modf = salt.substring(0, Math.min(8, salt.length()));
        return st.substring(0, 2) + modf.charAt(0)
                + st.charAt(3) + modf.charAt(1)
                + st.charAt(5) + modf.charAt(2)
                + st.charAt(7) + modf.charAt(3)
                + st.charAt(9) + modf.charAt(4)
                + st.charAt(11) + modf.charAt(5)
                + st.charAt(13) + modf.charAt(6)
                + st.charAt(15) + modf.charAt(7)
                + st.substring(17);
    }

    private static byte[] aes(int mode, byte[] key, byte[] iv, byte[] data) {
        try {
            Cipher c = Cipher.getInstance("AES/CBC/NoPadding");
            c.init(mode, new SecretKeySpec(key, "AES"), new IvParameterSpec(iv));
            return c.doFinal(data);
        } catch (Exception e) {
            throw new IllegalStateException("falha AES do W_COP", e);
        }
    }

    /** convBarraU (wcorp.pas): converte \\uXXXX para o caractere correspondente. */
    static String convBarraU(String s) {
        if (s == null || s.indexOf("\\u") < 0) {
            return s;
        }
        StringBuilder r = new StringBuilder(s.length());
        int i = 0;
        while (i < s.length()) {
            if (i + 5 < s.length() && s.charAt(i) == '\\' && s.charAt(i + 1) == 'u'
                    && isHex(s, i + 2, 4)) {
                r.append((char) Integer.parseInt(s.substring(i + 2, i + 6), 16));
                i += 6;
            } else {
                r.append(s.charAt(i));
                i++;
            }
        }
        return r.toString();
    }

    private static boolean isHex(String s, int from, int len) {
        for (int k = from; k < from + len; k++) {
            char c = s.charAt(k);
            boolean hex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
            if (!hex) {
                return false;
            }
        }
        return true;
    }
}
