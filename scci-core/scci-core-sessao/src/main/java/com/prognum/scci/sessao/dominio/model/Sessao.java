package com.prognum.scci.sessao.dominio.model;

/** Sessao emitida no login (isolada): usuario + ambiente operacional. */
public record Sessao(String usuario, String ambienteOperacional) {
}
