package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Teste de integracao do CACHE DE AMBIENTE (launcherenv.ini) — Req. seções 4/10.
 * Grava um launcherenv.ini temporario e altera o campo DB para observar cache-hit (nao rele),
 * invalidacao (rele), expiracao por TTL (rele apos o tempo) e modo sem-cache (sempre disco).
 * Prova a estrategia de cache com TTL/invalidacao configuraveis do {@link LauncherEnvReader}.
 */
class LauncherEnvReaderCacheTest {

    private static void escreveIni(Path dir, String db) throws IOException {
        Files.writeString(dir.resolve("launcherenv.ini"),
                "[USERS]\nDRIVERNAME=POSTGRES\nDB_HOSTNAME=h\nDB=" + db + "\nDB_USER=u\nDB_PASS=p\n",
                StandardCharsets.ISO_8859_1);
    }

    @Test
    void cacheHit_naoReleDoDiscoDentroDaVida(@TempDir Path dir) throws Exception {
        escreveIni(dir, "BANCO_A");
        LauncherEnvReader reader = new LauncherEnvReader(true, 0); // cache ligado, sem expiracao por tempo
        assertEquals("BANCO_A", reader.ler(dir.toString()).database());
        escreveIni(dir, "BANCO_B"); // arquivo muda no disco...
        assertEquals("BANCO_A", reader.ler(dir.toString()).database(),
                "com cache, deve servir o valor cacheado (nao reler o disco)");
    }

    @Test
    void invalidar_forcaReleituraDoDisco(@TempDir Path dir) throws Exception {
        escreveIni(dir, "BANCO_A");
        LauncherEnvReader reader = new LauncherEnvReader(true, 0);
        assertEquals("BANCO_A", reader.ler(dir.toString()).database());
        escreveIni(dir, "BANCO_B");
        reader.invalidar(dir.toString());
        assertEquals("BANCO_B", reader.ler(dir.toString()).database(),
                "apos invalidar(), deve reler o disco e ver o novo valor");
    }

    @Test
    void ttl_expiraEReleAposOTempo(@TempDir Path dir) throws Exception {
        escreveIni(dir, "BANCO_A");
        LauncherEnvReader reader = new LauncherEnvReader(true, 1); // TTL = 1s
        assertEquals("BANCO_A", reader.ler(dir.toString()).database());
        escreveIni(dir, "BANCO_B");
        assertEquals("BANCO_A", reader.ler(dir.toString()).database(), "dentro do TTL: ainda cacheado");
        Thread.sleep(1300); // passa o TTL
        assertEquals("BANCO_B", reader.ler(dir.toString()).database(), "apos o TTL: rele o disco");
    }

    @Test
    void semCache_sempreLeDoDisco(@TempDir Path dir) throws Exception {
        escreveIni(dir, "BANCO_A");
        LauncherEnvReader reader = new LauncherEnvReader(false, 0); // cache desligado
        assertEquals("BANCO_A", reader.ler(dir.toString()).database());
        escreveIni(dir, "BANCO_B");
        assertEquals("BANCO_B", reader.ler(dir.toString()).database(),
                "sem cache, cada leitura vem do disco");
    }
}
