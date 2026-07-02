package com.prognum.scci.documentos;

import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.aplicacao.BaixarDocumentoEntidadeService;
import com.prognum.scci.documentos.aplicacao.BaixarDocumentoService.DocumentoNaoEncontrado;
import com.prognum.scci.documentos.dominio.Documento;
import com.prognum.scci.documentos.dominio.port.in.BaixarDocumento;
import com.prognum.scci.documentos.dominio.port.out.ResolvedorDocumento;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** Leitura por entidade (GetDocumentoOperacao/Sisat): resolve id → delega ao read. Fakes de resolver + read. */
class BaixarDocumentoEntidadeServiceTest {

    private static final String AMB = "/u10/cliente/scat";

    /** Fake do read: devolve um Documento marcado com o id resolvido, pra checar a composição. */
    static class FakeBaixar implements BaixarDocumento {
        public Documento baixar(int id, boolean download, String amb) {
            return new Documento("doc-" + id + ".pdf", "application/pdf", new byte[]{(byte) id}, download);
        }

        public Documento baixarVersao(int id, int v, boolean download, String amb) {
            return baixar(id, download, amb);
        }
    }

    @Test
    void operacao_resolve_id_e_baixa() {
        ResolvedorDocumento resolvedor = new ResolvedorDocumento() {
            public Optional<Integer> idPorOperacao(String p, String d, boolean cs, String a) {
                return Optional.of(321);
            }

            public Optional<Integer> idPorSisat(int o, String d, String a) {
                return Optional.empty();
            }
        };
        Documento doc = new BaixarDocumentoEntidadeService(resolvedor, new FakeBaixar())
                .porOperacao("000123456", "7", false, true, AMB);
        assertThat(doc.nome()).isEqualTo("doc-321.pdf");
        assertThat(doc.download()).isTrue();
    }

    @Test
    void sisat_resolve_id_e_baixa() {
        ResolvedorDocumento resolvedor = new ResolvedorDocumento() {
            public Optional<Integer> idPorOperacao(String p, String d, boolean cs, String a) {
                return Optional.empty();
            }

            public Optional<Integer> idPorSisat(int o, String d, String a) {
                return Optional.of(999);
            }
        };
        Documento doc = new BaixarDocumentoEntidadeService(resolvedor, new FakeBaixar())
                .porSisat(55, "3", false, AMB);
        assertThat(doc.nome()).isEqualTo("doc-999.pdf");
    }

    @Test
    void nao_resolvido_lanca_nao_encontrado() {
        ResolvedorDocumento vazio = new ResolvedorDocumento() {
            public Optional<Integer> idPorOperacao(String p, String d, boolean cs, String a) {
                return Optional.empty();
            }

            public Optional<Integer> idPorSisat(int o, String d, String a) {
                return Optional.empty();
            }
        };
        assertThatThrownBy(() -> new BaixarDocumentoEntidadeService(vazio, new FakeBaixar())
                .porOperacao("1", "1", false, false, AMB))
                .isInstanceOf(DocumentoNaoEncontrado.class);
    }
}
