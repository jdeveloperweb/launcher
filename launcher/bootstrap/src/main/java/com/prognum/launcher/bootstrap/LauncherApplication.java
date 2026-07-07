package com.prognum.launcher.bootstrap;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Composition root do reator hexagonal (Ports and Adapters) do launcher SCCI em Java. Sobe na porta
 * 8083 (atras do Kong, que escuta a 8082 que o Apache proxya). Faz o component-scan de todos os
 * dominios (autenticacao, execucao, identidade, licencas, documentos, roteamento, compartilhado) e o
 * wiring dos casos de uso (POJOs puros) fica no {@link WiringConfig}.
 *
 * <p>{@code @EnableScheduling}: Doc Final de Requisitos (Upload/Download) — liga o job de limpeza de
 * staging de upload chunked ({@code LimpezaUploadStagingJob}, adapters-out).</p>
 *
 * <p><b>Doc Final de Requisitos (Arquitetura/Protocolo) — resumo consolidado no código-fonte:</b></p>
 * <ul>
 *   <li><b>Transporte:</b> o front fala HTTP(S)/W_COP com o Kong, que repassa HTTP/1.1 puro para
 *       este serviço na porta 8083 (sem TLS aqui — ver abaixo). Internamente, este serviço chama
 *       {@code scci-core} e {@code pascal-executor} também por HTTP/1.1 puro (REST interno).</li>
 *   <li><b>TLS:</b> este serviço NÃO termina TLS. TLS 1.2+ é terminado no <b>Kong</b> (borda,
 *       {@code deploy/kong/}), antes de chegar aqui. O tráfego deste serviço para
 *       {@code scci-core}/{@code pascal-executor} é texto puro, por decisão documentada (rede interna
 *       confiável, sem exposição direta à internet).</li>
 *   <li><b>Apache:</b> permanece na frente do Kong, INTOCADO — faz só o proxy do path
 *       {@code /aejs-l/rest} para o Kong; não termina TLS, não é substituído por este serviço. Este
 *       serviço não assume papel de webserver direto à internet (fica sempre atrás do Kong).</li>
 * </ul>
 * <p>Detalhes/diagramas: ver {@code README.md} na raiz do repositório.</p>
 */
@EnableScheduling
@SpringBootApplication(scanBasePackages = "com.prognum.launcher")
public class LauncherApplication {

    public static void main(String[] args) {
        SpringApplication.run(LauncherApplication.class, args);
    }
}
