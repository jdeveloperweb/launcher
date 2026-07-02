package com.prognum.scci.documentos;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.aplicacao.GerenciarEstruturaService;
import com.prognum.scci.documentos.dominio.port.out.EstruturaDocumento;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** PutNome/PutPasta — valida o nome e delega ao port. Fake do EstruturaDocumento. */
class GerenciarEstruturaServiceTest {

    private static final String AMB = "/u10/cliente/scat";

    static class FakeEstrutura implements EstruturaDocumento {
        String renomeado;
        int pastaPai = -1;

        public void renomear(int id, String novoNome, String amb) {
            renomeado = novoNome;
        }

        public int criarPasta(int idPai, String nome, boolean exibe, String amb) {
            pastaPai = idPai;
            return 123;
        }
    }

    @Test
    void renomeia_delegando_ao_port() {
        FakeEstrutura fake = new FakeEstrutura();
        new GerenciarEstruturaService(fake).renomear(9, "novo.pdf", AMB);
        assertThat(fake.renomeado).isEqualTo("novo.pdf");
    }

    @Test
    void cria_pasta_e_devolve_id() {
        FakeEstrutura fake = new FakeEstrutura();
        int id = new GerenciarEstruturaService(fake).criarPasta(4, "Contratos", true, AMB);
        assertThat(id).isEqualTo(123);
        assertThat(fake.pastaPai).isEqualTo(4);
    }

    @Test
    void nome_vazio_e_rejeitado() {
        assertThatThrownBy(() -> new GerenciarEstruturaService(new FakeEstrutura()).renomear(1, " ", AMB))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
