package com.prognum.scci.acesso.dominio.policy;

import java.util.ArrayList;
import java.util.List;

/**
 * Politica de complexidade de senha (RN-010..012), portada do ValidaSenha do launcher legado.
 * Conjunto de caracteres especiais identico ao CARACESP do Pascal. Copia fiel do legado, mas
 * SEM Spring (dominio puro) — os parametros sao injetados via construtor pelo bootstrap.
 */
public class PasswordPolicy {

    private static final String ESPECIAIS = "#$%*@?!;{}|[]+-/\\><.()&:";

    private final int minCarac;
    private final boolean requerComposicao;
    private final int minLetras;
    private final int minMaiusc;
    private final int minDigitos;
    private final int minEspeciais;
    private final int maxRep;
    private final int maxSeq;

    public PasswordPolicy(int minCarac, boolean requerComposicao, int minLetras, int minMaiusc,
                          int minDigitos, int minEspeciais, int maxRep, int maxSeq) {
        this.minCarac = minCarac;
        this.requerComposicao = requerComposicao;
        this.minLetras = minLetras;
        this.minMaiusc = minMaiusc;
        this.minDigitos = minDigitos;
        this.minEspeciais = minEspeciais;
        this.maxRep = maxRep;
        this.maxSeq = maxSeq;
    }

    public Resultado validar(String senha) {
        if (senha == null) {
            senha = "";
        }
        List<String> faltas = new ArrayList<>();

        if (senha.length() < minCarac) {
            faltas.add("ter no minimo " + minCarac + " caracteres");
        }

        int nNum = 0, nAlfa = 0, nMaiusc = 0, nEsp = 0;
        for (int i = 0; i < senha.length(); i++) {
            char c = senha.charAt(i);
            if (Character.isDigit(c)) {
                nNum++;
            } else if (ESPECIAIS.indexOf(c) >= 0) {
                nEsp++;
            } else {
                nAlfa++;
                if (Character.isUpperCase(c)) {
                    nMaiusc++;
                }
            }
        }

        if (requerComposicao) {
            if (minLetras > 0 && nAlfa < minLetras) {
                faltas.add("ter no minimo " + minLetras + " letra(s)");
            }
            if (minMaiusc > 0 && nMaiusc < minMaiusc) {
                faltas.add("ter no minimo " + minMaiusc + " letra(s) maiuscula(s)");
            }
            if (minDigitos > 0 && nNum < minDigitos) {
                faltas.add("ter no minimo " + minDigitos + " digito(s)");
            }
            if (minEspeciais > 0 && nEsp < minEspeciais) {
                faltas.add("ter no minimo " + minEspeciais + " caractere(s) especial(is)");
            }
        }

        if (maxRep > 0 && maxRun(senha, false) >= maxRep) {
            faltas.add("nao repetir o mesmo caractere " + maxRep + " ou mais vezes seguidas");
        }
        if (maxSeq > 0 && maxRun(senha, true) >= maxSeq) {
            faltas.add("nao usar " + maxSeq + " ou mais caracteres em sequencia");
        }

        if (faltas.isEmpty()) {
            return new Resultado(true, "ok");
        }
        return new Resultado(false, "A senha deve: " + String.join("; ", faltas) + ".");
    }

    /** Maior corrida de caracteres iguais (sequencial=false) ou em sequencia (sequencial=true). */
    private int maxRun(String s, boolean sequencial) {
        if (s.isEmpty()) {
            return 0;
        }
        int max = 1, cur = 1;
        for (int i = 1; i < s.length(); i++) {
            boolean liga = sequencial
                    ? (s.charAt(i) == s.charAt(i - 1) + 1)
                    : (s.charAt(i) == s.charAt(i - 1));
            cur = liga ? cur + 1 : 1;
            if (cur > max) {
                max = cur;
            }
        }
        return max;
    }

    public record Resultado(boolean ok, String mensagem) {
    }
}
