package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

/**
 * Ambiente dos programas = secao [ENV] do launcher.conf (global do servidor) + [ENVIRONMENT] do
 * launcherenv.ini, que manda sobre ela — como o daemon legado, cujos programas herdam o [ENV].
 */
class LauncherEnvReaderEnvGlobalTest {

    private static final String CONF = "[DIRETORIOS]\ncfiae=/home/cfiae/dados\n"
            + "[ENV]\nTMP=/var/tmp\nLANG=pt_BR\nLC_ALL=pt_BR\nNODELAY=1\n";

    private static Path escreve(Path dir, String nome, String conteudo) throws IOException {
        Path arq = dir.resolve(nome);
        Files.writeString(arq, conteudo, StandardCharsets.ISO_8859_1);
        return arq;
    }

    @Test
    void env_do_launcher_conf_chega_ao_ambiente_do_programa(@TempDir Path dir) throws Exception {
        Path conf = escreve(dir, "launcher.conf", CONF);
        escreve(dir, "launcherenv.ini", "[ENVIRONMENT]\nCLIENTE=CFIAe\n[USERS]\nDB=x\n");
        Map<String, String> env = new LauncherEnvReader().ambienteEnv(dir.toString(), "supervisor", conf);
        assertEquals("pt_BR", env.get("LANG"));
        assertEquals("pt_BR", env.get("LC_ALL"));
        assertEquals("/var/tmp", env.get("TMP"));
        assertEquals("1", env.get("NODELAY"));
        assertEquals("CFIAe", env.get("CLIENTE"));
        assertEquals("supervisor", env.get("USER"));
        assertFalse(env.containsKey("cfiae"), "[DIRETORIOS] nao e ambiente de programa");
    }

    @Test
    void launcherenv_ini_manda_sobre_o_launcher_conf(@TempDir Path dir) throws Exception {
        Path conf = escreve(dir, "launcher.conf", CONF);
        escreve(dir, "launcherenv.ini", "[ENVIRONMENT]\nLC_ALL=pt_BR.ISO-8859-1\nTMPDIR=$TMP/x\n");
        Map<String, String> env = new LauncherEnvReader().ambienteEnv(dir.toString(), "u", conf);
        assertEquals("pt_BR.ISO-8859-1", env.get("LC_ALL"));
        assertEquals("pt_BR", env.get("LANG"));
        assertEquals("/var/tmp/x", env.get("TMPDIR"), "o ini expande variaveis vindas do [ENV]");
    }

    @Test
    void sem_launcher_conf_fica_so_o_launcherenv_ini(@TempDir Path dir) throws Exception {
        escreve(dir, "launcherenv.ini", "[ENVIRONMENT]\nCLIENTE=CFIAe\n");
        Map<String, String> env = new LauncherEnvReader()
                .ambienteEnv(dir.toString(), "u", dir.resolve("nao-existe.conf"));
        assertEquals("CFIAe", env.get("CLIENTE"));
        assertFalse(env.containsKey("LANG"));
    }
}
