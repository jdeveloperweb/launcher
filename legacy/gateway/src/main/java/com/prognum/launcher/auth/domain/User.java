package com.prognum.launcher.auth.domain;

import java.time.LocalDate;

/**
 * Usuario do dominio (modelo da nossa doc secao 23). Os campos espelham as colunas
 * configuraveis do launcher legado (validade, ultima troca, max dias, must change).
 */
public record User(
        String usuario,
        String ambiente,
        String senhaHash,      // bcrypt no fluxo Java nativo
        boolean ativo,
        LocalDate dtValidade,  // validade da conta/senha (RN-020)
        LocalDate ultimaTroca, // ultima troca de senha
        Integer maxDiasTroca,  // idade maxima da senha (RN-021)
        boolean mustChange     // trocar no proximo login (RN-023)
) {
}
