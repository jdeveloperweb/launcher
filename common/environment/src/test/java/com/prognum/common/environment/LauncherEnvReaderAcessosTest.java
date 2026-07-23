package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Leitura do limite de sessoes simultaneas POR AMBIENTE (ACESSOSSIMULTANEOS do [ENVIRONMENT]). */
class LauncherEnvReaderAcessosTest {

    private static void escreve(Path dir, String conteudo) throws IOException {
        Files.writeString(dir.resolve("launcherenv.ini"), conteudo, StandardCharsets.ISO_8859_1);
    }

    @Test
    void leAcessosSimultaneos_doAmbiente(@TempDir Path dir) throws Exception {
        // fiel ao launcherenv.ini do CFIAe: ACESSOSSIMULTANEOS=999
        escreve(dir, "[ENVIRONMENT]\nCLIENTE=CFIAe\nACESSOSSIMULTANEOS=999\n[USERS]\nDB=x\n");
        assertEquals(999, new LauncherEnvReader().acessosSimultaneos(dir.toString()));
    }

    @Test
    void ausente_retornaZero_paraCairNoFallbackGlobal(@TempDir Path dir) throws Exception {
        escreve(dir, "[ENVIRONMENT]\nCLIENTE=X\n[USERS]\nDB=x\n");
        assertEquals(0, new LauncherEnvReader().acessosSimultaneos(dir.toString()),
                "sem a chave -> 0 (o AutenticacaoController cai no limite global)");
    }
}
