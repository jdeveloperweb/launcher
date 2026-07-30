package com.prognum.gateway.execucao.port.out;

/**
 * Port de saída do roteamento da EXECUÇÃO (Strangler, 3 trilhos). Por operação/programa decide o trilho:
 *
 * <ul>
 *   <li><b>puro</b>    — 100% migrado: scci-core PURO (só Java, sem SDK/Pascal);</li>
 *   <li><b>hibrido</b> — parcial: scci-core HÍBRIDO (Java orquestra + Pascal via SDK in-process);</li>
 *   <li><b>pascal</b>  — não migrado: executor Pascal direto (o comportamento legado).</li>
 * </ul>
 *
 * Dirigido por feature-flag (config): {@code gateway.execucao.rotas.<programa> = puro|hibrido|pascal};
 * quem não tem flag cai no default ({@code gateway.execucao.rota-default}, = pascal). Virar a flag
 * migra a operação de trilho sem código.
 */
public interface RotaExecucaoRegistry {

    /** Trilho da operação: {@code "puro"}, {@code "hibrido"} ou {@code "pascal"} (nunca nulo). */
    String trilho(String programa);
}
