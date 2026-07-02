package com.prognum.launcher.auth.adapter;

import com.prognum.launcher.auth.port.PasswordHistoryStore;
import org.springframework.stereotype.Component;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

/** Historico de senhas in-memory. Depois: tabela de hashes no banco. */
@Component
public class InMemoryPasswordHistoryStore implements PasswordHistoryStore {

    private final ConcurrentHashMap<String, Deque<String>> historico = new ConcurrentHashMap<>();

    @Override
    public List<String> hashes(String usuario) {
        Deque<String> d = historico.get(key(usuario));
        return d == null ? List.of() : new ArrayList<>(d);
    }

    @Override
    public void push(String usuario, String hash, int max) {
        if (hash == null || max <= 0) {
            return;
        }
        Deque<String> d = historico.computeIfAbsent(key(usuario), k -> new ArrayDeque<>());
        synchronized (d) {
            d.addFirst(hash);
            while (d.size() > max) {
                d.removeLast();
            }
        }
    }

    private String key(String usuario) {
        return usuario == null ? "" : usuario.trim().toLowerCase();
    }
}
