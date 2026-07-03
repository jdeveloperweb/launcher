package com.prognum.scci.acesso.domain.port.in;

import com.prognum.scci.acesso.domain.model.ResultadoTroca;

/** Port de entrada: troca de senha (PASSWD do loginbd.pas / ExecutaPasswdBD). */
public interface TrocarSenhaUseCase {

    ResultadoTroca trocar(String usuario, String senhaAtual, String novaSenha, String ambiente);
}
