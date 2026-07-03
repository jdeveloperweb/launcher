package com.prognum.scci.acesso.dominio.port.in;

import com.prognum.scci.acesso.dominio.model.ResultadoTroca;

/**
 * Port de entrada: recuperacao de senha por e-mail ("esqueci a senha", ExecutaEmailPwd do loginbd).
 * Gera uma senha temporaria, grava (forcando troca no proximo login) e envia por e-mail.
 */
public interface RecuperarSenhaUseCase {

    ResultadoTroca recuperar(String usuario, String cpf, String ambiente);
}
