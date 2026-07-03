package com.prognum.scci.acesso.config;

import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.prognum.scci.acesso.aplicacao.AutenticadorBanco;
import com.prognum.scci.acesso.aplicacao.LoginService;
import com.prognum.scci.acesso.dominio.port.in.LoginUseCase;
import com.prognum.scci.acesso.dominio.port.out.Autenticador;
import com.prognum.scci.acesso.dominio.port.out.ContadorTentativas;
import com.prognum.scci.acesso.dominio.port.out.CredenciaisRepository;
import com.prognum.scci.acesso.dominio.port.out.MetodoLoginResolver;
import com.prognum.scci.acesso.dominio.port.out.VerificadorSenha;

/**
 * Fia os POJOs do contexto acesso (LoginService coordenador + Strategies). Espelha a seção de auth do
 * WiringConfig do launcher, com as chaves sob {@code scci.auth.*}. Os adapters de saída
 * (Scc..., Redis..., Verificador..., Metodo...) são {@code @Component} e entram por injeção.
 */
@Configuration
public class AcessoWiringConfig {

    /** Strategy BANCO (loginbd, md5crypt) — o método padrão/fallback. */
    @Bean
    Autenticador autenticadorBanco(CredenciaisRepository repo, VerificadorSenha senhas,
            @Value("${scci.auth.dias-aviso-expiracao:5}") int diasAviso) {
        return new AutenticadorBanco(repo, senhas, diasAviso);
    }

    /** Coordenador do login: recebe TODAS as Strategies (Autenticador) + o resolver de método por cliente. */
    @Bean
    LoginUseCase loginService(List<Autenticador> autenticadores, MetodoLoginResolver resolver,
            ContadorTentativas tentativas,
            @Value("${scci.auth.login-err-delay-ms:1000}") long delayMs,
            @Value("${scci.auth.max-erros:5}") int maxErros,
            @Value("${scci.auth.max-erros-captcha:3}") int maxErrosCaptcha,
            @Value("${scci.auth.captcha-habilitado:true}") boolean captchaHabilitado) {
        return new LoginService(autenticadores, resolver, tentativas, delayMs, maxErros,
                maxErrosCaptcha, captchaHabilitado);
    }
}
