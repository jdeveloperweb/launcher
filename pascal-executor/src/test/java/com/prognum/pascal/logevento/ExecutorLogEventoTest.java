package com.prognum.pascal.logevento;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Log de eventos [LOG]/sccilog — MONTAGEM do comando (parte pura, testavel).
 * Expande {@code $USER}, mapeia o evento para a chave certa da secao [LOG] e anexa
 * {@code <ip> <origem> [session]} na ordem que o sccilog espera. Sem [LOG] p/ o evento -> vazio.
 */
class ExecutorLogEventoTest {

    private static final Map<String, String> SECAO = Map.of(
            "LOGIN", "sccilog -z LOGON $USER",
            "LOGOFF", "sccilog -z LOGOFF $USER",
            "LOGINERR", "sccilog -z LOGINERR $USER");

    @Test
    void login_montaSccilogLOGON_comUsuarioExpandido_eArgsNaOrdem() {
        List<String> argv = ExecutorLogEvento.montarComando(SECAO, Map.of("USER", "joao"),
                "login", "1.2.3.4", "CORP_WEB", "KEY123");
        assertEquals(List.of("sccilog", "-z", "LOGON", "joao", "1.2.3.4", "CORP_WEB", "KEY123"), argv);
    }

    @Test
    void logout_usaChaveLOGOFF() {
        List<String> argv = ExecutorLogEvento.montarComando(SECAO, Map.of("USER", "maria"),
                "logout", "9.9.9.9", "CORP_WEB", "S1");
        assertEquals(List.of("sccilog", "-z", "LOGOFF", "maria", "9.9.9.9", "CORP_WEB", "S1"), argv);
    }

    @Test
    void semSessionKey_naoAnexaOSexto() {
        List<String> argv = ExecutorLogEvento.montarComando(SECAO, Map.of("USER", "x"),
                "loginerr", "1.1.1.1", "CORP_WEB", null);
        assertEquals(List.of("sccilog", "-z", "LOGINERR", "x", "1.1.1.1", "CORP_WEB"), argv);
    }

    @Test
    void eventoSemEntradaNaSecaoLog_devolveVazio() {
        Map<String, String> soLogin = Map.of("LOGIN", "sccilog -z LOGON $USER"); // sem LOGOFF
        assertTrue(ExecutorLogEvento.montarComando(soLogin, Map.of("USER", "x"), "logout", "1.1.1.1", "CORP_WEB", null).isEmpty());
    }

    @Test
    void secaoLogVazia_devolveVazio() {
        assertTrue(ExecutorLogEvento.montarComando(Map.of(), Map.of("USER", "x"), "login", "1.1.1.1", "CORP_WEB", "K").isEmpty());
    }

    @Test
    void eventoDesconhecido_devolveVazio() {
        assertTrue(ExecutorLogEvento.montarComando(SECAO, Map.of("USER", "x"), "xpto", "1.1.1.1", "CORP_WEB", "K").isEmpty());
    }

    // --- classificacao da falha de execucao: binario ausente (esperado) x falha real ---

    @Test
    void programaInexistente_eClassificadoComoIndisponivel_naoComoFalha() {
        // exatamente o que o ProcessBuilder.start() lanca quando o sccilog nao esta no ambiente
        IOException semBinario = new IOException("Cannot run program \"sccilog\": error=2, No such file or directory");
        assertTrue(ExecutorLogEvento.programaIndisponivel(semBinario),
                "binario ausente -> indisponivel (INFO), nao WARN a cada acesso");
    }

    @Test
    void outrasFalhas_naoSaoIndisponivel_continuamSendoWarn() {
        assertFalse(ExecutorLogEvento.programaIndisponivel(new IOException("Permission denied")));
        assertFalse(ExecutorLogEvento.programaIndisponivel(new RuntimeException("Cannot run program \"x\"")),
                "so IOException conta (RuntimeException nao vem do start por binario ausente)");
        assertFalse(ExecutorLogEvento.programaIndisponivel(new InterruptedException("timeout")));
    }

    // --- resolucao do binario pelo PATH do ambiente (por que o sccilog nao rodava na desenv) ---

    @Test
    void resolveBinarioPeloPathDoAmbiente_naoPeloPathDaJvm(@TempDir Path dir) throws Exception {
        // simula /u/scci/binfpc/sccilog: um executavel achavel SO pelo PATH do launcherenv
        File bin = dir.resolve("sccilog").toFile();
        Files.writeString(bin.toPath(), "#!/bin/sh\n");
        bin.setExecutable(true);
        String path = "/usr/bin:/bin:" + dir;   // separador ':' (launcherenv e Linux)
        String resolvido = ExecutorLogEvento.resolverExecutavel("sccilog", Map.of("PATH", path));
        assertEquals(bin.getAbsolutePath(), resolvido, "deve virar o caminho absoluto do binfpc do ambiente");
    }

    @Test
    void comandoComCaminho_naoEhAlterado() {
        assertEquals("/u/scci/binfpc/sccilog",
                ExecutorLogEvento.resolverExecutavel("/u/scci/binfpc/sccilog", Map.of("PATH", "/qualquer")));
    }

    @Test
    void naoAchadoNoPath_devolveOriginal_paraCairEmIndisponivel() {
        assertEquals("sccilog", ExecutorLogEvento.resolverExecutavel("sccilog", Map.of("PATH", "/usr/bin:/bin")));
        assertEquals("sccilog", ExecutorLogEvento.resolverExecutavel("sccilog", Map.of()), "sem PATH -> inalterado");
    }
}
