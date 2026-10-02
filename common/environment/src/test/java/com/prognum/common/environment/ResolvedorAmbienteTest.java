package com.prognum.common.environment;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * Trava o porte do VirtualPathToFisical do launcher.pas: tradução virtual->físico pela seção
 * [DIRETORIOS] do launcher.conf, com a divergência proposital (sem match => devolve como veio).
 */
class ResolvedorAmbienteTest {

    @TempDir
    Path tmp;

    private static final String CONF = String.join("\n",
            "# comentario ignorado",
            "[DIRETORIOS]",
            "home=/home",
            "cfiae=/home/cfiae/dados",
            "cdhu-ht=home/scci_data/dados",   // valor SEM '/' inicial -> normaliza p/ /home/scci_data/dados
            "",
            "[ENV]",
            "FOO=/nao/traduz");

    private ResolvedorAmbiente comConf(String conteudo) throws IOException {
        Path f = tmp.resolve("launcher.conf");
        Files.writeString(f, conteudo, StandardCharsets.ISO_8859_1);
        return new ResolvedorAmbiente(f.toString());
    }

    @Test
    void traduz_virtual_para_fisico() throws IOException {
        assertThat(comConf(CONF).resolver("/cfiae/")).isEqualTo("/home/cfiae/dados/");
    }

    @Test
    void mantem_o_resto_do_caminho() throws IOException {
        assertThat(comConf(CONF).resolver("/cfiae/sub/arq.pdf")).isEqualTo("/home/cfiae/dados/sub/arq.pdf");
    }

    @Test
    void caminho_fisico_passa_pela_entrada_home() throws IOException {
        // com home=/home, /home/cfiae/dados casa 'home' e volta igual (quem já manda físico continua)
        assertThat(comConf(CONF).resolver("/home/cfiae/dados")).isEqualTo("/home/cfiae/dados");
    }

    @Test
    void sem_barra_final_nao_casa_volta_como_veio() throws IOException {
        // legado daria vazio; divergência proposital: devolve como veio
        assertThat(comConf(CONF).resolver("/cfiae")).isEqualTo("/cfiae");
    }

    @Test
    void prefixo_falso_nao_casa() throws IOException {
        assertThat(comConf(CONF).resolver("/cfiaex/y")).isEqualTo("/cfiaex/y");
    }

    @Test
    void valor_sem_barra_inicial_e_normalizado() throws IOException {
        assertThat(comConf(CONF).resolver("/cdhu-ht/doc")).isEqualTo("/home/scci_data/dados/doc");
    }

    @Test
    void entrada_de_outra_secao_nao_traduz() throws IOException {
        assertThat(comConf(CONF).resolver("/FOO/x")).isEqualTo("/FOO/x");
    }

    @Test
    void arquivo_ausente_devolve_como_veio() {
        ResolvedorAmbiente r = new ResolvedorAmbiente(tmp.resolve("nao-existe.conf").toString());
        assertThat(r.resolver("/cfiae/")).isEqualTo("/cfiae/");
        assertThat(r.resolver("/home/x/dados")).isEqualTo("/home/x/dados");
    }

    @Test
    void primeira_entrada_que_casa_vence_a_ordem() throws IOException {
        // duas entradas que casam /app/sub/f: a PRIMEIRA do arquivo vence (fiel ao while do legado)
        String conf = "[DIRETORIOS]\napp/sub=/primeiro\napp=/segundo\n";
        assertThat(comConf(conf).resolver("/app/sub/f")).isEqualTo("/primeiro/f");
    }

    @Test
    void nulo_e_vazio_voltam_iguais() throws IOException {
        ResolvedorAmbiente r = comConf(CONF);
        assertThat(r.resolver(null)).isNull();
        assertThat(r.resolver("")).isEmpty();
    }

    @Test
    void idempotente_sobre_caminho_ja_fisico() throws IOException {
        ResolvedorAmbiente r = comConf(CONF);
        String fisico = r.resolver("/cfiae/");               // /home/cfiae/dados/
        assertThat(r.resolver(fisico)).isEqualTo(fisico);     // reaplicar não muda
    }

    @Test
    void rele_o_arquivo_quando_muda() throws IOException {
        Path f = tmp.resolve("launcher.conf");
        Files.writeString(f, "[DIRETORIOS]\ncli=/antigo\n", StandardCharsets.ISO_8859_1);
        ResolvedorAmbiente r = new ResolvedorAmbiente(f.toString());
        assertThat(r.resolver("/cli/x")).isEqualTo("/antigo/x");

        // reescreve com mapeamento novo e empurra o mtime pra frente (garante detecção)
        Files.writeString(f, "[DIRETORIOS]\ncli=/novo/lugar\n", StandardCharsets.ISO_8859_1);
        Files.setLastModifiedTime(f, FileTime.fromMillis(System.currentTimeMillis() + 5000));
        assertThat(r.resolver("/cli/x")).isEqualTo("/novo/lugar/x");
    }
}
