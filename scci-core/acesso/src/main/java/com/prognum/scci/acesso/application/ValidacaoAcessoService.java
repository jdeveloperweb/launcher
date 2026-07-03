package com.prognum.scci.acesso.application;

import com.prognum.scci.acesso.domain.port.in.ValidarAcessoUseCase;
import com.prognum.scci.acesso.domain.port.out.ValidacaoAcessoRepository;

/**
 * Validacoes de acesso do login-por-CPF/protocolo (ValidaCpf/ValidaProtocolo do loginbd). POJO puro:
 * delega ao repositorio do ambiente. CPF/protocolo vazio = considerado valido (igual ao Pascal).
 */
public class ValidacaoAcessoService implements ValidarAcessoUseCase {

    private final ValidacaoAcessoRepository repo;

    public ValidacaoAcessoService(ValidacaoAcessoRepository repo) {
        this.repo = repo;
    }

    @Override
    public boolean cpfValido(String cpf, String ambiente) {
        if (cpf == null || cpf.isBlank()) {
            return true;   // Pascal: CPF vazio -> nao invalida
        }
        return repo.cpfComOperacao(cpf, ambiente);
    }

    @Override
    public boolean protocoloValido(String protocolo, String ambiente) {
        if (protocolo == null || protocolo.isBlank()) {
            return true;
        }
        return repo.protocoloExiste(protocolo, ambiente);
    }
}
