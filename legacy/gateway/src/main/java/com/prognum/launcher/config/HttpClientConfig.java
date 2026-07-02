package com.prognum.launcher.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.client.RestClient;

/**
 * Cliente HTTP usado pela Rota C (proxy para o W_COP).
 * Hoje aponta para o simulador embutido; depois, para a URL real do W_COP (via config).
 */
@Configuration
public class HttpClientConfig {

    @Bean
    public RestClient restClient() {
        return RestClient.create();
    }
}
