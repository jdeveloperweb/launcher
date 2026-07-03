package com.prognum.launcher.identidade.model;

/**
 * Visao de dominio do AMBIENTE OPERACIONAL (o que isola um cliente/base). Resumo do mapeamento
 * [USERS] do launcherenv.ini: qual driver/base o ambiente usa (multi-banco). O detalhe de conexao
 * e colunas fica na infra (compartilhado/db.SccDbConfig); aqui e a visao do bounded context.
 */
public record AmbienteOperacional(String caminho, String driver, String host, String database) {
}
