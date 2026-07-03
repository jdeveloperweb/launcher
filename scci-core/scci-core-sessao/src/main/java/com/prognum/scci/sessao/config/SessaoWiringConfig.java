package com.prognum.scci.sessao.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.prognum.scci.sessao.aplicacao.SessaoService;
import com.prognum.scci.sessao.dominio.port.in.SessaoUseCase;
import com.prognum.scci.sessao.dominio.port.out.RepositorioSessao;
import com.prognum.scci.sessao.dominio.port.out.SessaoPersistente;

/**
 * Fia o POJO do contexto sessao ({@link SessaoService}, cache Redis + SCCI_SESSION). Os adapters de
 * saída (RedisRepositorioSessao, SccSessionRepository) são {@code @Component} e entram por injeção.
 */
@Configuration
public class SessaoWiringConfig {

    @Bean
    SessaoUseCase sessaoService(RepositorioSessao cache, SessaoPersistente persistente) {
        return new SessaoService(cache, persistente);
    }
}
