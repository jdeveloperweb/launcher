package com.prognum.scci.acesso.config;

import java.security.SecureRandom;
import java.util.List;
import java.util.function.Supplier;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.prognum.scci.acesso.application.AutenticadorBanco;
import com.prognum.scci.acesso.application.LoginService;
import com.prognum.scci.acesso.application.TrocarSenhaService;
import com.prognum.scci.acesso.application.ValidacaoAcessoService;
import com.prognum.scci.acesso.application.mapeado.AutenticadorMapeado;
import com.prognum.scci.acesso.application.mapeado.ProvisaoAilos;
import com.prognum.scci.acesso.application.mapeado.ProvisaoBrb;
import com.prognum.scci.acesso.application.mapeado.ProvisaoC6;
import com.prognum.scci.acesso.application.mapeado.ProvisaoCashmeweb;
import com.prognum.scci.acesso.application.mapeado.ProvisaoDireto;
import com.prognum.scci.acesso.application.mapeado.ProvisaoItau;
import com.prognum.scci.acesso.application.mapeado.ProvisaoUnicred;
import com.prognum.scci.acesso.domain.port.out.PoliticaSenhaResolver;
import com.prognum.scci.acesso.domain.port.in.LoginUseCase;
import com.prognum.scci.acesso.domain.port.in.TrocarSenhaUseCase;
import com.prognum.scci.acesso.domain.port.in.ValidarAcessoUseCase;
import com.prognum.scci.acesso.domain.port.out.Autenticador;
import com.prognum.scci.acesso.domain.port.out.ContadorTentativas;
import com.prognum.scci.acesso.domain.port.out.CredenciaisRepository;
import com.prognum.scci.acesso.domain.port.out.MetodoLoginResolver;
import com.prognum.scci.acesso.domain.port.out.ProvisionamentoUsuario;
import com.prognum.scci.acesso.domain.port.out.SenhaRepository;
import com.prognum.scci.acesso.domain.port.out.ValidacaoAcessoRepository;
import com.prognum.scci.acesso.domain.port.out.VerificadorSenha;
import com.prognum.scci.acesso.domain.port.out.VerificadorVersaoBanco;
import com.prognum.scci.acesso.domain.port.out.RecuperacaoSenhaRepository;
import com.prognum.scci.acesso.domain.port.in.RecuperarSenhaUseCase;
import com.prognum.scci.acesso.application.RecuperarSenhaService;
import com.prognum.scci.notificacao.domain.port.Notificador;

/**
 * Fia os POJOs do contexto acesso (coordenador LoginService + Strategies BANCO/família B + senha/
 * recuperação/valida). Espelha a seção de auth do WiringConfig do launcher, com as chaves sob
 * {@code scci.auth.*}. Os adapters de saída (Scc..., Redis..., Verificador..., Metodo...) e o
 * {@code Notificador} (contexto notificacao) são {@code @Component}/bean e entram por injeção.
 */
@Configuration
public class AcessoWiringConfig {

    private static final SecureRandom RND = new SecureRandom();
    private static final char[] ALFABETO_TOKEN = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".toCharArray();

    /** Token de sessão (29 chars), mesmo formato do LoginService.novaSessionKey(). */
    private static String tokenSessao() {
        StringBuilder sb = new StringBuilder(29);
        for (int i = 0; i < 29; i++) {
            sb.append(ALFABETO_TOKEN[RND.nextInt(ALFABETO_TOKEN.length)]);
        }
        return sb.toString();
    }

    private static final Supplier<String> GERADOR_TOKEN = AcessoWiringConfig::tokenSessao;

    // ---- Strategy BANCO (loginbd, md5crypt) — o método padrão/fallback ----
    @Bean
    Autenticador autenticadorBanco(CredenciaisRepository repo, VerificadorSenha senhas,
            @Value("${scci.auth.dias-aviso-expiracao:5}") int diasAviso) {
        return new AutenticadorBanco(repo, senhas, diasAviso);
    }

    // ---- Strategies "payload-mapeado" (família B: IdP externo já autenticou, provisiona o USUARIO) ----
    // Um Autenticador por cliente; o LoginService os coleta na List<Autenticador> e o MetodoLoginResolver
    // escolhe por ambiente. Token de sessão = 29 chars (mesmo formato do coordenador).
    @Bean
    Autenticador autItau(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoItau(p), GERADOR_TOKEN);
    }

    @Bean
    Autenticador autC6(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoC6(p), GERADOR_TOKEN);
    }

    @Bean
    Autenticador autBrb(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoBrb(p), GERADOR_TOKEN);
    }

    @Bean
    Autenticador autCashmeweb(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoCashmeweb(p), GERADOR_TOKEN);
    }

    @Bean
    Autenticador autDireto(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoDireto(p), GERADOR_TOKEN);
    }

    @Bean
    Autenticador autUnicred(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoUnicred(p), GERADOR_TOKEN);
    }

    @Bean
    Autenticador autAilos(ProvisionamentoUsuario p) {
        return new AutenticadorMapeado(new ProvisaoAilos(p), GERADOR_TOKEN);
    }

    // ---- Coordenador do login ----
    // Doc Final de Requisitos (Autenticação): CAPTCHA fora do escopo inicial — sem parâmetro aqui.
    @Bean
    LoginUseCase loginService(List<Autenticador> autenticadores, MetodoLoginResolver resolver,
            ContadorTentativas tentativas, VerificadorVersaoBanco versaoBanco,
            @Value("${scci.auth.login-err-delay-ms:1000}") long delayMs,
            @Value("${scci.auth.max-erros:5}") int maxErros) {
        return new LoginService(autenticadores, resolver, tentativas, versaoBanco, delayMs, maxErros);
    }

    // ---- Politica de senha POR AMBIENTE (lida do launcherenv.ini; sem chaves = permissiva) ----
    // O SccPoliticaSenhaResolver e @Component (adapters.out) e entra por injecao no trocarSenhaService.
    // (parametrizacao por cliente, fiel ao loginbd: CARMIN*/USERMINCARACPASS/USERMAX*PASS).

    // ---- Troca / recuperação / valida ----
    @Bean
    TrocarSenhaUseCase trocarSenhaService(SenhaRepository repo, VerificadorSenha verificador,
            PoliticaSenhaResolver politicas) {
        return new TrocarSenhaService(repo, verificador, politicas);
    }

    // Recuperação de senha ("esqueci minha senha", ExecutaEmailPwd do loginbd): gera senha temporária,
    // grava forçando troca no próximo login e entrega por e-mail via o contexto notificacao.
    @Bean
    RecuperarSenhaUseCase recuperarSenhaService(RecuperacaoSenhaRepository repo, VerificadorSenha verificador,
            Notificador notificador) {
        return new RecuperarSenhaService(repo, verificador, notificador);
    }

    @Bean
    ValidarAcessoUseCase validacaoAcessoService(ValidacaoAcessoRepository repo) {
        return new ValidacaoAcessoService(repo);
    }
}
