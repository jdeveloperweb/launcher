package com.prognum.scci.acesso.domain.mapeado;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

import javax.xml.parsers.DocumentBuilderFactory;

import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

/**
 * Payload dos logins "payload-mapeado" (família B: itau/c6/brb/cashmeweb/direto/unicred/ailos).
 * O front já autenticou o usuário num IdP externo (OpenID/JWT) e manda os atributos resultantes
 * cifrados no campo "senha". No legado cada loginXXX.pas faz {@code WebDecrypt(senha)} e então lê:
 *
 * <ul>
 *   <li><b>XML</b> (c6/brb/cashmeweb/direto — {@code TrataParamsEntrada}): 5 chars de prefixo +
 *       {@code <...><perfil/><ipAddr/><expiresIn/><token/></...>};</li>
 *   <li><b>CommaText</b> (unicred/ailos — {@code THashedStringlist.CommaText}): {@code !#___} +
 *       lista {@code chave=valor} separada por vírgula, valores podendo vir entre aspas;</li>
 *   <li><b>texto simples</b> (itau): {@code !#___} + o nome do perfil, sem chaves.</li>
 * </ul>
 *
 * Esta classe NÃO decifra (isso é {@code WcopCrypto.webDeCrypt}); recebe o texto JÁ decifrado e só
 * faz o parse fiel a cada formato. Objeto de valor imutável.
 */
public final class PayloadMapeado {

    /** Prefixo de 5 chars que precede o corpo (o {@code copy(st,6,...)}/{@code '!#___'} do legado). */
    public static final String PREFIXO = "!#___";

    private final Map<String, String> valores;

    private PayloadMapeado(Map<String, String> valores) {
        this.valores = valores;
    }

    /**
     * Formato XML dos clientes que usam {@code TrataParamsEntrada}. Espera o texto decifrado COM os
     * 5 chars de prefixo (removidos aqui, como o {@code copy(paramStr,6,...)} do .pas).
     */
    public static PayloadMapeado deXml(String decifrado) {
        String xml = semPrefixo(decifrado);
        Map<String, String> m = new LinkedHashMap<>();
        try {
            var dbf = DocumentBuilderFactory.newInstance();
            dbf.setNamespaceAware(false);
            dbf.setExpandEntityReferences(false);
            var doc = dbf.newDocumentBuilder()
                    .parse(new ByteArrayInputStream(xml.getBytes(StandardCharsets.ISO_8859_1)));
            NodeList filhos = doc.getDocumentElement().getChildNodes();
            for (int i = 0; i < filhos.getLength(); i++) {
                Node n = filhos.item(i);
                if (n instanceof Element el) {
                    m.putIfAbsent(el.getNodeName(), el.getTextContent() == null ? "" : el.getTextContent().trim());
                }
            }
        } catch (Exception e) {
            throw new IllegalArgumentException("payload XML de login invalido", e);
        }
        return new PayloadMapeado(m);
    }

    /**
     * Formato CommaText (THashedStringlist) dos clientes JWT/atributos. Espera o texto decifrado COM
     * o prefixo {@code !#___} (removido aqui, como o {@code copy(senha,6,...)} do .pas).
     */
    public static PayloadMapeado deCommaText(String decifrado) {
        return new PayloadMapeado(parseCommaText(semPrefixo(decifrado)));
    }

    /** Valor de uma chave (vazio se ausente). Espelha {@code THashedStringlist.values['chave']}. */
    public String valor(String chave) {
        return valores.getOrDefault(chave, "");
    }

    public String perfil() {
        return valor("perfil");
    }

    public String ipAddr() {
        return valor("ipAddr");
    }

    public String token() {
        return valor("token");
    }

    /** {@code expiresIn} como inteiro; 0 se ausente/ inválido (igual ao {@code asInteger} do pXml). */
    public int expiresIn() {
        try {
            String v = valor("expiresIn");
            return v.isBlank() ? 0 : Integer.parseInt(v.trim());
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    /** IP truncado em 30 (a coluna NU_IP_ACESSO é char(30)), fiel ao TrataParamsEntrada. */
    public String ipAddrTruncado() {
        String ip = ipAddr();
        return ip.length() > 30 ? ip.substring(0, 30) : ip;
    }

    Map<String, String> valores() {
        return valores;
    }

    // ---- helpers ----

    /** Remove os 5 chars de prefixo ({@code copy(x,6,len)}). Tolera string menor que o prefixo. */
    static String semPrefixo(String s) {
        if (s == null) {
            return "";
        }
        return s.length() <= 5 ? "" : s.substring(5);
    }

    /**
     * Parser do CommaText do Delphi/FPC: itens separados por vírgula (ou espaço), cada valor podendo
     * vir entre aspas duplas ("" = aspa literal). Cada item vira {@code chave=valor}. Fiel o
     * suficiente para os atributos que unicred/ailos leem (memberof, Givename, jwt_id_identifier…).
     */
    static Map<String, String> parseCommaText(String s) {
        Map<String, String> m = new LinkedHashMap<>();
        for (String item : dividirCommaText(s)) {
            int eq = item.indexOf('=');
            if (eq < 0) {
                if (!item.isBlank()) {
                    m.putIfAbsent(item, "");
                }
            } else {
                m.putIfAbsent(item.substring(0, eq), item.substring(eq + 1));
            }
        }
        return m;
    }

    private static java.util.List<String> dividirCommaText(String s) {
        java.util.List<String> itens = new java.util.ArrayList<>();
        StringBuilder atual = new StringBuilder();
        boolean emAspas = false;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '"') {
                if (emAspas && i + 1 < s.length() && s.charAt(i + 1) == '"') {   // "" -> aspa literal
                    atual.append('"');
                    i++;
                } else {
                    emAspas = !emAspas;
                }
            } else if ((c == ',' || c == ' ') && !emAspas) {
                if (atual.length() > 0) {
                    itens.add(atual.toString());
                    atual.setLength(0);
                }
            } else {
                atual.append(c);
            }
        }
        if (atual.length() > 0) {
            itens.add(atual.toString());
        }
        return itens;
    }
}
