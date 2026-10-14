package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Recarga completa (o SIGHUP do legado): limpa o cache do launcherenv.ini, roda os caches proprios do
 * servico e mostra o valor efetivo das variaveis que o programa recebe (ex.: DATAH).
 */
class RecargaAmbienteTest {

    private static void escreveIni(Path dir, String db, String datah) throws IOException {
        Files.writeString(dir.resolve("launcherenv.ini"),
                "[ENVIRONMENT]\nDATAH=" + datah + "\nISC_PASSWORD=segredo\n"
                        + "[USERS]\nDRIVERNAME=POSTGRES\nDB_HOSTNAME=h\nDB=" + db + "\nDB_USER=u\nDB_PASS=p\n",
                StandardCharsets.ISO_8859_1);
    }

    @Test
    void sem_ambiente_limpa_o_cache_de_todos_e_roda_os_extras(@TempDir Path dir) throws Exception {
        escreveIni(dir, "BANCO_A", "20260101");
        LauncherEnvReader env = new LauncherEnvReader(true, 0);
        AtomicInteger extras = new AtomicInteger();
        RecargaAmbiente recarga = new RecargaAmbiente(env, extras::incrementAndGet);
        assertEquals("BANCO_A", env.ler(dir.toString()).database());
        escreveIni(dir, "BANCO_B", "20260101");

        Map<String, Object> r = recarga.recarregar(null, null);

        assertEquals("all", r.get("reloaded"));
        assertEquals(1, extras.get(), "caches proprios do servico tambem sao recarregados");
        assertEquals("BANCO_B", env.ler(dir.toString()).database(), "[USERS] relido do disco");
    }

    @Test
    void com_ambiente_mostra_o_datah_que_o_programa_recebe(@TempDir Path dir) throws Exception {
        escreveIni(dir, "BANCO_A", "20260719");
        RecargaAmbiente recarga = new RecargaAmbiente(new LauncherEnvReader(true, 0));

        Map<String, Object> r = recarga.recarregar(dir.toString(), List.of("DataH", "ISC_PASSWORD", "NAO_EXISTE"));

        assertEquals(dir.toString(), r.get("reloaded"));
        @SuppressWarnings("unchecked")
        Map<String, String> vars = (Map<String, String>) r.get("variaveis");
        assertEquals("20260719", vars.get("DataH"), "nome casa sem diferenciar maiuscula");
        assertEquals("***", vars.get("ISC_PASSWORD"), "valor sensivel nao sai na resposta");
        assertTrue(vars.containsKey("NAO_EXISTE"));
        assertNull(vars.get("NAO_EXISTE"));
    }

    @Test
    void variaveis_sem_ambiente_avisam_em_vez_de_falhar(@TempDir Path dir) throws Exception {
        Map<String, Object> r = new RecargaAmbiente(new LauncherEnvReader()).recarregar("", List.of("DATAH"));
        assertEquals("all", r.get("reloaded"));
        assertTrue(r.containsKey("aviso"));
        assertFalse(r.containsKey("variaveis"));
    }

    @Test
    void ambiente_sem_launcherenv_ini_devolve_erro(@TempDir Path dir) {
        Map<String, Object> r = new RecargaAmbiente(new LauncherEnvReader())
                .recarregar(dir.resolve("nao-existe").toString(), List.of("DATAH"));
        assertEquals(true, r.get("success"), "o reload em si aconteceu");
        assertTrue(r.containsKey("erro"));
    }

    @Test
    void datah_do_launcher_conf_chega_e_o_ini_manda_sobre_ele(@TempDir Path dir) throws Exception {
        Path conf = dir.resolve("launcher.conf");
        Files.writeString(conf, "[ENV]\nDATAH=20250101\nLANG=pt_BR\n", StandardCharsets.ISO_8859_1);
        Files.writeString(dir.resolve("launcherenv.ini"), "[ENVIRONMENT]\nCLIENTE=CDHU\n", StandardCharsets.ISO_8859_1);
        LauncherEnvReader env = new LauncherEnvReader();
        assertEquals("20250101", env.variaveisEfetivas(dir.toString(), List.of("DATAH"), conf).get("DATAH"));

        escreveIni(dir, "X", "20260719");
        assertEquals("20260719", env.variaveisEfetivas(dir.toString(), List.of("DATAH"), conf).get("DATAH"),
                "sem cache: a alteracao no ini vale na proxima leitura");
    }
}
