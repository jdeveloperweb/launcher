package com.prognum.scci.acesso.dominio.port.out;

import com.prognum.scci.acesso.dominio.model.CredenciaisUsuario;

import java.util.Optional;

/**
 * Port de saida: consulta as credenciais do usuario na base do AMBIENTE (secao [USERS] do
 * launcherenv.ini). O adapter resolve a conexao/colunas por ambiente. SOMENTE LEITURA.
 */
public interface CredenciaisRepository {

    Optional<CredenciaisUsuario> buscar(String usuario, String ambiente);
}
