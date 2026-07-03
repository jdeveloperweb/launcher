package com.prognum.scci.acesso.dominio.model;

import java.time.LocalDate;

/**
 * Linha do usuario relevante para o login (igual ao TestaUsuario do loginbd.pas).
 * Copia fiel do SccUser do launcher SCCI (legado).
 */
public record CredenciaisUsuario(
        String senhaHash,
        LocalDate dtValidade,
        LocalDate ultimaTroca,
        Integer maxDias,
        Integer minDias,
        String mustChange) {
}
