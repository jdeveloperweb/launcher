package com.prognum.gateway.autenticacao.port.out;

/**
 * Porta de saida: a chave de sessao FIXA da conta de integracao ({@code loginintegracao}) — o
 * {@code SEG_IDENTIFICACAO} do {@code [SEGURANCA]} do launcherenv.ini do ambiente. Porte do
 * loginintegracao.pas, que valida a integracao STATELESS: {@code usuario='loginintegracao'} +
 * {@code sessionKey == SEG_IDENTIFICACAO}, sem store de sessao.
 */
public interface SegurancaIntegracao {

    /** SEG_IDENTIFICACAO (chave fixa) do ambiente, ou {@code null} se nao configurada. */
    String identificacao(String ambiente);
}
