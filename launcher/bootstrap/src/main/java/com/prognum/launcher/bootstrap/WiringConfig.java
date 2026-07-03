package com.prognum.launcher.bootstrap;

import com.prognum.launcher.autenticacao.SessaoService;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.launcher.autenticacao.port.out.RepositorioSessao;
import com.prognum.launcher.autenticacao.port.out.SessaoPersistente;
import com.prognum.common.crypto.WcopCrypto;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.launcher.documentos.port.in.BaixarDocumentoUseCase;
import com.prognum.launcher.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.launcher.execucao.DespachoService;
import com.prognum.launcher.execucao.port.in.DespachoUseCase;
import com.prognum.launcher.execucao.port.out.ExecutorPrograma;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

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

    /** Leitor do launcherenv.ini (comum-ambiente): env do Pascal + config de banco. POJO -> @Bean. */
    @Bean
    LauncherEnvReader launcherEnvReader() {
        return new LauncherEnvReader();
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

    // ---- casos de uso (execucao) ----
    // A execucao de programas Pascal e SEMPRE via pascal-executor (ClientePascalExecutor, @Component):
    // o launcher e Java PURO, sem JNA/nativo. A ponte oserver vive so no pascal-executor.
    @Bean
    DespachoUseCase despachoService(ExecutorPrograma executor) {
        return new DespachoService(executor);
    }

    // ---- casos de uso (documentos) ----
    /**
     * Roteador do canal de documentos (Strangler): decide por feature-flag entre executar o wdoc Pascal
     * (DocumentoService) ou chamar o contexto documentos do scci-core (DocumentosJavaPort). Fallback ao
     * Pascal quando a flag é PASCAL ou o método não foi migrado.
     */
    @Bean
    BaixarDocumentoUseCase documentoService(ExecutorPrograma executor,
            com.prognum.launcher.documentos.port.out.DocumentosJavaPort documentosJava,
            com.prognum.launcher.roteamento.port.out.FeatureRegistry flags) {
        var pascal = new com.prognum.launcher.documentos.DocumentoService(executor);
        return new com.prognum.launcher.documentos.RoteadorBaixarDocumento(pascal, documentosJava, flags);
    }

    /** Roteador do UPLOAD (Strangler): flag decide entre wdoc Pascal e o scci-core (PostDocumento). */
    @Bean
    EnviarDocumentoUseCase envioDocumentoService(ExecutorPrograma executor,
            com.prognum.launcher.documentos.port.out.DocumentosJavaPort documentosJava,
            com.prognum.launcher.roteamento.port.out.FeatureRegistry flags) {
        var pascal = new com.prognum.launcher.documentos.EnvioDocumentoService(executor);
        return new com.prognum.launcher.documentos.RoteadorEnviarDocumento(pascal, documentosJava, flags);
    }
}
