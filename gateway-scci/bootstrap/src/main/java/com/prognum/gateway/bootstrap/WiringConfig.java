package com.prognum.gateway.bootstrap;

import com.prognum.gateway.autenticacao.SessaoService;
import com.prognum.gateway.autenticacao.port.in.SessaoUseCase;
import com.prognum.gateway.autenticacao.port.out.RepositorioSessao;
import com.prognum.gateway.autenticacao.port.out.SessaoPersistente;
import com.prognum.common.crypto.WcopCrypto;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.gateway.documentos.UploadChunkadoService;
import com.prognum.gateway.documentos.port.in.BaixarDocumentoUseCase;
import com.prognum.gateway.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.gateway.documentos.port.in.UploadChunkadoUseCase;
import com.prognum.gateway.documentos.port.out.RepositorioUploadChunked;
import com.prognum.gateway.execucao.RoteadorExecucao;
import com.prognum.gateway.execucao.pascal.ClientePascalExecutor;
import com.prognum.gateway.execucao.port.in.DespachoUseCase;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;
import com.prognum.gateway.execucao.port.out.RotaExecucaoRegistry;
import java.util.Arrays;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Primary;
import org.springframework.web.client.RestClient;

/**
 * Wiring (composition root) dos casos de uso, que sao POJOs puros (application/domain sem Spring).
 * Os adapters (@Component em adapters-in/out) sao detectados pelo component-scan; aqui so os POJOs
 * e as classes puras de dominio (WcopCrypto, PasswordPolicy) viram @Bean.
 */
@Configuration
public class WiringConfig {

    // ---- kernel tecnico / modulos compartilhados (comum/*) ----
    @Bean
    WcopCrypto wcopCrypto() {
        return new WcopCrypto();
    }

    /**
     * Leitor do launcherenv.ini (comum-ambiente): env do Pascal + config de banco. POJO -> @Bean.
     * Doc Final de Requisitos (Autenticacao/Sessao): cache de ambiente parametrizavel (TTL/on-off).
     */
    @Bean
    LauncherEnvReader launcherEnvReader(
            @Value("${common.environment.cache-habilitado:true}") boolean cacheHabilitado,
            @Value("${common.environment.cache-ttl-segundos:300}") long cacheTtlSegundos) {
        return new LauncherEnvReader(cacheHabilitado, cacheTtlSegundos);
    }

    /** Fabrica de conexao JDBC multi-banco (comum-ambiente). POJO -> @Bean. */
    @Bean
    JdbcConnectionFactory jdbcConnectionFactory() {
        return new JdbcConnectionFactory();
    }

    // ---- sessao (o EDGE mantem o gate: cache Redis + SCCI_SESSION). O restante do 'acesso'
    //      (login/senha/recuperacao/valida) foi movido para o scci-core; o launcher so o chama
    //      via ClienteScciCoreAcesso (AcessoJavaPort, @Component). ----
    @Bean
    SessaoUseCase sessaoService(RepositorioSessao cache, SessaoPersistente persistente) {
        return new SessaoService(cache, persistente);
    }

    // ---- EXECUCAO: 3 trilhos do Strangler (mesmo contrato /interno/executar, muda so a URL base) ----
    // pascal (default/legado) — executor-url: launcher :8091 OU scci-core hibrido raw :8090 (switch do Configurador).
    @Bean
    @Primary
    ExecutorPrograma executorPascal(RestClient.Builder b,
            @Value("${gateway.executor-url:${launcher.pascal-executor.url:http://localhost:8091}}") String url) {
        return new ClientePascalExecutor(b, url);
    }

    // hibrido — scci-core com SDK embutido (Java orquestra + Pascal in-process).
    @Bean
    ExecutorPrograma executorHibrido(RestClient.Builder b,
            @Value("${gateway.hibrido-url:http://localhost:8090}") String url) {
        return new ClientePascalExecutor(b, url);
    }

    // puro — scci-core PURO (Java, sem SDK/Pascal), deploy separado.
    @Bean
    ExecutorPrograma executorPuro(RestClient.Builder b,
            @Value("${gateway.puro-url:http://localhost:8092}") String url) {
        return new ClientePascalExecutor(b, url);
    }

    // Roteador /w: a feature-flag por operacao (RotaExecucaoRegistry) escolhe o trilho e delega ao executor certo.
    @Bean
    DespachoUseCase despachoService(
            @Qualifier("executorPascal") ExecutorPrograma pascal,
            @Qualifier("executorHibrido") ExecutorPrograma hibrido,
            @Qualifier("executorPuro") ExecutorPrograma puro,
            RotaExecucaoRegistry rotas) {
        return new RoteadorExecucao(pascal, hibrido, puro, rotas);
    }

    // ---- casos de uso (documentos) ----
    /**
     * Roteador do canal de documentos (Strangler): decide por feature-flag entre executar o wdoc Pascal
     * (DocumentoService) ou chamar o contexto documentos do scci-core (DocumentosJavaPort). Fallback ao
     * Pascal quando a flag é PASCAL ou o método não foi migrado.
     */
    @Bean
    BaixarDocumentoUseCase documentoService(ExecutorPrograma executor,
            com.prognum.gateway.documentos.port.out.DocumentosJavaPort documentosJava,
            com.prognum.gateway.roteamento.port.out.FeatureRegistry flags) {
        var pascal = new com.prognum.gateway.documentos.DocumentoService(executor);
        return new com.prognum.gateway.documentos.RoteadorBaixarDocumento(pascal, documentosJava, flags);
    }

    /** Roteador do UPLOAD (Strangler): flag decide entre wdoc Pascal e o scci-core (PostDocumento). */
    @Bean
    EnviarDocumentoUseCase envioDocumentoService(ExecutorPrograma executor,
            com.prognum.gateway.documentos.port.out.DocumentosJavaPort documentosJava,
            com.prognum.gateway.roteamento.port.out.FeatureRegistry flags) {
        var pascal = new com.prognum.gateway.documentos.EnvioDocumentoService(executor);
        return new com.prognum.gateway.documentos.RoteadorEnviarDocumento(pascal, documentosJava, flags);
    }

    /**
     * Doc Final de Requisitos (Upload/Download): upload em blocos (chunking) para arquivos grandes
     * (>10GB) — reaproveita o MESMO {@link EnviarDocumentoUseCase} (roteador Strangler) na conclusão,
     * então herda a allow-list de extensões e o roteamento Pascal/scci-core já existentes. Endpoint
     * PROPOSTO/aditivo (ver Javadoc do controller) — validar contrato com o front antes de produção.
     */
    @Bean
    UploadChunkadoUseCase uploadChunkadoService(RepositorioUploadChunked staging, EnviarDocumentoUseCase envio,
            @Value("${launcher.documentos.chunked.tamanho-maximo-bytes:16106127360}") long tamanhoMaximoBytes,
            @Value("${launcher.documentos.chunked.tamanho-bloco-maximo-bytes:10485760}") int tamanhoBlocoMaximoBytes,
            @Value("${launcher.documentos.extensoes-permitidas:}") String[] extensoesPermitidas) {
        Set<String> extensoes = Arrays.stream(extensoesPermitidas)
                .map(e -> e.trim().toLowerCase(Locale.ROOT))
                .filter(e -> !e.isEmpty())
                .collect(Collectors.toSet());
        return new UploadChunkadoService(staging, envio, tamanhoMaximoBytes, tamanhoBlocoMaximoBytes, extensoes);
    }
}
