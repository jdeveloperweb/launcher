package com.prognum.launcher.autenticacao.redis;

import com.prognum.launcher.autenticacao.model.Sessao;
import com.prognum.launcher.autenticacao.port.out.RepositorioSessao;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Optional;

/**
 * Adapter de saida: sessao no REDIS (cache distribuido, com TTL) — substitui o ConcurrentHashMap
 * do legado. Chave "sess:&lt;sessionKey&gt;", valor "usuarioambiente". A SCCI_SESSION
 * (VALIDA) continua autoritativa; o Redis e o caminho rapido e compartilhado entre instancias.
 */
@Component
public class RedisRepositorioSessao implements RepositorioSessao {

    private static final String PREFIXO = "sess:";
    private static final String SEP = "";   // separador de controle (nao aparece em login/path)

    private final StringRedisTemplate redis;
    private final Duration ttl;

    public RedisRepositorioSessao(StringRedisTemplate redis,
                                  @Value("${launcher.sessao.ttl-segundos:1800}") long ttlSegundos) {
        this.redis = redis;
        this.ttl = Duration.ofSeconds(ttlSegundos);
    }

    @Override
    public void salvar(String sessionKey, Sessao sessao) {
        if (sessionKey == null) {
            return;
        }
        String valor = nvl(sessao.usuario()) + SEP + nvl(sessao.ambienteOperacional());
        redis.opsForValue().set(PREFIXO + sessionKey, valor, ttl);
    }

    @Override
    public Optional<Sessao> buscar(String sessionKey) {
        if (sessionKey == null) {
            return Optional.empty();
        }
        String valor = redis.opsForValue().get(PREFIXO + sessionKey);
        if (valor == null) {
            return Optional.empty();
        }
        String[] p = valor.split(SEP, -1);
        String usuario = p.length > 0 ? p[0] : "";
        String ambiente = p.length > 1 ? p[1] : "";
        redis.expire(PREFIXO + sessionKey, ttl);   // renova o TTL (sessao "viva")
        return Optional.of(new Sessao(usuario, ambiente));
    }

    @Override
    public void remover(String sessionKey) {
        if (sessionKey != null) {
            redis.delete(PREFIXO + sessionKey);
        }
    }

    private static String nvl(String s) {
        return s == null ? "" : s;
    }
}
