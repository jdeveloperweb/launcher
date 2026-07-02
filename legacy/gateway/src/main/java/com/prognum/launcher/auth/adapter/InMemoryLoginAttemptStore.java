package com.prognum.launcher.auth.adapter;

import com.prognum.launcher.auth.port.LoginAttemptStore;
import org.springframework.stereotype.Component;

import java.util.concurrent.ConcurrentHashMap;

/** Contador in-memory de tentativas erradas. Depois: Redis (distribuido/persistente). */
@Component
public class InMemoryLoginAttemptStore implements LoginAttemptStore {

    private final ConcurrentHashMap<String, Integer> contador = new ConcurrentHashMap<>();

    @Override
    public int registerFailure(String usuario) {
        return contador.merge(key(usuario), 1, Integer::sum);
    }

    @Override
    public int get(String usuario) {
        return contador.getOrDefault(key(usuario), 0);
    }

    @Override
    public void reset(String usuario) {
        contador.remove(key(usuario));
    }

    private String key(String usuario) {
        return usuario == null ? "" : usuario.trim().toLowerCase();
    }
}
