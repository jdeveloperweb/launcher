package com.prognum.launcher.auth.dto;

/** Resposta da troca de senha. 'outcome' = estado do catalogo (LoginOutcome). */
public record ChangePasswordResponse(
        boolean success,
        String outcome,
        String message,
        String requestId
) {
}
