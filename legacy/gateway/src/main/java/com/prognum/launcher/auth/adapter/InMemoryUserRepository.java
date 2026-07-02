package com.prognum.launcher.auth.adapter;

import com.prognum.launcher.auth.PasswordVerifier;
import com.prognum.launcher.auth.domain.User;
import com.prognum.launcher.auth.port.UserRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Repositorio SIMULADO (in-memory) com usuarios cobrindo os estados do catalogo.
 * Senha de todos: "Senha@123" (hash bcrypt gerado no startup).
 * Trocar por um adapter Firebird depois — so esta classe muda.
 */
@Repository
public class InMemoryUserRepository implements UserRepository {

    private final Map<String, User> porUsuario = new LinkedHashMap<>();

    public InMemoryUserRepository(PasswordVerifier passwords) {
        String hash = passwords.hash("Senha@123");
        LocalDate hoje = LocalDate.now();

        add(new User("joao",   "larcky", hash, true,  hoje.plusYears(1), hoje.minusDays(10),  90, false)); // OK
        add(new User("maria",  "larcky", hash, true,  hoje.plusYears(1), hoje.minusDays(10),  90, true));  // TROCA_OBRIGATORIA
        add(new User("carlos", "larcky", hash, true,  hoje.minusDays(1), hoje.minusDays(10),  90, false)); // SENHA_EXPIRADA
        add(new User("ana",    "larcky", hash, false, hoje.plusYears(1), hoje.minusDays(10),  90, false)); // USUARIO_INATIVO
        add(new User("bia",    "larcky", hash, true,  hoje.plusYears(1), hoje.minusDays(88),  90, false)); // SENHA_VAI_EXPIRAR (faltam 2 dias)

        // Usuario com hash LEGADO (md5crypt, como vem do loginbd/usuario.gdb):
        // no primeiro login bem-sucedido e migrado para bcrypt (Q8).
        add(new User("legado", "larcky", passwords.md5crypt("Senha@123"), true,
                hoje.plusYears(1), hoje.minusDays(10), 90, false));
    }

    private void add(User u) {
        porUsuario.put(u.usuario().toLowerCase(), u);
    }

    @Override
    public Optional<User> findByUsuario(String usuario, String ambiente) {
        if (usuario == null) {
            return Optional.empty();
        }
        // Fase 1: cliente unico — o ambiente nao discrimina o lookup ainda.
        return Optional.ofNullable(porUsuario.get(usuario.trim().toLowerCase()));
    }

    @Override
    public void trocarSenha(String usuario, String ambiente, String novoHash, LocalDate ultimaTroca) {
        if (usuario == null) {
            return;
        }
        User u = porUsuario.get(usuario.trim().toLowerCase());
        if (u == null) {
            return;
        }
        porUsuario.put(usuario.trim().toLowerCase(),
                new User(u.usuario(), u.ambiente(), novoHash, u.ativo(),
                        u.dtValidade(), ultimaTroca, u.maxDiasTroca(), false));
    }

    @Override
    public void atualizarHash(String usuario, String ambiente, String novoHash) {
        if (usuario == null) {
            return;
        }
        User u = porUsuario.get(usuario.trim().toLowerCase());
        if (u == null) {
            return;
        }
        // troca SO o hash (mantem validade, ultima troca, mustChange etc.)
        porUsuario.put(usuario.trim().toLowerCase(),
                new User(u.usuario(), u.ambiente(), novoHash, u.ativo(),
                        u.dtValidade(), u.ultimaTroca(), u.maxDiasTroca(), u.mustChange()));
    }
}
