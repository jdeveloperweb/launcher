package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Leitura da politica de senha POR AMBIENTE (secao [USERS] do launcherenv.ini). */
class LauncherEnvReaderPoliticaTest {

    private static void escreve(Path dir, String conteudo) throws IOException {
        Files.writeString(dir.resolve("launcherenv.ini"), conteudo, StandardCharsets.ISO_8859_1);
    }

    @Test
    void leChavesDePolitica(@TempDir Path dir) throws Exception {
        escreve(dir, "[USERS]\nDB=x\nUSERMINCARACPASS=8\nCARMINALFAPASS=2\nCARMINNUMPASS=1\nUSERMAXREPPASS=3\n");
        PoliticaSenhaIni p = new LauncherEnvReader().politicaSenha(dir.toString());
        assertEquals(8, p.minCaracteres());
        assertEquals(2, p.minLetras());
        assertEquals(1, p.minDigitos());
        assertEquals(3, p.maxRepetidos());
        assertFalse(p.vazia());
    }

    @Test
    void clienteCFIAe_semChavesDePolitica_politicaVazia(@TempDir Path dir) throws Exception {
        // fiel ao launcherenv.ini do CFIAe: so colunas de conexao/dias, NENHUMA regra de composicao
        escreve(dir, "[USERS]\nDB=/home/cfiae/dados/scci.gdb\nUSERTABLE=USUARIO\n"
                + "USERMINPASS=NU_MIN_DIAS_TROCA_SENHA\nUSERMAXPASS=NU_MAX_DIAS_TROCA_SENHA\n");
        PoliticaSenhaIni p = new LauncherEnvReader().politicaSenha(dir.toString());
        assertTrue(p.vazia(), "cliente sem chaves de politica -> politica vazia (sem exigencia de composicao)");
    }
}
