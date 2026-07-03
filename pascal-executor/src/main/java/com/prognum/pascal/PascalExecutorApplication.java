package com.prognum.pascal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

import com.prognum.common.environment.LauncherEnvReader;

/**
 * Bootstrap do <b>pascal-executor</b> — a âncora legada da plataforma. Serviço interno (porta 8091)
 * que executa os programas Pascal (wmenu/wtela/wdoc/...) via ponte oserver/JNA. O launcher (edge) o
 * chama por REST quando a flag {@code executor.remoto} aponta REMOTO. CO-LOCALIZADO com os binários
 * Pascal, os {@code ambiente/} e o oserver — é o único módulo com JNA/nativo.
 */
@SpringBootApplication(scanBasePackages = "com.prognum.pascal")
public class PascalExecutorApplication {

    public static void main(String[] args) {
        SpringApplication.run(PascalExecutorApplication.class, args);
    }

    /** Leitor do launcherenv.ini (comum-environment) — POJO, exposto como bean. */
    @Bean
    LauncherEnvReader launcherEnvReader() {
        return new LauncherEnvReader();
    }
}
