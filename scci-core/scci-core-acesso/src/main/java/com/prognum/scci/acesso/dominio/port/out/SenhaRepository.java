package com.prognum.scci.acesso.dominio.port.out;

import com.prognum.scci.acesso.dominio.model.HistoricoSenhas;

import java.util.Optional;

/**
 * Port de saida: leitura/gravacao de senha para a troca (PASSWD do loginbd.pas).
 * O adapter grava rotacionando o historico (NO_SENHA1..5). GRAVA no banco do ambiente.
 */
public interface SenhaRepository {

    Optional<HistoricoSenhas> ler(String usuario, String ambiente);

    void gravar(String usuario, String ambiente, String novoHash);
}
