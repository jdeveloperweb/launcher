package com.prognum.launcher.documentos;

import java.util.Optional;

import com.prognum.launcher.documentos.model.RespostaDocumento;
import com.prognum.launcher.documentos.port.in.BaixarDocumentoUseCase;
import com.prognum.launcher.documentos.port.out.DocumentosJavaPort;
import com.prognum.launcher.execucao.model.ComandoExecucao;
import com.prognum.launcher.roteamento.model.FeatureFlag;
import com.prognum.launcher.roteamento.port.out.FeatureRegistry;

/**
 * Roteador do canal de documentos (Strangler) — decorator do {@link BaixarDocumentoUseCase}. Para cada
 * chamada de download decide, pela feature-flag do módulo, entre:
 *
 * <ul>
 *   <li><b>JAVA</b> — chama o contexto documentos do scci-core ({@link DocumentosJavaPort}); ou</li>
 *   <li><b>PASCAL</b> — executa o {@code wdoc} real (o {@code documentoServicePascal}), como hoje.</li>
 * </ul>
 *
 * Flag: {@code documentos.<metodo>} (override por método) → {@code documentos} (default do domínio) →
 * PASCAL. Fallback seguro: se o método não é um dos reads migrados, o {@link DocumentosJavaPort} devolve
 * vazio e cai no Pascal. POJO puro.
 */
public class RoteadorBaixarDocumento implements BaixarDocumentoUseCase {

    private final BaixarDocumentoUseCase pascal;
    private final DocumentosJavaPort java;
    private final FeatureRegistry flags;

    public RoteadorBaixarDocumento(BaixarDocumentoUseCase pascal, DocumentosJavaPort java, FeatureRegistry flags) {
        this.pascal = pascal;
        this.java = java;
        this.flags = flags;
    }

    @Override
    public RespostaDocumento baixar(ComandoExecucao comando) {
        if (usaJava(comando.methodName())) {
            Optional<RespostaDocumento> r = java.baixar(comando);
            if (r.isPresent()) {                 // vazio = método não migrado -> fallback Pascal
                return r.get();
            }
        }
        return pascal.baixar(comando);
    }

    /** Flag por método ({@code documentos.<metodo>}) vence; senão o default do domínio ({@code documentos}). */
    private boolean usaJava(String metodo) {
        Optional<FeatureFlag> especifica = flags.consultar("documentos." + metodo);
        if (especifica.isPresent()) {
            return especifica.get().habilitado();
        }
        return flags.consultar("documentos").map(FeatureFlag::habilitado).orElse(false);
    }
}
