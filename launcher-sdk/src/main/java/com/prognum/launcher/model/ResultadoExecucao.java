package com.prognum.launcher.model;

/** Resultado da execucao de um programa "w": erro (bloco EXCEPT) + corpo (resposta crua). */
public record ResultadoExecucao(boolean erro, String corpo) {
}
