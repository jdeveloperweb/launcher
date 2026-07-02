package com.prognum.launcher.autenticacao;

import com.prognum.launcher.autenticacao.model.DadosRecuperacao;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.port.out.EnvioEmail;
import com.prognum.launcher.autenticacao.port.out.RecuperacaoSenhaRepository;
import com.prognum.launcher.autenticacao.port.out.VerificadorSenha;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Recuperação de senha por e-mail (ExecutaEmailPwd do loginbd.pas). */
class RecuperarSenhaServiceTest {

    private final RecuperacaoSenhaRepository repo = mock(RecuperacaoSenhaRepository.class);
    private final VerificadorSenha passwords = mock(VerificadorSenha.class);
    private final EnvioEmail email = mock(EnvioEmail.class);
    private final RecuperarSenhaService svc = new RecuperarSenhaService(repo, passwords, email);

    private void usuarioCadastrado(String cpf, String mail, String smtp) {
        when(repo.buscar(eq("joao"), any()))
                .thenReturn(Optional.of(new DadosRecuperacao(cpf, mail, smtp, "smtpuser", "smtppass")));
        when(passwords.gerarHashMd5Crypt(anyString())).thenReturn("$1$novohash");
    }

    @Test
    void supervisor_bloqueado() {
        ResultadoTroca r = svc.recuperar("supervisor", "12345678901", "/amb");
        assertThat(r.sucesso()).isFalse();
        verify(repo, never()).gravarSenhaTemporaria(any(), any(), any());
    }

    @Test
    void cpf_111_bloqueado() {
        assertThat(svc.recuperar("joao", "111.111.111-11", "/amb").sucesso()).isFalse();
    }

    @Test
    void cpf_invalido_ou_usuario_branco() {
        assertThat(svc.recuperar("", "12345678901", "/amb").sucesso()).isFalse();
        assertThat(svc.recuperar("joao", "123", "/amb").sucesso()).isFalse();   // < 11 dígitos
    }

    @Test
    void cpf_nao_bate_com_cadastro() {
        usuarioCadastrado("99999999999", "j@x.com", "smtp");
        assertThat(svc.recuperar("joao", "12345678901", "/amb").sucesso()).isFalse();
    }

    @Test
    void sem_email_ou_smtp_cadastrado() {
        usuarioCadastrado("12345678901", "", "smtp");
        assertThat(svc.recuperar("joao", "12345678901", "/amb").sucesso()).isFalse();
    }

    @Test
    void sucesso_gera_grava_e_envia() {
        usuarioCadastrado("12345678901", "joao@x.com", "smtp.x.com");
        ResultadoTroca r = svc.recuperar("joao", "123.456.789-01", "/amb");
        assertThat(r.sucesso()).isTrue();
        verify(repo).gravarSenhaTemporaria(eq("joao"), eq("/amb"), eq("$1$novohash"));
        verify(email).enviar(eq("smtp.x.com"), any(), any(), eq("joao@x.com"), anyString(), anyString());
    }

    @Test
    void falha_no_envio_de_email_retorna_erro() {
        usuarioCadastrado("12345678901", "joao@x.com", "smtp.x.com");
        doThrow(new RuntimeException("smtp down"))
                .when(email).enviar(any(), any(), any(), any(), any(), any());
        assertThat(svc.recuperar("joao", "12345678901", "/amb").sucesso()).isFalse();
    }
}
