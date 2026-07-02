package com.prognum.scci.documentos;

import java.nio.charset.StandardCharsets;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService;
import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService.DocumentoNaoEncontrado;
import com.prognum.scci.documentos.dominio.ArquivoBruto;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Caso de uso de download — porte idiomático do GetDocumentoPorId, testado com fake do repositório. */
class BaixarDocumentoServiceTest {

    private static final String AMB = "/u10/cliente/scat";

    @Test
    void monta_documento_com_mime_da_extensao_e_flag_download() {
        byte[] bytes = "%PDF-1.4 conteudo".getBytes(StandardCharsets.ISO_8859_1);
        RepositorioDocumento repo = (id, amb) -> Optional.of(new ArquivoBruto("laudo.pdf", bytes));

        Documento doc = new BaixarDocumentoService(repo).baixar(42, true, AMB);

        assertThat(doc.nome()).isEqualTo("laudo.pdf");
        assertThat(doc.tipoMime()).isEqualTo("application/pdf");
        assertThat(doc.conteudo()).isEqualTo(bytes);
        assertThat(doc.download()).isTrue();
    }

    @Test
    void inline_quando_nao_download() {
        RepositorioDocumento repo = (id, amb) -> Optional.of(new ArquivoBruto("nota.txt", new byte[]{1, 2, 3}));
        Documento doc = new BaixarDocumentoService(repo).baixar(1, false, AMB);
        assertThat(doc.download()).isFalse();
        assertThat(doc.tipoMime()).isEqualTo("text/plain");
    }

    @Test
    void documento_inexistente_lanca_nao_encontrado() {
        RepositorioDocumento repo = (id, amb) -> Optional.empty();
        assertThatThrownBy(() -> new BaixarDocumentoService(repo).baixar(999, false, AMB))
                .isInstanceOf(DocumentoNaoEncontrado.class)
                .hasMessageContaining("999");
    }
}
