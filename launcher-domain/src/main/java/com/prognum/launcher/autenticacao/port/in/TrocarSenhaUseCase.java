package com.prognum.launcher.autenticacao.port.in;

import com.prognum.launcher.autenticacao.model.ResultadoTroca;

/** Port de entrada: troca de senha (PASSWD do loginbd.pas / ExecutaPasswdBD). */
public interface TrocarSenhaUseCase {

    ResultadoTroca trocar(String usuario, String senhaAtual, String novaSenha, String ambiente);
}
