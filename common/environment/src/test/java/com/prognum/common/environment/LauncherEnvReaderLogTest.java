package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Leitura da secao [LOG] do launcherenv.ini (log de eventos) e expansao de {@code $USER}.
 * Secao/arquivo ausente = mapa vazio (log de evento e OPCIONAL por cliente).
 */
class LauncherEnvReaderLogTest {

    private static void escreve(Path dir, String conteudo) throws IOException {
        Files.writeString(dir.resolve("launcherenv.ini"), conteudo, StandardCharsets.ISO_8859_1);
    }

    @Test
    void leSecaoLog_LOGIN_e_LOGOFF(@TempDir Path dir) throws Exception {
        escreve(dir, "[USERS]\nDB=x\n\n[LOG]\nLOGIN=sccilog -z LOGON $USER\nLOGOFF=sccilog -z LOGOFF $USER\n");
        Map<String, String> log = new LauncherEnvReader().logEventos(dir.toString());
        assertEquals("sccilog -z LOGON $USER", log.get("LOGIN"));
        assertEquals("sccilog -z LOGOFF $USER", log.get("LOGOFF"));
    }

    @Test
    void semSecaoLog_devolveVazio(@TempDir Path dir) throws Exception {
        escreve(dir, "[USERS]\nDB=x\n[ENVIRONMENT]\nCLIENTE=CFIAe\n");
        assertTrue(new LauncherEnvReader().logEventos(dir.toString()).isEmpty(), "sem [LOG] -> sem log de evento");
    }

    @Test
    void arquivoAusente_devolveVazioSemQuebrar() {
        assertTrue(new LauncherEnvReader().logEventos("/caminho/que/nao/existe").isEmpty());
    }

    @Test
    void expandeUsuarioNoComando() {
        String cmd = LauncherEnvReader.expandirVariaveis("sccilog -z LOGON $USER", Map.of("USER", "supervisor"));
        assertEquals("sccilog -z LOGON supervisor", cmd);
    }
}
