package com.prognum.launcher.autenticacao;

import com.prognum.launcher.autenticacao.model.CredenciaisUsuario;
import com.prognum.launcher.autenticacao.model.ResultadoLogin;
import com.prognum.launcher.autenticacao.port.out.CredenciaisRepository;
import com.prognum.launcher.autenticacao.port.out.VerificadorSenha;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Strategy BANCO (loginbd/TestaUsuario): senha md5crypt + estados T/F/E/M (sem sessão — é do coordenador). */
class AutenticadorBancoTest {

    private final CredenciaisRepository repo = mock(CredenciaisRepository.class);
    private final VerificadorSenha verificador = mock(VerificadorSenha.class);
    private final AutenticadorBanco aut = new AutenticadorBanco(repo, verificador, 5);

    private void usuario(String hash, LocalDate dtValidade, String mustChange) {
        when(repo.buscar(eq("joao"), any()))
                .thenReturn(Optional.of(new CredenciaisUsuario(hash, dtValidade, null, null, null, mustChange)));
    }

    @Test
    void metodo_e_BANCO() {
        assertThat(aut.metodo()).isEqualTo("BANCO");
    }

    @Test
    void senha_correta_T_sem_sessionKey() {
        usuario("HASH", null, "f");
        when(verificador.matches(eq("Senha@123"), anyString())).thenReturn(true);
        ResultadoLogin r = aut.autenticar("joao", "Senha@123", "/amb", "ip");
        assertThat(r.sucesso()).isTrue();
        assertThat(r.codErro()).isEqualTo('T');
        assertThat(r.sessionKey()).isNull();   // o coordenador emite a sessão
    }

    @Test
    void senha_errada_F() {
        usuario("HASH", null, "f");
        when(verificador.matches(eq("ERRADA"), anyString())).thenReturn(false);
        assertThat(aut.autenticar("joao", "ERRADA", "/amb", "ip").codErro()).isEqualTo('F');
    }

    @Test
    void inexistente_F() {
        when(repo.buscar(eq("zzz"), any())).thenReturn(Optional.empty());
        assertThat(aut.autenticar("zzz", "x", "/amb", "ip").codErro()).isEqualTo('F');
    }

    @Test
    void conta_expirada_E() {
        usuario("HASH", LocalDate.now().minusDays(1), "f");
        when(verificador.matches(eq("Senha@123"), anyString())).thenReturn(true);
        assertThat(aut.autenticar("joao", "Senha@123", "/amb", "ip").codErro()).isEqualTo('E');
    }

    @Test
    void troca_obrigatoria_M() {
        usuario("HASH", null, "T");
        when(verificador.matches(eq("Senha@123"), anyString())).thenReturn(true);
        assertThat(aut.autenticar("joao", "Senha@123", "/amb", "ip").codErro()).isEqualTo('M');
    }
}
