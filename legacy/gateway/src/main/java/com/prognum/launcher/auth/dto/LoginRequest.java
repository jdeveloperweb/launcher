package com.prognum.launcher.auth.dto;

/** Credenciais do login (Rota A). 'captcha' usado apos bloqueio progressivo. */
public record LoginRequest(
        String usuario,
        String senha,
        String ambiente,
        String captcha
) {
}
