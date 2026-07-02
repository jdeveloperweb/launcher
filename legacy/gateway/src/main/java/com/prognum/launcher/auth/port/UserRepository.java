package com.prognum.launcher.auth.port;

import com.prognum.launcher.auth.domain.User;

import java.time.LocalDate;
import java.util.Optional;

/** Porta de saida: origem dos usuarios. Hoje in-memory; depois Firebird (adapter). */
public interface UserRepository {
    Optional<User> findByUsuario(String usuario, String ambiente);

    /** Grava a nova senha (hash), atualiza a ultima troca e zera o "trocar no proximo login". */
    void trocarSenha(String usuario, String ambiente, String novoHash, LocalDate ultimaTroca);

    /** Atualiza apenas o hash — migracao transparente md5crypt -> bcrypt no login (Q8). */
    void atualizarHash(String usuario, String ambiente, String novoHash);
}
