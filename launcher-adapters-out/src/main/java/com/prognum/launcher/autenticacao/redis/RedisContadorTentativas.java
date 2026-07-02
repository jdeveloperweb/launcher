package com.prognum.launcher.autenticacao.redis;

import com.prognum.launcher.autenticacao.port.out.ContadorTentativas;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * Adapter de saida: contador de tentativas erradas no REDIS (distribuido, com TTL de auto-reset) —
 * substitui o ConcurrentHashMap do legado. Chave "att:&lt;usuario&gt;". INCR conta a falha; o TTL
 * faz o bloqueio/captcha "esfriar" sozinho apos a janela.
 */
@Component
public class RedisContadorTentativas implements ContadorTentativas {

    private static final String PREFIXO = "att:";

    private final StringRedisTemplate redis;
    private final Duration ttl;

    public RedisContadorTentativas(StringRedisTemplate redis,
                                   @Value("${launcher.auth.tentativas-ttl-segundos:900}") long ttlSegundos) {
        this.redis = redis;
        this.ttl = Duration.ofSeconds(ttlSegundos);
    }

    @Override
    public int registerFailure(String usuario) {
        String chave = PREFIXO + nvl(usuario);
        Long n = redis.opsForValue().increment(chave);
        redis.expire(chave, ttl);   // (re)arma a janela a cada falha
        return n == null ? 0 : n.intValue();
    }

    @Override
    public int get(String usuario) {
        String v = redis.opsForValue().get(PREFIXO + nvl(usuario));
        return v == null ? 0 : Integer.parseInt(v);
    }

    @Override
    public void reset(String usuario) {
        redis.delete(PREFIXO + nvl(usuario));
    }

    private static String nvl(String s) {
        return s == null ? "" : s;
    }
}
