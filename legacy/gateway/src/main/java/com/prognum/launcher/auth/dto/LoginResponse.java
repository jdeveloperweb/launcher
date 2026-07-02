package com.prognum.launcher.auth.dto;

/**
 * Resposta padronizada do login. 'outcome' e o estado do catalogo (LoginOutcome);
 * 'sessionToken' so vem no sucesso; 'diasRestantes' acompanha SENHA_VAI_EXPIRAR.
 */
public record LoginResponse(
        boolean success,
        String outcome,
        String message,
        String sessionToken,
        String requestId,
        Integer diasRestantes
) {
}
