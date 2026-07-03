package com.prognum.scci.sessao.adapters.out;

import com.prognum.scci.sessao.domain.model.Sessao;
import com.prognum.scci.sessao.domain.port.out.RepositorioSessao;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Optional;

/**
 * Adapter de saida: sessao no REDIS (cache distribuido, com TTL). <b>CONTRATO COMPARTILHADO</b> com o
 * launcher-edge (gate): os dois processos leem/escrevem o MESMO Redis, entao a chave e a serializacao
 * TEM que ser identicas nos dois lados. Chave {@code "sess:" + sessionKey}; valor
 * {@code usuario + SEP + ambiente}, onde {@code SEP} = char de controle SOH (U+0001), IGUAL ao byte
 * usado pelo RedisRepositorioSessao do launcher. Aqui montado via {@code (char) 1} (ASCII no fonte,
 * sem byte invisivel/escape ambiguo). NAO alterar sem alterar o gate do launcher junto.
 */
@Component
public class RedisRepositorioSessao implements RepositorioSessao {

    private static final String PREFIXO = "sess:";
    private static final String SEP = String.valueOf((char) 1);   // SOH (U+0001) — contrato do Redis compartilhado

    private final StringRedisTemplate redis;
    private final Duration ttl;

    public RedisRepositorioSessao(StringRedisTemplate redis,
                                  @Value("${scci.sessao.ttl-segundos:1800}") long ttlSegundos) {
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
