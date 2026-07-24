package com.prognum.gateway.autenticacao.port.out;

/**
 * Uma sessao ativa na SCCI_SESSION de um ambiente (para o painel de "usuarios conectados por
 * ambiente"). {@code desde} e o ISO-8601 do DT_HORA_SOLICITACAO (quando logou) — o front calcula
 * "ha quanto tempo". SOMENTE LEITURA/observabilidade.
 */
public record SessaoAtiva(String chave, String usuario, String ip, String desde) {
}
