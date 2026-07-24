package com.prognum.gateway.documentos;

import com.prognum.gateway.documentos.model.RespostaDocumento;
import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.execucao.model.ResultadoExecucao;
import com.prognum.gateway.execucao.port.out.ExecutorPrograma;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Download de documento: interpreta a resposta [len(4,LE)][XML metadados][binário] do sccidoc. */
class DocumentoServiceTest {

    private final ExecutorPrograma executor = mock(ExecutorPrograma.class);
    private final DocumentoService svc = new DocumentoService(executor);

    private final ComandoExecucao cmd =
            new ComandoExecucao("/amb", "wdoc", "documentoOperacao", "GET", "{}", "joao", "ip", true);

    /** Monta a resposta crua [LE32 len][xml][binário] como String ISO-8859-1 (1 byte = 1 char). */
    private static String resposta(String xml, byte[] binario) {
        byte[] x = xml.getBytes(StandardCharsets.ISO_8859_1);
        ByteArrayOutputStream bos = new ByteArrayOutputStream();
        bos.write(x.length & 0xFF);
        bos.write((x.length >> 8) & 0xFF);
        bos.write((x.length >> 16) & 0xFF);
        bos.write((x.length >> 24) & 0xFF);
        bos.writeBytes(x);
        bos.writeBytes(binario);
        return new String(bos.toByteArray(), StandardCharsets.ISO_8859_1);
    }

    @Test
    void resposta_com_Nome_e_arquivo_binario() {
        byte[] pdf = "%PDF-1.4 conteudo".getBytes(StandardCharsets.ISO_8859_1);
        String corpo = resposta("<Nome>doc.pdf</Nome><Tipo>.pdf</Tipo><DOW>true</DOW>", pdf);
        when(executor.executar(any())).thenReturn(new ResultadoExecucao(false, corpo));

        RespostaDocumento d = svc.baixar(cmd);
        assertThat(d.erro()).isFalse();
        assertThat(d.arquivo()).isTrue();
        assertThat(d.nome()).isEqualTo("doc.pdf");
        assertThat(d.tipo()).isEqualTo(".pdf");
        assertThat(d.download()).isTrue();
        assertThat(d.conteudo()).isEqualTo(pdf);
    }

    @Test
    void erro_do_programa_vira_texto_json() {
        when(executor.executar(any()))
                .thenReturn(new ResultadoExecucao(true, "{\"success\":false,\"message\":\"Stream read error\"}"));
        RespostaDocumento d = svc.baixar(cmd);
        assertThat(d.erro()).isTrue();
        assertThat(d.arquivo()).isFalse();
        assertThat(d.texto()).contains("Stream read error");
    }

    @Test
    void resposta_json_sem_prefixo_e_texto_de_passagem() {
        String json = "{\"success\":true}";
        when(executor.executar(any())).thenReturn(new ResultadoExecucao(false, json));
        RespostaDocumento d = svc.baixar(cmd);
        assertThat(d.arquivo()).isFalse();
        assertThat(d.texto()).isEqualTo(json);
    }

    @Test
    void size_prefixed_sem_Nome_nao_e_arquivo() {
        String corpo = resposta("<Tipo>.txt</Tipo>", "x".getBytes(StandardCharsets.ISO_8859_1));
        when(executor.executar(any())).thenReturn(new ResultadoExecucao(false, corpo));
        assertThat(svc.baixar(cmd).arquivo()).isFalse();
    }
}
