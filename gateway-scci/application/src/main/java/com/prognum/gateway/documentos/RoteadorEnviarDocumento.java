package com.prognum.gateway.documentos;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import com.prognum.gateway.documentos.port.in.EnviarDocumentoUseCase;
import com.prognum.gateway.documentos.port.out.DocumentosJavaPort;
import com.prognum.gateway.execucao.model.ComandoExecucao;
import com.prognum.gateway.roteamento.model.FeatureFlag;
import com.prognum.gateway.roteamento.port.out.FeatureRegistry;

/**
 * Roteador do UPLOAD de documentos (Strangler) — decorator do {@link EnviarDocumentoUseCase}. Por arquivo,
 * decide (feature-flag {@code documentos.<metodo>} → {@code documentos} → PASCAL) entre chamar o scci-core
 * (JAVA, {@link DocumentosJavaPort#enviar}) ou executar o {@code wdoc} (Pascal). Fallback seguro ao Pascal
 * quando o método não é migrado (Java devolve vazio) ou a flag é PASCAL. POJO puro.
 */
public class RoteadorEnviarDocumento implements EnviarDocumentoUseCase {

    private final EnviarDocumentoUseCase pascal;
    private final DocumentosJavaPort java;
    private final FeatureRegistry flags;

    public RoteadorEnviarDocumento(EnviarDocumentoUseCase pascal, DocumentosJavaPort java, FeatureRegistry flags) {
        this.pascal = pascal;
        this.java = java;
        this.flags = flags;
    }

    @Override
    public List<String> enviar(List<ComandoExecucao> arquivos) {
        List<String> respostas = new ArrayList<>(arquivos.size());
        for (ComandoExecucao cmd : arquivos) {
            respostas.add(enviarUm(cmd));
        }
        return respostas;
    }

    private String enviarUm(ComandoExecucao cmd) {
        if (usaJava(cmd.methodName())) {
            Optional<String> r = java.enviar(cmd);
            if (r.isPresent()) {                 // vazio = método não migrado -> fallback Pascal
                return r.get();
            }
        }
        return pascal.enviar(List.of(cmd)).get(0);
    }

    private boolean usaJava(String metodo) {
        Optional<FeatureFlag> especifica = flags.consultar("documentos." + metodo);
        if (especifica.isPresent()) {
            return especifica.get().habilitado();
        }
        return flags.consultar("documentos").map(FeatureFlag::habilitado).orElse(false);
    }
}
