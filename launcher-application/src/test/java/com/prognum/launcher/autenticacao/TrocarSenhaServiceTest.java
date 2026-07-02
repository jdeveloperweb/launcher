package com.prognum.launcher.autenticacao;

import com.prognum.launcher.autenticacao.model.HistoricoSenhas;
import com.prognum.launcher.autenticacao.model.ResultadoTroca;
import com.prognum.launcher.autenticacao.policy.PasswordPolicy;
import com.prognum.launcher.autenticacao.port.out.SenhaRepository;
import com.prognum.launcher.autenticacao.port.out.VerificadorSenha;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Regras da TROCA de senha (PASSWD/ExecutaPasswdBD). Porte do WcopPasswordServiceTest. */
class TrocarSenhaServiceTest {

    private final SenhaRepository repo = mock(SenhaRepository.class);
    private final VerificadorSenha verificador = mock(VerificadorSenha.class);
    private final PasswordPolicy policy = new PasswordPolicy(8, true, 1, 1, 1, 1, 3, 3);
    private final TrocarSenhaService svc = new TrocarSenhaService(repo, verificador, policy);

    private static final String ATUAL = "ATUAL_HASH";

    private void usuario(List<String> anteriores) {
        when(repo.ler(eq("joao"), any())).thenReturn(Optional.of(new HistoricoSenhas(ATUAL, anteriores)));
    }

    @Test
    void senhaAtualIncorreta_naoGrava() {
        usuario(List.of("", "", "", "", ""));
        when(verificador.matches("ERRADA", ATUAL)).thenReturn(false);
        ResultadoTroca r = svc.trocar("joao", "ERRADA", "Xy7#kqLm", "/amb");
        assertFalse(r.sucesso());
        assertTrue(r.mensagem().toLowerCase().contains("atual incorreta"));
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void senhaNovaFraca_naoGrava() {
        usuario(List.of("", "", "", "", ""));
        when(verificador.matches("Atual@1", ATUAL)).thenReturn(true);
        ResultadoTroca r = svc.trocar("joao", "Atual@1", "fraca", "/amb");
        assertFalse(r.sucesso());
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void rodizio_igualAAtual_naoGrava() {
        usuario(List.of("", "", "", "", ""));
        when(verificador.matches("Atual@1", ATUAL)).thenReturn(true);
        when(verificador.matches("Xy7#kqLm", ATUAL)).thenReturn(true);   // nova == atual
        ResultadoTroca r = svc.trocar("joao", "Atual@1", "Xy7#kqLm", "/amb");
        assertFalse(r.sucesso());
        assertTrue(r.mensagem().toLowerCase().contains("ja foi usada"));
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void rodizio_igualAoHistorico_naoGrava() {
        usuario(List.of("NO1_HASH", "", "", "", ""));
        when(verificador.matches("Atual@1", ATUAL)).thenReturn(true);
        when(verificador.matches("Xy7#kqLm", ATUAL)).thenReturn(false);
        when(verificador.matches("Xy7#kqLm", "NO1_HASH")).thenReturn(true);   // nova == NO_SENHA1
        ResultadoTroca r = svc.trocar("joao", "Atual@1", "Xy7#kqLm", "/amb");
        assertFalse(r.sucesso());
        assertTrue(r.mensagem().toLowerCase().contains("ja foi usada"));
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void sucesso_gravaComRotacao() {
        usuario(List.of("", "", "", "", ""));
        when(verificador.matches("Atual@1", ATUAL)).thenReturn(true);
        when(verificador.matches("Xy7#kqLm", ATUAL)).thenReturn(false);
        when(verificador.gerarHashMd5Crypt("Xy7#kqLm")).thenReturn("$1$novo$hash");
        ResultadoTroca r = svc.trocar("joao", "Atual@1", "Xy7#kqLm", "/amb");
        assertTrue(r.sucesso());
        verify(repo, times(1)).gravar(eq("joao"), eq("/amb"), anyString());
    }
}
