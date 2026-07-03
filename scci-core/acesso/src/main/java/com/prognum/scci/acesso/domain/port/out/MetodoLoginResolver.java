package com.prognum.scci.acesso.domain.port.out;

/**
 * Resolve QUAL método de login um ambiente/cliente usa — o que no legado era decidido por qual
 * binário loginXXX o cliente estava configurado. Aqui vira CONFIGURAÇÃO por cliente (ex.: chave no
 * launcherenv.ini ou mapa no application.yml), garantindo que cada cliente funcione como hoje.
 *
 * Retorna o id do método (ex.: "BANCO", "OAUTH", "API_SICREDI", "LDAP"). Default: "BANCO" (loginbd).
 */
public interface MetodoLoginResolver {

    String metodoDe(String ambiente);
}
