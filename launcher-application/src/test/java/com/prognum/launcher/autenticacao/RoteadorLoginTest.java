package com.prognum.launcher.autenticacao;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.port.in.LoginUseCase;
import com.prognum.launcher.autenticacao.port.out.AcessoJavaPort;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Trava o roteador do login (Strangler): flag OFF → local; ON → scci-core (Java); scci-core fora
 * (Optional vazio) → fallback local.
 */
class RoteadorLoginTest {

    private final LoginUseCase local = (u, s, a, ip) -> new ResultadoLogin(true, 'T', "LOCAL", "local", null);

    /** FeatureRegistry só com a flag informada. */
    private static FeatureRegistry flag(String nome, boolean on) {
        return chave -> chave.equals(nome) ? Optional.of(new FeatureFlag(nome, on, 0)) : Optional.empty();
    }

    /** AcessoJavaPort de teste: login devolve o resultado dado (ou vazio = scci-core fora). */
    private static AcessoJavaPort java(Optional<ResultadoLogin> login) {
        return new AcessoJavaPort() {
            public Optional<ResultadoLogin> login(String u, String s, String a, String ip) {
                return login;
            }
            public Optional<ResultadoTroca> trocarSenha(String u, String sa, String sn, String a) {
                return Optional.empty();
            }
            public Optional<ResultadoTroca> recuperar(String u, String c, String a) {
                return Optional.empty();
            }
            public Optional<Boolean> validarCpf(String v, String a) {
                return Optional.empty();
            }
            public Optional<Boolean> validarProtocolo(String v, String a) {
                return Optional.empty();
            }
        };
    }

    @Test
    void flag_off_usa_local() {
        var r = new RoteadorLogin(local, java(Optional.of(res("JAVA"))), flag("acesso.Login", false));
        assertThat(r.login("u", "s", "/a", "ip").sessionKey()).isEqualTo("LOCAL");
    }

    @Test
    void flag_on_usa_scci_core() {
        var r = new RoteadorLogin(local, java(Optional.of(res("JAVA"))), flag("acesso.Login", true));
        assertThat(r.login("u", "s", "/a", "ip").sessionKey()).isEqualTo("JAVA");
    }

    @Test
    void flag_on_mas_scci_fora_cai_no_local() {
        var r = new RoteadorLogin(local, java(Optional.empty()), flag("acesso.Login", true));
        assertThat(r.login("u", "s", "/a", "ip").sessionKey()).isEqualTo("LOCAL");
    }

    private static ResultadoLogin res(String token) {
        return new ResultadoLogin(true, 'T', token, "ok", null);
    }
}
