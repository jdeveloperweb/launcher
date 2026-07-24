package com.prognum.gateway.licencas.model;

/**
 * SCAFFOLD do bounded context LICENCAS (novo). NAO HA regra de negocio mapeada hoje — modelo
 * placeholder para o contexto existir. Definir: o que e uma licenca no SCCI, ciclo de vida,
 * validade, vinculo com ambiente/usuario. Ver MAPA DE LACUNAS nas REGRAS.
 */
public record Licenca(String id, String descricao, String situacao) {
}
