package com.prognum.launcher;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Launcher Java Gateway — Fase 1 (MVP) conforme regras.md.
 * Fachada Strangler que roteia A (Java nativo) / B (ProcessBuilder) / C (proxy W_COP).
 */
@SpringBootApplication
public class LauncherGatewayApplication {

    public static void main(String[] args) {
        SpringApplication.run(LauncherGatewayApplication.class, args);
    }
}
