package com.prognum.launcher.autenticacao;

import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.port.out.Autenticador;
import com.prognum.launcher.autenticacao.port.out.ContadorTentativas;
import com.prognum.launcher.autenticacao.port.out.MetodoLoginResolver;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * COORDENADOR do login: bloqueio/captcha/sessão comuns + escolha da Strategy pela config do cliente.
 * (Os estados de banco T/F/E/M são do AutenticadorBanco — ver AutenticadorBancoTest.)
 */
class LoginServiceTest {

    private final Autenticador banco = mock(Autenticador.class);
    private final Autenticador oauth = mock(Autenticador.class);
    private final MetodoLoginResolver resolver = mock(MetodoLoginResolver.class);
    private final ContadorTentativas attempts = mock(ContadorTentativas.class);
    private LoginService svc;

    @BeforeEach
    void setup() {
        when(banco.metodo()).thenReturn("BANCO");
        when(oauth.metodo()).thenReturn("OAUTH");
        when(resolver.metodoDe(any())).thenReturn("BANCO");   // default
        when(attempts.get(any())).thenReturn(0);
        when(attempts.registerFailure(any())).thenReturn(1);
        svc = new LoginService(List.of(banco, oauth), resolver, attempts, 0, 5, 3, true);
    }

    @Test
    void sucesso_emite_sessionKey_e_zera_tentativas() {
        when(banco.autenticar(any(), any(), any(), any()))
                .thenReturn(new ResultadoLogin(true, 'T', null, "OK", null));
        ResultadoLogin r = svc.login("joao", "s", "/amb", "ip");
        assertThat(r.sucesso()).isTrue();
        assertThat(r.sessionKey()).isNotBlank();   // o coordenador emitiu o token
        verify(attempts).reset("joao");
    }

    @Test
    void credencial_invalida_F_conta_tentativa() {
        when(banco.autenticar(any(), any(), any(), any()))
                .thenReturn(new ResultadoLogin(false, 'F', null, "Usuario ou senha invalidos.", null));
        ResultadoLogin r = svc.login("joao", "x", "/amb", "ip");
        assertThat(r.codErro()).isEqualTo('F');
        verify(attempts).registerFailure("joao");
    }

    @Test
    void bloqueado_X_antes_de_autenticar() {
        when(attempts.get("joao")).thenReturn(99);
        ResultadoLogin r = svc.login("joao", "x", "/amb", "ip");
        assertThat(r.codErro()).isEqualTo('X');
        verify(banco, org.mockito.Mockito.never()).autenticar(any(), any(), any(), any());
    }

    @Test
    void captcha_K_apos_exceder_o_limite() {
        when(attempts.registerFailure("joao")).thenReturn(4);   // > maxErrosCaptcha(3), <= maxErros(5)
        when(banco.autenticar(any(), any(), any(), any()))
                .thenReturn(new ResultadoLogin(false, 'F', null, "invalidos", null));
        assertThat(svc.login("joao", "x", "/amb", "ip").codErro()).isEqualTo('K');
    }

    @Test
    void estado_E_ou_M_nao_emite_sessao_mas_zera_tentativas() {
        when(banco.autenticar(any(), any(), any(), any()))
                .thenReturn(new ResultadoLogin(false, 'M', null, "Troque a senha.", null));
        ResultadoLogin r = svc.login("joao", "s", "/amb", "ip");
        assertThat(r.codErro()).isEqualTo('M');
        assertThat(r.sessionKey()).isNull();
        verify(attempts).reset("joao");   // credencial válida -> zera tentativas
    }

    @Test
    void escolhe_a_strategy_pela_config_do_cliente() {
        when(resolver.metodoDe("/u/itau/x")).thenReturn("OAUTH");
        when(oauth.autenticar(any(), any(), any(), any()))
                .thenReturn(new ResultadoLogin(true, 'T', null, "OK", null));
        svc.login("joao", "token", "/u/itau/x", "ip");
        verify(oauth).autenticar(any(), any(), any(), any());
        verify(banco, org.mockito.Mockito.never()).autenticar(any(), any(), any(), any());
    }
}
