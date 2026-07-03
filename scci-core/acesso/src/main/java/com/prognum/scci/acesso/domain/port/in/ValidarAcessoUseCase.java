package com.prognum.scci.acesso.domain.port.in;

/**
 * Port de entrada das validacoes de acesso (login por CPF/protocolo). Building block do modo
 * ExecutaLoginWebReact do loginbd — exposto tambem como validacao isolada (/w/valida-acesso).
 */
public interface ValidarAcessoUseCase {

    boolean cpfValido(String cpf, String ambiente);

    boolean protocoloValido(String protocolo, String ambiente);
}
