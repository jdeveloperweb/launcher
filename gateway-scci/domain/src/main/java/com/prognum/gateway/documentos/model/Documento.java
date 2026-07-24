package com.prognum.gateway.documentos.model;

/**
 * SCAFFOLD do bounded context DOCUMENTOS (novo). NAO HA regra de negocio mapeada hoje — modelo
 * placeholder. Definir: o que e um documento no SCCI, tipos, armazenamento, vinculo. Ver MAPA DE
 * LACUNAS nas REGRAS.
 */
public record Documento(String id, String tipo, String descricao) {
}
