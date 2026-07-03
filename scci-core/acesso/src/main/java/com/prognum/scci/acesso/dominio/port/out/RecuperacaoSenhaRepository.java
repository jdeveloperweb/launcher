package com.prognum.scci.acesso.dominio.port.out;

import com.prognum.scci.acesso.dominio.model.DadosRecuperacao;

import java.util.Optional;

/**
 * Port de saida da recuperacao de senha: le os dados do usuario + SMTP da entidade e grava a senha
 * TEMPORARIA (forcando troca no proximo login), fiel ao ExecutaEmailPwd do loginbd.pas.
 */
public interface RecuperacaoSenhaRepository {

    Optional<DadosRecuperacao> buscar(String usuario, String ambiente);

    /** Grava a nova senha (md5crypt) e marca IN_TROCA_SENHA_PROXIMO_LOGIN = 'T'. */
    void gravarSenhaTemporaria(String usuario, String ambiente, String novoHash);
}
