package com.prognum.scci.documentos;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.domain.TipoMime;

import static org.assertj.core.api.Assertions.assertThat;

/** content-type por extensão — porte do case de tipos do sccidoc.pas. */
class TipoMimeTest {

    @Test
    void mapeia_extensoes_conhecidas() {
        assertThat(TipoMime.doNome("relatorio.pdf")).isEqualTo("application/pdf");
        assertThat(TipoMime.doNome("planilha.xlsx"))
                .isEqualTo("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        assertThat(TipoMime.doNome("foto.PNG")).isEqualTo("image/png");     // case-insensitive
        assertThat(TipoMime.doNome("dados.csv")).isEqualTo("text/csv");
        assertThat(TipoMime.porExtensao(".doc")).isEqualTo("application/msword");
    }

    @Test
    void extensao_desconhecida_ou_ausente_vira_octet_stream() {
        assertThat(TipoMime.doNome("arquivo.xyz")).isEqualTo("application/octet-stream");
        assertThat(TipoMime.doNome("semextensao")).isEqualTo("application/octet-stream");
        assertThat(TipoMime.doNome(null)).isEqualTo("application/octet-stream");
    }

    @Test
    void extrai_extensao() {
        assertThat(TipoMime.extensao("a.b.PDF")).isEqualTo("pdf");
        assertThat(TipoMime.extensao("semponto")).isEmpty();
    }
}
