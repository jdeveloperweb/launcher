package com.prognum.launcher.legacy.login;

import com.prognum.launcher.auth.PasswordVerifier;
import com.prognum.launcher.auth.policy.PasswordPolicy;
import com.prognum.launcher.legacy.db.LauncherEnvReader;
import com.prognum.launcher.legacy.db.SccDbConfig;
import com.prognum.launcher.legacy.db.SccPasswordRepository;
import com.prognum.launcher.legacy.db.SccPasswordRepository.Senhas;
import org.apache.commons.codec.digest.Md5Crypt;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
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

/** Regras da TROCA de senha (PASSWD do loginbd.pas / ExecutaPasswdBD). */
class WcopPasswordServiceTest {

    private final LauncherEnvReader env = mock(LauncherEnvReader.class);
    private final SccPasswordRepository repo = mock(SccPasswordRepository.class);
    private final PasswordVerifier passwords = new PasswordVerifier();
    private final PasswordPolicy policy = new PasswordPolicy(8, true, 1, 1, 1, 1, 3, 3);
    private final WcopPasswordService svc = new WcopPasswordService(env, repo, passwords, policy);

    private final SccDbConfig cfg = new SccDbConfig("POSTGRES", "h", "db", "u", "p",
            "usuario", "USUARIO", "senha", "DT_VAL", "DT_ULT", "MAX", "MIN", "TROCA");

    private static String md5(String s) {
        return Md5Crypt.md5Crypt(s.getBytes(StandardCharsets.UTF_8), "$1$abcdef$");
    }

    private void usuarioCom(String atual, List<String> anteriores) {
        when(repo.ler(any(), eq("joao"))).thenReturn(Optional.of(new Senhas(md5(atual), anteriores)));
    }

    @BeforeEach
    void setup() {
        when(env.ler(any())).thenReturn(cfg);
    }

    @Test
    void senhaAtualIncorreta_naoGrava() {
        usuarioCom("Atual@123", List.of("", "", "", "", ""));
        var r = svc.trocar("joao", "ERRADA", "Xy7#kqLm", "/amb");
        assertFalse(r.sucesso());
        assertTrue(r.mensagem().toLowerCase().contains("atual incorreta"));
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void senhaNovaFraca_naoGrava() {
        usuarioCom("Atual@123", List.of("", "", "", "", ""));
        var r = svc.trocar("joao", "Atual@123", "fraca", "/amb");
        assertFalse(r.sucesso());
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void rodizio_igualAAtual_naoGrava() {
        // nova == atual: precisa ser forte (passa na politica) para chegar ao rodizio.
        usuarioCom("Xy7#kqLm", List.of("", "", "", "", ""));
        var r = svc.trocar("joao", "Xy7#kqLm", "Xy7#kqLm", "/amb");
        assertFalse(r.sucesso());
        assertTrue(r.mensagem().toLowerCase().contains("ja foi usada"));
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void rodizio_igualAoHistorico_naoGrava() {
        usuarioCom("Atual@123", List.of(md5("Antiga@99"), "", "", "", ""));
        var r = svc.trocar("joao", "Atual@123", "Antiga@99", "/amb");
        assertFalse(r.sucesso());
        assertTrue(r.mensagem().toLowerCase().contains("ja foi usada"));
        verify(repo, never()).gravar(any(), any(), any());
    }

    @Test
    void sucesso_gravaComRotacao() {
        usuarioCom("Atual@123", List.of("", "", "", "", ""));
        var r = svc.trocar("joao", "Atual@123", "Xy7#kqLm", "/amb");
        assertTrue(r.sucesso());
        verify(repo, times(1)).gravar(eq(cfg), eq("joao"), anyString());
    }
}
