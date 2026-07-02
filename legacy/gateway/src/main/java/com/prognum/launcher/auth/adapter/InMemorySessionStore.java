package com.prognum.launcher.auth.adapter;

import com.prognum.launcher.auth.domain.Session;
import com.prognum.launcher.auth.port.SessionStore;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/** Store de sessao in-memory. Depois: Redis (adapter), mantendo esta interface. */
@Component
public class InMemorySessionStore implements SessionStore {

    private final ConcurrentHashMap<String, Session> porToken = new ConcurrentHashMap<>();

    @Override
    public String create(String usuario, String ambiente, String ip, long ttlSegundos) {
        Instant agora = Instant.now();
        String token = UUID.randomUUID().toString();
        porToken.put(token, new Session(token, usuario, ambiente, ip, agora, agora.plusSeconds(ttlSegundos)));
        return token;
    }

    @Override
    public Optional<Session> get(String token) {
        if (token == null) {
            return Optional.empty();
        }
        Session s = porToken.get(token);
        if (s == null) {
            return Optional.empty();
        }
        if (s.expiraEm().isBefore(Instant.now())) {   // expirada por inatividade/TTL
            porToken.remove(token);
            return Optional.empty();
        }
        return Optional.of(s);
    }

    @Override
    public void invalidate(String token) {
        if (token != null) {
            porToken.remove(token);
        }
    }

    @Override
    public void enforceLimit(String usuario, int maxPorUsuario) {
        if (usuario == null || maxPorUsuario <= 0) {
            return;
        }
        List<Session> doUsuario = porToken.values().stream()
                .filter(s -> usuario.equalsIgnoreCase(s.usuario()))
                .sorted(Comparator.comparing(Session::criadoEm))   // mais antigas primeiro
                .toList();
        // remove as mais antigas ate sobrar espaco para 1 nova (logout automatico ao novo login)
        int remover = doUsuario.size() - (maxPorUsuario - 1);
        for (int i = 0; i < remover && i < doUsuario.size(); i++) {
            porToken.remove(doUsuario.get(i).token());
        }
    }
}
