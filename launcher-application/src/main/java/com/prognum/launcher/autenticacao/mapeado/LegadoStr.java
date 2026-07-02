package com.prognum.launcher.autenticacao.mapeado;

/** Utilitários de string fiéis às funções Pascal usadas nos loginXXX (valint, rightStr, padding). */
final class LegadoStr {

    private LegadoStr() {
    }

    /** valint: inteiro do prefixo numérico da string; 0 se não começar com dígito (como o FPC). */
    static int valint(String s) {
        if (s == null) {
            return 0;
        }
        String t = s.trim();
        int i = 0;
        int sinal = 1;
        if (i < t.length() && (t.charAt(i) == '+' || t.charAt(i) == '-')) {
            if (t.charAt(i) == '-') {
                sinal = -1;
            }
            i++;
        }
        int ini = i;
        while (i < t.length() && Character.isDigit(t.charAt(i))) {
            i++;
        }
        if (i == ini) {
            return 0;
        }
        try {
            return sinal * Integer.parseInt(t.substring(ini, i));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** strtoint estrito: lança se não for inteiro válido (como o strtoint do Pascal). */
    static int strtoint(String s, String msgErro) {
        try {
            return Integer.parseInt(s == null ? "" : s.trim());
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(msgErro);
        }
    }

    /** rightStr(s,n): os últimos n caracteres (toda a string se n>len). */
    static String rightStr(String s, int n) {
        if (s == null) {
            return "";
        }
        return s.length() <= n ? s : s.substring(s.length() - n);
    }

    /** left-pad com '0' até len (StringOfChar('0',len-length)+s). */
    static String lpadZeros(String s, int len) {
        if (s == null) {
            s = "";
        }
        StringBuilder sb = new StringBuilder();
        for (int i = s.length(); i < len; i++) {
            sb.append('0');
        }
        return sb.append(s).toString();
    }
}
