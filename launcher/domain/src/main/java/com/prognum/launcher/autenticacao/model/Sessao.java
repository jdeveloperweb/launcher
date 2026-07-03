package com.prognum.launcher.autenticacao.model;

/** Sessao emitida no login (isolada): usuario + ambiente operacional. */
public record Sessao(String usuario, String ambienteOperacional) {
}
