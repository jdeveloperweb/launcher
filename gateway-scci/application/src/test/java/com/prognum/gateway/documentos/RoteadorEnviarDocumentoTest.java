package com.prognum.gateway.documentos;

import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.gateway.documentos.model.RespostaDocumento;
import com.prognum.gateway.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.gateway.documentos.port.out.DocumentosJavaPort;
import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.roteamento.model.FeatureFlag;
import com.prognum.gateway.roteamento.port.out.FeatureRegistry;

import static org.assertj.core.api.Assertions.assertThat;

/** Decisão do roteador de upload: flag JAVA chama o scci-core; PASCAL (ou não migrado) executa o wdoc. */
class RoteadorEnviarDocumentoTest {

    private final EnviarDocumentoUseCase pascal = lista -> List.of("PASCAL");

    private static ComandoExecucao cmd() {
        return new ComandoExecucao("/amb", "wdoc", "PostDocumento", "POST",
                "{\"IDPAI\":\"7\",\"FileName\":\"x.pdf\"}", "u", "ip", true, new byte[]{1, 2});
    }

    private static FeatureRegistry flag(boolean java) {
        return nome -> "documentos".equals(nome) && java
                ? Optional.of(new FeatureFlag("documentos", true, 100)) : Optional.empty();
    }

    private static DocumentosJavaPort java(Optional<String> resp) {
        return new DocumentosJavaPort() {
            public Optional<RespostaDocumento> baixar(ComandoExecucao c) {
                return Optional.empty();
            }

            public Optional<String> enviar(ComandoExecucao c) {
                return resp;
            }
        };
    }

    @Test
    void flag_java_e_migrado_usa_scci_core() {
        var r = new RoteadorEnviarDocumento(pascal, java(Optional.of("{\"ID_INSERIDO\":9}")), flag(true))
                .enviar(List.of(cmd()));
        assertThat(r).containsExactly("{\"ID_INSERIDO\":9}");
    }

    @Test
    void flag_java_mas_nao_migrado_cai_no_pascal() {
        var r = new RoteadorEnviarDocumento(pascal, java(Optional.empty()), flag(true)).enviar(List.of(cmd()));
        assertThat(r).containsExactly("PASCAL");
    }

    @Test
    void flag_pascal_executa_wdoc() {
        var r = new RoteadorEnviarDocumento(pascal, java(Optional.of("x")), flag(false)).enviar(List.of(cmd()));
        assertThat(r).containsExactly("PASCAL");
    }
}
