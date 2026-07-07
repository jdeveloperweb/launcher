package com.prognum.scci;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Bootstrap do <b>scci-core</b> — o monólito modular (DDD) da plataforma SCCI. Sobe os contextos
 * delimitados (acesso, sessao, documentos, …) como UM deployable, escalável em N réplicas stateless.
 * O launcher (borda) chama este serviço via REST interno quando a feature-flag do módulo aponta JAVA.
 *
 * <p><b>Doc Final de Requisitos (Arquitetura/Protocolo) — resumo consolidado no código-fonte:</b></p>
 * <ul>
 *   <li><b>Transporte:</b> HTTP/1.1 puro (REST interno via {@code RestClient}). Este serviço NÃO é
 *       exposto ao front/internet — só o {@code launcher} o chama, em rede interna confiável.</li>
 *   <li><b>TLS:</b> não há terminação TLS aqui nem no {@code launcher} — o TLS 1.2+ é terminado no
 *       <b>Kong</b> (borda), antes de chegar no {@code launcher}. O tráfego {@code launcher}↔
 *       {@code scci-core} é texto puro, por decisão documentada (rede confiável, sem exposição
 *       externa).</li>
 *   <li><b>Apache:</b> permanece na frente do Kong, INTOCADO (só faz proxy do path {@code /aejs-l} —
 *       não termina TLS, não é substituído). Nenhum dos deployables desta plataforma assume papel de
 *       webserver direto à internet.</li>
 * </ul>
 * <p>Detalhes/diagramas: ver {@code README.md} na raiz do repositório — este resumo evita divergência
 * entre a documentação e o código (a verdade arquitetural fica registrada nos dois lugares, com o
 * mesmo conteúdo).</p>
 */
@SpringBootApplication(scanBasePackages = "com.prognum.scci")
public class ScciCoreApplication {

    public static void main(String[] args) {
        SpringApplication.run(ScciCoreApplication.class, args);
    }
}
