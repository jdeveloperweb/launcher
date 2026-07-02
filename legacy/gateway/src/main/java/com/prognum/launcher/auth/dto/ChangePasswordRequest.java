package com.prognum.launcher.auth.dto;

/** Troca de senha (RF01). */
public record ChangePasswordRequest(
        String usuario,
        String senhaAtual,
        String novaSenha,
        String ambiente
) {
}
