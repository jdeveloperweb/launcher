package com.prognum.launcher.documentos.port.out;

import java.util.Optional;

import com.prognum.launcher.documentos.model.RespostaDocumento;
import com.prognum.launcher.execucao.model.ComandoExecucao;

/**
 * Saída do launcher para o contexto <b>documentos do scci-core</b> (REST interno) — o "outro caminho" do
 * roteador quando a feature-flag do módulo aponta JAVA em vez de executar o {@code wdoc} Pascal.
 *
 * Ambos devolvem {@link Optional#empty()} quando o método NÃO é migrado (relatório, merge, etc.) ou o
 * scci-core está inacessível — sinal para o roteador cair no Pascal (fallback seguro).
 */
public interface DocumentosJavaPort {

    /** Download (Get* do wdoc) → arquivo/erro. */
    Optional<RespostaDocumento> baixar(ComandoExecucao comando);

    /** Upload (Post* do wdoc) → corpo JSON da resposta (ex.: {@code {"success":true,"dados":{"ID_INSERIDO":..}}}). */
    Optional<String> enviar(ComandoExecucao comando);
}
