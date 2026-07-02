package com.prognum.launcher.api.dto;

/**
 * Resposta padronizada (regras.md RF07): success/message/data/requestId.
 * 'rota' expoe qual caminho (A/B/C) atendeu — para observabilidade (RF09/RNF06).
 */
public record ExecuteResponse(
        boolean success,
        String message,
        Object data,
        String requestId,
        String rota
) {
}
