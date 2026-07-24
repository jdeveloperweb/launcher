package com.prognum.gateway.autenticacao.redis;

import com.prognum.gateway.autenticacao.model.Sessao;
import com.prognum.gateway.autenticacao.port.out.RepositorioSessao;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Optional;

/**
 * Adapter de saida: sessao no REDIS (cache distribuido, com TTL) — substitui o ConcurrentHashMap
 * do legado. Chave "sess:&lt;sessionKey&gt;", valor "usuarioambiente". A SCCI_SESSION
 * (VALIDA) continua autoritativa; o Redis e o caminho rapido e compartilhado entre instancias.
 *
 * Doc Final de Requisitos (Autenticacao/Sessao): timeout de sessao parametrizavel, com default
 * igual ao comportamento atual -- sessao SEM expiracao. ttl-segundos&lt;=0 (default) = sem TTL
 * (chave permanece no Redis ate logout explicito); um valor positivo (ex.: 1800 = 30 min) liga a
 * expiracao/renovacao por inatividade.
 */
@Component
public class RedisRepositorioSessao implements RepositorioSessao {

    private static final String PREFIXO = "sess:";
    private static final String SEP = "";   // separador de controle (nao aparece em login/path)

    private final StringRedisTemplate redis;
    private final boolean semExpiracao;
    private final Duration ttl;

    public RedisRepositorioSessao(StringRedisTemplate redis,
                                  @Value("${launcher.sessao.ttl-segundos:0}") long ttlSegundos) {
        this.redis = redis;
        this.semExpiracao = ttlSegundos <= 0;
        this.ttl = semExpiracao ? null : Duration.ofSeconds(ttlSegundos);
    }

    @Override
    public void salvar(String sessionKey, Sessao sessao) {
        if (sessionKey == null) {
            return;
        }
        String valor = nvl(sessao.usuario()) + SEP + nvl(sessao.ambienteOperacional());
        if (semExpiracao) {
            redis.opsForValue().set(PREFIXO + sessionKey, valor);
        } else {
            redis.opsForValue().set(PREFIXO + sessionKey, valor, ttl);
        }
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
        if (!semExpiracao) {
            redis.expire(PREFIXO + sessionKey, ttl);   // renova o TTL (sessao "viva")
        }
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
