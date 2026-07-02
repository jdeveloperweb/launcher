package com.prognum.scci;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Bootstrap do <b>scci-core</b> — o monólito modular (DDD) da plataforma SCCI. Sobe os contextos
 * delimitados (acesso, sessao, documentos, …) como UM deployable, escalável em N réplicas stateless.
 * O launcher (borda) chama este serviço via REST interno quando a feature-flag do módulo aponta JAVA.
 */
@SpringBootApplication(scanBasePackages = "com.prognum.scci")
public class ScciCoreApplication {

    public static void main(String[] args) {
        SpringApplication.run(ScciCoreApplication.class, args);
    }
}
