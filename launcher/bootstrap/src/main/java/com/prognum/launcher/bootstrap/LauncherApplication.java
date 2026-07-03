package com.prognum.launcher.bootstrap;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Composition root do reator hexagonal (Ports and Adapters) do launcher SCCI em Java. Sobe na porta
 * 8083 (atras do Kong, que escuta a 8082 que o Apache proxya). Faz o component-scan de todos os
 * dominios (autenticacao, execucao, identidade, licencas, documentos, roteamento, compartilhado) e o
 * wiring dos casos de uso (POJOs puros) fica no {@link WiringConfig}.
 */
@SpringBootApplication(scanBasePackages = "com.prognum.launcher")
public class LauncherApplication {

    public static void main(String[] args) {
        SpringApplication.run(LauncherApplication.class, args);
    }
}
