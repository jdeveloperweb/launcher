package com.prognum.launcher;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

import com.prognum.common.environment.LauncherEnvReader;

/**
 * Bootstrap do <b>pascal-executor</b> — a âncora legada da plataforma. Serviço interno (porta 8091)
 * que executa os programas Pascal (wmenu/wtela/wdoc/...) via ponte oserver/JNA. O launcher (edge) o
 * chama por REST quando a flag {@code executor.remoto} aponta REMOTO. CO-LOCALIZADO com os binários
 * Pascal, os {@code ambiente/} e o oserver — é o único módulo com JNA/nativo.
 *
 * <p><b>Doc Final de Requisitos (Arquitetura/Protocolo) — resumo consolidado no código-fonte:</b></p>
 * <ul>
 *   <li><b>Transporte:</b> HTTP/1.1 puro (REST interno). Este serviço NÃO é exposto ao front/internet
 *       — só o {@code launcher} o chama, em rede interna confiável.</li>
 *   <li><b>TLS:</b> não há terminação TLS aqui — TLS 1.2+ é terminado no <b>Kong</b> (borda), antes
 *       de chegar no {@code launcher}. O tráfego {@code launcher}↔{@code pascal-executor} é texto
 *       puro, por decisão documentada (rede confiável, sem exposição externa).</li>
 *   <li><b>Apache:</b> permanece na frente do Kong, INTOCADO — este serviço não assume papel de
 *       webserver direto à internet.</li>
 * </ul>
 * <p>Detalhes/diagramas: ver {@code README.md} na raiz do repositório.</p>
 */
@SpringBootApplication(scanBasePackages = "com.prognum.launcher")
public class PascalExecutorApplication {

    public static void main(String[] args) {
        SpringApplication.run(PascalExecutorApplication.class, args);
    }

    /**
     * Leitor do launcherenv.ini (comum-environment) — POJO, exposto como bean.
     * Doc Final de Requisitos (Autenticacao/Sessao): cache de ambiente parametrizavel (TTL/on-off).
     */
    @Bean
    LauncherEnvReader launcherEnvReader(
            @Value("${common.environment.cache-habilitado:true}") boolean cacheHabilitado,
            @Value("${common.environment.cache-ttl-segundos:300}") long cacheTtlSegundos) {
        return new LauncherEnvReader(cacheHabilitado, cacheTtlSegundos);
    }
}
