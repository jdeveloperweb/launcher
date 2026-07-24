package com.prognum.gateway.identidade.model;

/**
 * Identidade do usuario no ambiente. Hoje o cadastro/perfil vive no banco do ambiente (SCCI);
 * este bounded context existe para, no futuro, portar cadastro/perfil/permissao sem misturar com
 * autenticacao. SCAFFOLD: modelo minimo (login + ambiente).
 */
public record Usuario(String login, String ambienteOperacional) {
}
