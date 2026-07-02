package com.prognum.scci;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.scci.documentos.aplicacao.BaixarDocumentoEntidadeService;
import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService;
import com.prognum.scci.documentos.aplicacao.EnviarDocumentoService;
import com.prognum.scci.documentos.aplicacao.ExcluirDocumentoService;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumentoEntidade;
import com.prognum.scci.documentos.dominio.port.in.EnviarDocumento;
import com.prognum.scci.documentos.dominio.port.in.ExcluirDocumento;
import com.prognum.scci.documentos.dominio.port.out.AntiMalware;
import com.prognum.scci.documentos.dominio.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.dominio.port.out.ConversorImagemPdf;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;
import com.prognum.scci.documentos.dominio.port.out.ResolvedorDocumento;

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

    @Bean
    ExcluirDocumento excluirDocumento(RepositorioDocumento repo) {
        return new ExcluirDocumentoService(repo);
    }

    @Bean
    BaixarDocumentoEntidade baixarDocumentoEntidade(ResolvedorDocumento resolvedor, BaixarDocumento baixar) {
        return new BaixarDocumentoEntidadeService(resolvedor, baixar);
    }

    @Bean
    EnviarDocumento enviarDocumento(AntiMalware antiMalware, ConversorImagemPdf conversor,
                                    ArmazenadorDocumento armazenador) {
        return new EnviarDocumentoService(antiMalware, conversor, armazenador);
    }
}
