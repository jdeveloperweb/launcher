package com.prognum.launcher.legacy.login;

import com.prognum.launcher.auth.PasswordVerifier;
import com.prognum.launcher.auth.port.LoginAttemptStore;
import com.prognum.launcher.legacy.db.LauncherEnvReader;
import com.prognum.launcher.legacy.db.SccDbConfig;
import com.prognum.launcher.legacy.db.SccLoginRepository;
import com.prognum.launcher.legacy.db.SccLoginRepository.SccUser;
import org.apache.commons.codec.digest.Md5Crypt;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Regras de LOGIN (ExecutaLoginBD/TestaUsuario do loginbd.pas): estados T/C/E/M/B/F. */
class WcopLoginServiceTest {

    private final LauncherEnvReader env = mock(LauncherEnvReader.class);
    private final SccLoginRepository repo = mock(SccLoginRepository.class);
    private final PasswordVerifier passwords = new PasswordVerifier();
    private final LoginAttemptStore attempts = mock(LoginAttemptStore.class);
    private final WcopLoginService svc =
            new WcopLoginService(env, repo, passwords, attempts, 0, 5, 3, true, 5);

    private final SccDbConfig cfg = new SccDbConfig("POSTGRES", "h", "db", "u", "p",
            "usuario", "USUARIO", "senha", "DT_VAL", "DT_ULT", "MAX", "MIN", "TROCA");

    private static String md5(String s) {
        return Md5Crypt.md5Crypt(s.getBytes(StandardCharsets.UTF_8), "$1$abcdef$");
    }

    private void usuario(String senhaHash, LocalDate dtValidade, String mustChange) {
        when(repo.buscar(any(), eq("joao")))
                .thenReturn(Optional.of(new SccUser(senhaHash, dtValidade, null, null, null, mustChange)));
    }

    @BeforeEach
    void setup() {
        when(env.ler(any())).thenReturn(cfg);
        when(attempts.get(any())).thenReturn(0);
    }

    @Test
    void senhaCorreta_okT() {
        usuario(md5("Senha@123"), null, "f");
        var r = svc.login("joao", "Senha@123", "/amb", "ip");
        assertTrue(r.sucesso());
        assertEquals('T', r.codErro());
        assertNotNull(r.sessionKey());
    }

    @Test
    void senhaErrada_F() {
        usuario(md5("Senha@123"), null, "f");
        var r = svc.login("joao", "ERRADA", "/amb", "ip");
        assertFalse(r.sucesso());
        assertEquals('F', r.codErro());
    }

    @Test
    void contaExpirada_E() {
        usuario(md5("Senha@123"), LocalDate.now().minusDays(1), "f");
        var r = svc.login("joao", "Senha@123", "/amb", "ip");
        assertFalse(r.sucesso());
        assertEquals('E', r.codErro());
    }

    @Test
    void trocaObrigatoria_M() {
        usuario(md5("Senha@123"), null, "T");
        var r = svc.login("joao", "Senha@123", "/amb", "ip");
        assertFalse(r.sucesso());
        assertEquals('M', r.codErro());
    }

    @Test
    void usuarioInexistente_F() {
        when(repo.buscar(any(), eq("zzz"))).thenReturn(Optional.empty());
        var r = svc.login("zzz", "x", "/amb", "ip");
        assertFalse(r.sucesso());
        assertEquals('F', r.codErro());
    }
}
