package com.prognum.scci.documentos;

import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.aplicacao.EnviarDocumentoService;
import com.prognum.scci.documentos.dominio.port.out.AntiMalware;
import com.prognum.scci.documentos.dominio.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.dominio.port.out.ConversorImagemPdf;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Upload: anti-malware → conversão → gravação. Testado com fakes dos três ports. */
class EnviarDocumentoServiceTest {

    private static final String AMB = "/u10/cliente/scat";

    @Test
    void verifica_converte_e_grava_nova_versao() {
        byte[] original = "imagem".getBytes(StandardCharsets.ISO_8859_1);
        byte[] convertido = "pdf".getBytes(StandardCharsets.ISO_8859_1);
        AtomicReference<String> escaneado = new AtomicReference<>();
        AtomicReference<byte[]> gravado = new AtomicReference<>();

        AntiMalware am = (c, nome) -> escaneado.set(nome);
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(convertido, "foto.pdf");
        ArmazenadorDocumento arm = (id, nome, conteudo, usuario, amb) -> {
            gravado.set(conteudo);
            assertThat(nome).isEqualTo("foto.pdf");     // usa o nome pós-conversão
            return 3;
        };

        int versao = new EnviarDocumentoService(am, conv, arm).enviar(9, "foto.jpg", original, "joao", AMB);

        assertThat(versao).isEqualTo(3);
        assertThat(escaneado.get()).isEqualTo("foto.jpg");   // anti-malware no arquivo original
        assertThat(gravado.get()).isEqualTo(convertido);     // grava o conteúdo convertido
    }

    @Test
    void anti_malware_reprovado_aborta_sem_gravar() {
        AntiMalware am = (c, nome) -> {
            throw new AntiMalware.ArquivoInfectado("EICAR");
        };
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(c, nome);
        ArmazenadorDocumento arm = (id, nome, conteudo, usuario, amb) -> {
            throw new AssertionError("nao deveria gravar arquivo reprovado");
        };
        assertThatThrownBy(() -> new EnviarDocumentoService(am, conv, arm).enviar(1, "x.exe", new byte[]{1}, "u", AMB))
                .isInstanceOf(AntiMalware.ArquivoInfectado.class);
    }
}
