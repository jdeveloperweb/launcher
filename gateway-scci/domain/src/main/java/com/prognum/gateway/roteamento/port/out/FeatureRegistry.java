package com.prognum.gateway.roteamento.port.out;

import com.prognum.gateway.roteamento.model.FeatureFlag;

import java.util.Optional;

/**
 * NAO-PRODUTIVO (scaffold). Port de saida do registro de feature flags do roteador Strangler.
 * Mantido para quando o A/B/C for ligado de verdade.
 */
public interface FeatureRegistry {

    Optional<FeatureFlag> consultar(String nome);
}
