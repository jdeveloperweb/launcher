package com.prognum.launcher.documentos.port.out;

import java.util.Optional;

import com.prognum.launcher.documentos.model.RespostaDocumento;
import com.prognum.launcher.execucao.model.ComandoExecucao;

/**
 * Saída do launcher para o contexto <b>documentos do scci-core</b> (REST interno) — o "outro caminho" do
 * roteador quando a feature-flag do módulo aponta JAVA em vez de executar o {@code wdoc} Pascal.
 *
 * Devolve {@link Optional#empty()} quando o método do {@code wdoc} NÃO é um dos reads migrados (ex.:
 * relatório, upload, merge) — sinal para o roteador cair no Pascal (fallback seguro).
 */
public interface DocumentosJavaPort {

    Optional<RespostaDocumento> baixar(ComandoExecucao comando);
}
