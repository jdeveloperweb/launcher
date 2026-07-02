package com.prognum.launcher.documentos;

import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.launcher.documentos.model.RespostaDocumento;
import com.prognum.launcher.documentos.port.in.BaixarDocumentoUseCase;
import com.prognum.launcher.documentos.port.out.DocumentosJavaPort;
import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

import static org.assertj.core.api.Assertions.assertThat;

/** Decisão do roteador: flag JAVA chama o scci-core; PASCAL (ou método não migrado) executa o wdoc. */
class RoteadorBaixarDocumentoTest {

    private static final RespostaDocumento DO_PASCAL =
            new RespostaDocumento(false, false, null, null, false, null, "PASCAL");
    private static final RespostaDocumento DO_JAVA =
            new RespostaDocumento(false, true, ".pdf", "x.pdf", false, new byte[]{1}, null);

    private final BaixarDocumentoUseCase pascal = c -> DO_PASCAL;

    private static ComandoExecucao cmd() {
        return new ComandoExecucao("/amb", "wdoc", "GetDocumento", "GET", "{\"ID\":\"5\"}", "u", "ip", true);
    }

    private static FeatureRegistry flag(boolean documentosJava) {
        return nome -> "documentos".equals(nome) && documentosJava
                ? Optional.of(new FeatureFlag("documentos", true, 100)) : Optional.empty();
    }

    @Test
    void flag_java_e_metodo_migrado_usa_scci_core() {
        DocumentosJavaPort java = c -> Optional.of(DO_JAVA);
        var r = new RoteadorBaixarDocumento(pascal, java, flag(true)).baixar(cmd());
        assertThat(r).isEqualTo(DO_JAVA);
    }

    @Test
    void flag_java_mas_metodo_nao_migrado_cai_no_pascal() {
        DocumentosJavaPort java = c -> Optional.empty();   // scci-core não suporta o método
        var r = new RoteadorBaixarDocumento(pascal, java, flag(true)).baixar(cmd());
        assertThat(r).isEqualTo(DO_PASCAL);
    }

    @Test
    void flag_pascal_executa_wdoc() {
        DocumentosJavaPort java = c -> Optional.of(DO_JAVA);   // nem seria chamado
        var r = new RoteadorBaixarDocumento(pascal, java, flag(false)).baixar(cmd());
        assertThat(r).isEqualTo(DO_PASCAL);
    }
}
