package com.prognum.common.environment;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * SEG_IDENTIFICACAO do [SEGURANCA] (chave fixa da conta de integracao 'loginintegracao'). Lida DIRETO
 * do ambiente do request — sem o override de SCCIDIRATV (que no multi-ambiente leria o launcherenv errado).
 */
class LauncherEnvReaderSegIdentificacaoTest {

    private static void escreve(Path dir, String conteudo) throws IOException {
        Files.writeString(dir.resolve("launcherenv.ini"), conteudo, StandardCharsets.ISO_8859_1);
    }

    @Test
    void le_seg_identificacao_do_ambiente(@TempDir Path dir) throws Exception {
        escreve(dir, "[SEGURANCA]\nSEG_SISTEMA=loginintegracao\nSEG_SERVICO=\nSEG_IDENTIFICACAO=DXJKLDEOSX\n");
        assertThat(new LauncherEnvReader().segIdentificacao(dir.toString())).isEqualTo("DXJKLDEOSX");
    }

    @Test
    void ignora_linha_comentada_e_pega_a_ativa(@TempDir Path dir) throws Exception {
        // fiel ao launcherenv do simulador: uma linha comentada + a ativa
        escreve(dir, "[SEGURANCA]\n#SEG_IDENTIFICACAO=\nSEG_IDENTIFICACAO=CHAVE123\n");
        assertThat(new LauncherEnvReader().segIdentificacao(dir.toString())).isEqualTo("CHAVE123");
    }

    @Test
    void ausente_ou_vazio_devolve_null(@TempDir Path dir) throws Exception {
        escreve(dir, "[SEGURANCA]\nSEG_SISTEMA=loginbd\nSEG_IDENTIFICACAO=\n[ENVIRONMENT]\nCLIENTE=X\n");
        assertThat(new LauncherEnvReader().segIdentificacao(dir.toString())).isNull();   // vazio -> null

        escreve(dir, "[ENVIRONMENT]\nCLIENTE=X\n[USERS]\nDB=x\n");
        assertThat(new LauncherEnvReader().segIdentificacao(dir.toString())).isNull();   // sem [SEGURANCA] -> null
    }

    @Test
    void ambiente_nulo_devolve_null() {
        assertThat(new LauncherEnvReader().segIdentificacao(null)).isNull();
    }
}
