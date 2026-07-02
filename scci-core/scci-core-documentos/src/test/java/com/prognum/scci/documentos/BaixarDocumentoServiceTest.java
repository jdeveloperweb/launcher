package com.prognum.scci.documentos;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService;
import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService.DocumentoNaoEncontrado;
import com.prognum.scci.documentos.aplicacao.ExcluirDocumentoService;
import com.prognum.scci.documentos.dominio.ArquivoBruto;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Casos de uso de leitura/exclusão — porte idiomático do GetDocumento/GetDocumentoVersao/DeleteDocumento. */
class BaixarDocumentoServiceTest {

    private static final String AMB = "/u10/cliente/scat";

    /** Fake em memória do port (última versão + por versão + exclusão). */
    static class FakeRepo implements RepositorioDocumento {
        final Map<Integer, ArquivoBruto> ultima = new HashMap<>();
        final Map<String, ArquivoBruto> porVersao = new HashMap<>();
        final java.util.List<Integer> excluidos = new java.util.ArrayList<>();

        public Optional<ArquivoBruto> buscarUltimaVersao(int id, String amb) {
            return Optional.ofNullable(ultima.get(id));
        }

        public Optional<ArquivoBruto> buscarVersao(int id, int versao, String amb) {
            return Optional.ofNullable(porVersao.get(id + ":" + versao));
        }

        public void excluir(int id, String amb) {
            excluidos.add(id);
        }
    }

    @Test
    void monta_documento_com_mime_da_extensao_e_flag_download() {
        byte[] bytes = "%PDF-1.4 conteudo".getBytes(StandardCharsets.ISO_8859_1);
        FakeRepo repo = new FakeRepo();
        repo.ultima.put(42, new ArquivoBruto("laudo.pdf", bytes));

        Documento doc = new BaixarDocumentoService(repo).baixar(42, true, AMB);

        assertThat(doc.nome()).isEqualTo("laudo.pdf");
        assertThat(doc.tipoMime()).isEqualTo("application/pdf");
        assertThat(doc.conteudo()).isEqualTo(bytes);
        assertThat(doc.download()).isTrue();
    }

    @Test
    void inline_quando_nao_download() {
        FakeRepo repo = new FakeRepo();
        repo.ultima.put(1, new ArquivoBruto("nota.txt", new byte[]{1, 2, 3}));
        Documento doc = new BaixarDocumentoService(repo).baixar(1, false, AMB);
        assertThat(doc.download()).isFalse();
        assertThat(doc.tipoMime()).isEqualTo("text/plain");
    }

    @Test
    void baixa_versao_especifica() {
        FakeRepo repo = new FakeRepo();
        repo.porVersao.put("7:2", new ArquivoBruto("contrato.docx", new byte[]{9}));
        Documento doc = new BaixarDocumentoService(repo).baixarVersao(7, 2, false, AMB);
        assertThat(doc.nome()).isEqualTo("contrato.docx");
        assertThat(doc.tipoMime())
                .isEqualTo("application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    }

    @Test
    void documento_inexistente_lanca_nao_encontrado() {
        FakeRepo repo = new FakeRepo();
        assertThatThrownBy(() -> new BaixarDocumentoService(repo).baixar(999, false, AMB))
                .isInstanceOf(DocumentoNaoEncontrado.class)
                .hasMessageContaining("999");
    }

    @Test
    void excluir_delega_ao_repositorio() {
        FakeRepo repo = new FakeRepo();
        new ExcluirDocumentoService(repo).excluir(55, AMB);
        assertThat(repo.excluidos).containsExactly(55);
    }
}
