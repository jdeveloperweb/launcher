package com.prognum.launcher.bootstrap;

import com.prognum.launcher.autenticacao.AutenticadorBanco;
import com.prognum.launcher.autenticacao.LoginService;
import com.prognum.launcher.autenticacao.mapeado.AutenticadorMapeado;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoAilos;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoBrb;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoC6;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoCashmeweb;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoDireto;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoItau;
import com.prognum.launcher.autenticacao.mapeado.ProvisaoUnicred;
import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;
import com.prognum.launcher.autenticacao.RecuperarSenhaService;
import com.prognum.launcher.autenticacao.SessaoService;
import com.prognum.launcher.autenticacao.TrocarSenhaService;
import com.prognum.launcher.autenticacao.ValidacaoAcessoService;
import com.prognum.launcher.autenticacao.policy.PasswordPolicy;
import com.prognum.launcher.autenticacao.port.in.LoginUseCase;
import com.prognum.launcher.autenticacao.port.in.RecuperarSenhaUseCase;
import com.prognum.launcher.autenticacao.port.in.SessaoUseCase;
import com.prognum.launcher.autenticacao.port.in.TrocarSenhaUseCase;
import com.prognum.launcher.autenticacao.port.in.ValidarAcessoUseCase;
import com.prognum.launcher.autenticacao.port.out.Autenticador;
import com.prognum.launcher.autenticacao.port.out.ContadorTentativas;
import com.prognum.launcher.autenticacao.port.out.CredenciaisRepository;
import com.prognum.launcher.autenticacao.port.out.MetodoLoginResolver;
import com.prognum.launcher.autenticacao.port.out.EnvioEmail;
import com.prognum.launcher.autenticacao.port.out.RecuperacaoSenhaRepository;
import com.prognum.launcher.autenticacao.port.out.RepositorioSessao;
import com.prognum.launcher.autenticacao.port.out.SessaoPersistente;
import com.prognum.launcher.autenticacao.port.out.SenhaRepository;
import com.prognum.launcher.autenticacao.port.out.ValidacaoAcessoRepository;
import com.prognum.launcher.autenticacao.port.out.VerificadorSenha;
import com.prognum.launcher.compartilhado.crypto.WcopCrypto;
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

    // ---- kernel tecnico / dominio puro ----
    @Bean
    WcopCrypto wcopCrypto() {
        return new WcopCrypto();
    }

    @Bean
    PasswordPolicy passwordPolicy(
            @Value("${launcher.auth.policy.min-caracteres:8}") int minCarac,
            @Value("${launcher.auth.policy.requer-composicao:true}") boolean requerComposicao,
            @Value("${launcher.auth.policy.min-letras:1}") int minLetras,
            @Value("${launcher.auth.policy.min-maiusculas:1}") int minMaiusc,
            @Value("${launcher.auth.policy.min-digitos:1}") int minDigitos,
            @Value("${launcher.auth.policy.min-especiais:1}") int minEspeciais,
            @Value("${launcher.auth.policy.max-repetidos:3}") int maxRep,
            @Value("${launcher.auth.policy.max-sequenciais:3}") int maxSeq) {
        return new PasswordPolicy(minCarac, requerComposicao, minLetras, minMaiusc,
                minDigitos, minEspeciais, maxRep, maxSeq);
    }

    // ---- casos de uso (autenticacao) ----
    /** Strategy BANCO (loginbd, md5crypt). Novos mecanismos (OAuth/API/LDAP) entram como outros beans Autenticador. */
    @Bean
    Autenticador autenticadorBanco(CredenciaisRepository repo, VerificadorSenha verificador,
            @Value("${launcher.auth.dias-aviso-expiracao:5}") int diasAviso) {
        return new AutenticadorBanco(repo, verificador, diasAviso);
    }

    // ---- Strategies "payload-mapeado" (família B: IdP externo já autenticou, provisiona o USUARIO) ----
    // Um Autenticador por cliente; o LoginService os coleta na List<Autenticador> e o MetodoLoginResolver
    // escolhe por ambiente. Token de sessão = 29 chars (mesmo formato do coordenador).
    @Bean
    Autenticador autItau(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoItau(p), WiringConfig::tokenSessao);
    }

    @Bean
    Autenticador autC6(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoC6(p), WiringConfig::tokenSessao);
    }

    @Bean
    Autenticador autBrb(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoBrb(p), WiringConfig::tokenSessao);
    }

    @Bean
    Autenticador autCashmeweb(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoCashmeweb(p), WiringConfig::tokenSessao);
    }

    @Bean
    Autenticador autDireto(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoDireto(p), WiringConfig::tokenSessao);
    }

    @Bean
    Autenticador autUnicred(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoUnicred(p), WiringConfig::tokenSessao);
    }

    @Bean
    Autenticador autAilos(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoAilos(p), WiringConfig::tokenSessao);
    }

    private static final java.security.SecureRandom RND = new java.security.SecureRandom();
    private static final char[] ALFABETO_TOKEN = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".toCharArray();

    /** Token de sessão (29 chars), mesmo formato do LoginService.novaSessionKey(). */
    private static String tokenSessao() {
        StringBuilder sb = new StringBuilder(29);
        for (int i = 0; i < 29; i++) {
            sb.append(ALFABETO_TOKEN[RND.nextInt(ALFABETO_TOKEN.length)]);
        }
        return sb.toString();
    }

    @Bean
    LoginUseCase loginService(
            java.util.List<Autenticador> autenticadores, MetodoLoginResolver resolver, ContadorTentativas attempts,
            @Value("${launcher.auth.login-err-delay-ms:1000}") long delayMs,
            @Value("${launcher.auth.max-erros:5}") int maxErros,
            @Value("${launcher.auth.max-erros-captcha:3}") int maxErrosCaptcha,
            @Value("${launcher.auth.captcha-habilitado:true}") boolean captchaHabilitado) {
        return new LoginService(autenticadores, resolver, attempts, delayMs, maxErros,
                maxErrosCaptcha, captchaHabilitado);
    }

    @Bean
    TrocarSenhaUseCase trocarSenhaService(SenhaRepository repo, VerificadorSenha verificador, PasswordPolicy policy) {
        return new TrocarSenhaService(repo, verificador, policy);
    }

    @Bean
    RecuperarSenhaUseCase recuperarSenhaService(RecuperacaoSenhaRepository repo, VerificadorSenha verificador,
                                                EnvioEmail email) {
        return new RecuperarSenhaService(repo, verificador, email);
    }

    @Bean
    SessaoUseCase sessaoService(RepositorioSessao cache, SessaoPersistente persistente) {
        return new SessaoService(cache, persistente);
    }

    @Bean
    ValidarAcessoUseCase validacaoAcessoService(ValidacaoAcessoRepository repo) {
        return new ValidacaoAcessoService(repo);
    }

    // ---- casos de uso (execucao) ----
    @Bean
    DespachoUseCase despachoService(ExecutorPrograma executor) {
        return new DespachoService(executor);
    }

    // ---- casos de uso (documentos) ----
    @Bean
    BaixarDocumentoUseCase documentoService(ExecutorPrograma executor) {
        return new com.prognum.launcher.documentos.DocumentoService(executor);
    }

    @Bean
    EnviarDocumentoUseCase envioDocumentoService(ExecutorPrograma executor) {
        return new com.prognum.launcher.documentos.EnvioDocumentoService(executor);
    }
}
