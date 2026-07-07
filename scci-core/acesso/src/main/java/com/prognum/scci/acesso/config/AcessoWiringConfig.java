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
import com.prognum.scci.acesso.domain.policy.PasswordPolicy;
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
            ContadorTentativas tentativas,
            @Value("${scci.auth.login-err-delay-ms:1000}") long delayMs,
            @Value("${scci.auth.max-erros:5}") int maxErros) {
        return new LoginService(autenticadores, resolver, tentativas, delayMs, maxErros);
    }

    // ---- Política de senha (RN-010..012) ----
    @Bean
    PasswordPolicy passwordPolicy(
            @Value("${scci.auth.policy.min-caracteres:8}") int minCarac,
            @Value("${scci.auth.policy.requer-composicao:true}") boolean requerComposicao,
            @Value("${scci.auth.policy.min-letras:1}") int minLetras,
            @Value("${scci.auth.policy.min-maiusculas:1}") int minMaiusc,
            @Value("${scci.auth.policy.min-digitos:1}") int minDigitos,
            @Value("${scci.auth.policy.min-especiais:1}") int minEspeciais,
            @Value("${scci.auth.policy.max-repetidos:3}") int maxRep,
            @Value("${scci.auth.policy.max-sequenciais:3}") int maxSeq) {
        return new PasswordPolicy(minCarac, requerComposicao, minLetras, minMaiusc,
                minDigitos, minEspeciais, maxRep, maxSeq);
    }

    // ---- Troca / recuperação / valida ----
    @Bean
    TrocarSenhaUseCase trocarSenhaService(SenhaRepository repo, VerificadorSenha verificador, PasswordPolicy policy) {
        return new TrocarSenhaService(repo, verificador, policy);
    }

    // Doc Final de Requisitos (Troca/Recuperação de Senha): recuperação automática por e-mail
    // removida — fora do escopo inicial (sem bean de RecuperarSenhaUseCase).

    @Bean
    ValidarAcessoUseCase validacaoAcessoService(ValidacaoAcessoRepository repo) {
        return new ValidacaoAcessoService(repo);
    }
}
