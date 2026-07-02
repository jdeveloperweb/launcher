package com.prognum.launcher.autenticacao.port.out;

/**
 * Port de saida das validacoes de acesso do login-por-CPF/protocolo (ValidaCpf/ValidaProtocolo do
 * loginbd.pas): checam no banco do ambiente se o CPF tem operacao de credito ou se o protocolo
 * existe. Fiel a semantica do Pascal (achou = acesso valido).
 */
public interface ValidacaoAcessoRepository {

    /** CPF corresponde a alguma operacao de credito (pessoa_pretendente/operacao_credito)? */
    boolean cpfComOperacao(String cpf, String ambiente);

    /** Protocolo existe em ocorrencia_sisat? */
    boolean protocoloExiste(String protocolo, String ambiente);
}
