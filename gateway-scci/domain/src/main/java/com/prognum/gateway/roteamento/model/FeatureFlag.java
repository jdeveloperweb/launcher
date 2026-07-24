package com.prognum.gateway.roteamento.model;

/**
 * NAO-PRODUTIVO (scaffold). Feature flag do roteador A/B/C (Strangler): decidir por rota qual
 * caminho atende cada chamada durante a migracao. Hoje o reator atende so o fluxo nativo (Rota A/B
 * = login/senha em Java + execucao dos "w"); o roteamento so sera LIGADO quando houver rota
 * alternativa (ex.: proxy para o launcher legado). Ver MAPA DE LACUNAS.
 */
public record FeatureFlag(String nome, boolean habilitado, int percentual) {
}
