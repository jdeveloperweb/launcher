package com.prognum.launcher.autenticacao.mapeado;

/**
 * Snapshot de um USUARIO já cadastrado no SCCI, do jeito que os logins payload-mapeado leem antes de
 * decidir provisionar. Campos podem vir nulos conforme o SELECT de cada cliente (nem todos leem
 * perfil/e-mail AD). {@code usuario} vem SEMPRE com a grafia real da base (login é case-insensitive).
 */
public record UsuarioScci(String usuario, Integer perfPrimario, String nomePerfil, String noAutenticacaoAd) {
}
