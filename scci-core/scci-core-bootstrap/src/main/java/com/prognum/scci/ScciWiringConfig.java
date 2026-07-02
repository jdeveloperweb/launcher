package com.prognum.scci;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

/**
 * Composition root do scci-core: expõe como @Bean os POJOs de infra compartilhada (comum) e os casos de
 * uso (application) dos contextos. Os adapters (@Component/@RestController) são detectados pelo
 * component-scan de {@code com.prognum.scci}.
 */
@Configuration
public class ScciWiringConfig {

    // ---- infra tecnica compartilhada (comum, in-process) ----
    @Bean
    LauncherEnvReader launcherEnvReader() {
        return new LauncherEnvReader();
    }

    @Bean
    JdbcConnectionFactory jdbcConnectionFactory() {
        return new JdbcConnectionFactory();
    }

    // ---- casos de uso (contexto documentos) ----
    @Bean
    BaixarDocumento baixarDocumento(RepositorioDocumento repo) {
        return new BaixarDocumentoService(repo);
    }
}
