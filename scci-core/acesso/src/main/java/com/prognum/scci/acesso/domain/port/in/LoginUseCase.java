package com.prognum.scci.acesso.domain.port.in;

import com.prognum.scci.acesso.domain.model.ResultadoLogin;

/** Port de entrada: login nativo do W_COP/loginbd (estados T/C/E/M/B/F/K/X). */
public interface LoginUseCase {

    ResultadoLogin login(String usuario, String senha, String ambiente, String ip);
}
