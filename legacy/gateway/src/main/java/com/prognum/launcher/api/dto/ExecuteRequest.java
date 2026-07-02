package com.prognum.launcher.api.dto;

import java.util.Map;

/**
 * Requisicao unica do front-end (regras.md RF04): POST /v1/launcher/execute.
 * Os campos alimentam a decisao de rota (programa/metodo/wTela/ambiente/usuario).
 */
public record ExecuteRequest(
        String programa,   // ex.: wcorp, wtela, wscciweb...
        String metodo,     // ex.: Login, GetTela...
        String wTela,      // chave usada pelo Feature Registry para decidir a rota
        String ambiente,   // ambiente operacional (multi-tenant)
        String usuario,
        Map<String, Object> params
) {
}
