package com.prognum.scci.documentos;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;

import org.junit.jupiter.api.Test;

import com.prognum.scci.documentos.application.EnviarDocumentoService;
import com.prognum.scci.documentos.domain.port.out.AntiMalware;
import com.prognum.scci.documentos.domain.port.out.ArmazenadorDocumento;
import com.prognum.scci.documentos.domain.port.out.ConversorImagemPdf;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * Upload: valida extensão → anti-malware → conversão → gravação (por id e por pasta). Testado com
 * fakes dos três ports (allow-list vazia == sem restrição, salvo teste dedicado).
 */
class EnviarDocumentoServiceTest {

    private static final String AMB = "/u10/cliente/scat";

    /** Fake do armazenador (grava versão por id e insere arquivo por pasta). */
    static class FakeArmazenador implements ArmazenadorDocumento {
        byte[] conteudoGravado;
        String nomeGravado;
        int idPaiRecebido = -1;

        public int gravarVersao(int id, String nome, byte[] conteudo, String usuario, String amb) {
            conteudoGravado = conteudo;
            nomeGravado = nome;
            return 3;                          // versão
        }

        public int inserirArquivoVersao(int idPai, String nome, byte[] conteudo, String usuario, String amb) {
            idPaiRecebido = idPai;
            conteudoGravado = conteudo;
            nomeGravado = nome;
            return 777;                        // id do documento (ID_INSERIDO)
        }
    }

    @Test
    void por_id_verifica_converte_e_grava_versao() {
        byte[] original = "imagem".getBytes(StandardCharsets.ISO_8859_1);
        byte[] convertido = "pdf".getBytes(StandardCharsets.ISO_8859_1);
        AtomicReference<String> escaneado = new AtomicReference<>();

        AntiMalware am = (c, nome) -> escaneado.set(nome);
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(convertido, "foto.pdf");
        FakeArmazenador arm = new FakeArmazenador();

        int versao = new EnviarDocumentoService(am, conv, arm, Set.of()).enviar(9, "foto.jpg", original, "joao", AMB);

        assertThat(versao).isEqualTo(3);
        assertThat(escaneado.get()).isEqualTo("foto.jpg");     // anti-malware no arquivo original
        assertThat(arm.conteudoGravado).isEqualTo(convertido); // grava o conteúdo convertido
        assertThat(arm.nomeGravado).isEqualTo("foto.pdf");
    }

    @Test
    void por_pasta_cria_ou_acha_o_no_e_devolve_id() {
        AntiMalware am = (c, nome) -> { };
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(c, nome);
        FakeArmazenador arm = new FakeArmazenador();

        int id = new EnviarDocumentoService(am, conv, arm, Set.of())
                .enviarParaPasta(50, "contrato.pdf", new byte[]{1, 2}, "maria", AMB);

        assertThat(id).isEqualTo(777);
        assertThat(arm.idPaiRecebido).isEqualTo(50);
        assertThat(arm.nomeGravado).isEqualTo("contrato.pdf");
    }

    @Test
    void anti_malware_reprovado_aborta_sem_gravar() {
        AntiMalware am = (c, nome) -> {
            throw new AntiMalware.ArquivoInfectado("EICAR");
        };
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(c, nome);
        FakeArmazenador arm = new FakeArmazenador();
        assertThatThrownBy(() -> new EnviarDocumentoService(am, conv, arm, Set.of()).enviar(1, "x.exe", new byte[]{1}, "u", AMB))
                .isInstanceOf(AntiMalware.ArquivoInfectado.class);
        assertThat(arm.conteudoGravado).isNull();
    }

    @Test
    void extensao_fora_da_allowlist_e_rejeitada_antes_do_anti_malware() {
        AtomicReference<String> escaneado = new AtomicReference<>();
        AntiMalware am = (c, nome) -> escaneado.set(nome);     // não deve ser chamado
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(c, nome);
        FakeArmazenador arm = new FakeArmazenador();

        EnviarDocumentoService svc = new EnviarDocumentoService(am, conv, arm, Set.of("pdf", "jpg"));

        assertThatThrownBy(() -> svc.enviar(1, "script.exe", new byte[]{1}, "u", AMB))
                .isInstanceOf(EnviarDocumentoService.ExtensaoNaoPermitida.class);
        assertThat(escaneado.get()).isNull();          // não chegou a escanear
        assertThat(arm.conteudoGravado).isNull();       // não chegou a gravar
    }

    @Test
    void extensao_na_allowlist_passa_normalmente() {
        AntiMalware am = (c, nome) -> { };
        ConversorImagemPdf conv = (c, nome) -> new ConversorImagemPdf.Resultado(c, nome);
        FakeArmazenador arm = new FakeArmazenador();

        EnviarDocumentoService svc = new EnviarDocumentoService(am, conv, arm, Set.of("pdf", "jpg"));
        int versao = svc.enviar(1, "contrato.PDF", new byte[]{1}, "u", AMB);   // case-insensitive

        assertThat(versao).isEqualTo(3);
    }
}
