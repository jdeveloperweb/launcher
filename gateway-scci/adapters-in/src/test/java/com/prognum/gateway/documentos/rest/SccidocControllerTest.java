package com.prognum.gateway.documentos.rest;

import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;

/** Evidência dos helpers do canal /sccidoc: strip do [LE32] na resposta de upload e mime por extensão. */
class SccidocControllerTest {

    @Test
    void desembrulha_tira_o_prefixo_de_tamanho_da_resposta_de_upload() {
        // o PostDocumentoOperacao devolve [LE32 len][JSON] (SaveToStreamWithSize) -> precisa tirar o prefixo
        String json = "{\"success\":true}";
        String comPrefixo = comLE32(json);
        assertThat(SccidocController.desembrulhaTamanho(comPrefixo)).isEqualTo(json);
    }

    @Test
    void desembrulha_json_plano_sem_prefixo_fica_igual() {
        // sem prefixo válido, os 4 primeiros bytes ('{','"'...) dariam um tamanho gigante -> devolve como veio
        String json = "{\"success\":false}";
        assertThat(SccidocController.desembrulhaTamanho(json)).isEqualTo(json);
    }

    @Test
    void mime_por_extensao() {
        assertThat(SccidocController.mime(".PDF")).isEqualTo("application/pdf");
        assertThat(SccidocController.mime(".pdf")).isEqualTo("application/pdf");   // case-insensitive
        assertThat(SccidocController.mime(".XLSX"))
                .isEqualTo("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        assertThat(SccidocController.mime(".ZIP")).isEqualTo("application/zip");
        assertThat(SccidocController.mime(".PNG")).isEqualTo("image/png");
        assertThat(SccidocController.mime(".xyz")).isEqualTo("application/octet-stream");
        assertThat(SccidocController.mime(null)).isEqualTo("application/octet-stream");
    }

    /** [tamanho(4, little-endian)] + bytes (ISO-8859-1). */
    private static String comLE32(String s) {
        byte[] b = s.getBytes(StandardCharsets.ISO_8859_1);
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        bos.write(b.length & 0xFF);
        bos.write((b.length >> 8) & 0xFF);
        bos.write((b.length >> 16) & 0xFF);
        bos.write((b.length >> 24) & 0xFF);
        bos.writeBytes(b);
        return new String(bos.toByteArray(), StandardCharsets.ISO_8859_1);
    }
}
