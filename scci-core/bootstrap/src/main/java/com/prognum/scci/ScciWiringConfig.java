package com.prognum.scci;

import java.util.Arrays;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.beans.factory.annotation.Value;
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
    // Doc Final de Requisitos (Autenticacao/Sessao): cache de ambiente parametrizavel (TTL/on-off).
    @Bean
    LauncherEnvReader launcherEnvReader(
            @Value("${common.environment.cache-habilitado:true}") boolean cacheHabilitado,
            @Value("${common.environment.cache-ttl-segundos:300}") long cacheTtlSegundos) {
        return new LauncherEnvReader(cacheHabilitado, cacheTtlSegundos);
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

    // Doc Final de Requisitos (Upload/Download): lista paramétrica de extensões permitidas
    // (scci.documentos.extensoes-permitidas, vazia por padrão -> sem restrição adicional aqui; o
    // default REAL vem do application.yml, que já popula a lista recomendada).
    @Bean
    EnviarDocumento enviarDocumento(AntiMalware antiMalware, ConversorImagemPdf conversor,
                                    ArmazenadorDocumento armazenador,
                                    @Value("${scci.documentos.extensoes-permitidas:}") String[] extensoesPermitidas) {
        Set<String> extensoes = Arrays.stream(extensoesPermitidas)
                .map(e -> e.trim().toLowerCase(Locale.ROOT))
                .filter(e -> !e.isEmpty())
                .collect(Collectors.toSet());
        return new EnviarDocumentoService(antiMalware, conversor, armazenador, extensoes);
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
