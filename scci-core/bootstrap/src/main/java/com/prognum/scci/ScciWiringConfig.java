package com.prognum.scci;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.scci.documentos.application.BaixarDocumentoEntidadeService;
import com.prognum.scci.documentos.application.BaixarDocumentoService;
import com.prognum.scci.documentos.application.EnviarDocumentoService;
import com.prognum.scci.documentos.application.ExcluirDocumentoService;
import com.prognum.scci.documentos.domain.port.in.BaixarDocumento;
import com.prognum.scci.documentos.domain.port.in.BaixarDocumentoEntidade;
import com.prognum.scci.documentos.application.GerarRelatorioService;
import com.prognum.scci.documentos.application.GerenciarEstruturaService;
import com.prognum.scci.documentos.domain.port.in.EnviarDocumento;
import com.prognum.scci.documentos.domain.port.in.GerenciarEstrutura;
import com.prognum.scci.documentos.domain.port.out.EstruturaDocumento;
import com.prognum.scci.documentos.domain.port.in.ExcluirDocumento;
import com.prognum.scci.documentos.domain.port.in.GerarRelatorioPdf;
import com.prognum.scci.documentos.domain.port.out.AntiMalware;
import com.prognum.scci.documentos.domain.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.domain.port.out.ConversorImagemPdf;
import com.prognum.scci.documentos.domain.port.out.GeradorRelatorio;
import com.prognum.scci.documentos.domain.port.out.RepositorioDocumento;
import com.prognum.scci.documentos.domain.port.out.ResolvedorDocumento;

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

    @Bean
    GerarRelatorioPdf gerarRelatorioPdf(GeradorRelatorio gerador) {
        return new GerarRelatorioService(gerador);
    }

    @Bean
    GerenciarEstrutura gerenciarEstrutura(EstruturaDocumento estrutura) {
        return new GerenciarEstruturaService(estrutura);
    }
}
