package com.prognum.scci.acesso.dominio.model;

/** Resultado da troca de senha (PASSWD do loginbd.pas). Copia do WcopPasswordService.Resultado. */
public record ResultadoTroca(boolean sucesso, String mensagem) {
}
