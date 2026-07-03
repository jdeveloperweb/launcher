package com.prognum.scci.sessao.aplicacao;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.api.Test;

import com.prognum.scci.sessao.dominio.model.Sessao;
import com.prognum.scci.sessao.dominio.port.out.RepositorioSessao;
import com.prognum.scci.sessao.dominio.port.out.SessaoPersistente;

/**
 * Trava o VALIDA (launcher.pas): cache (Redis) primeiro; no miss revalida na SCCI_SESSION e reidrata;
 * registrar grava nos dois; encerrar limpa. Fakes no lugar de Redis/DB.
 */
class SessaoServiceTest {

    private final Map<String, Sessao> cacheMap = new HashMap<>();
    private final Set<String> db = new HashSet<>();   // "usuario|key" presentes na SCCI_SESSION

    private final RepositorioSessao cache = new RepositorioSessao() {
        public void salvar(String k, Sessao s) {
            cacheMap.put(k, s);
        }
        public Optional<Sessao> buscar(String k) {
            return Optional.ofNullable(cacheMap.get(k));
        }
        public void remover(String k) {
            cacheMap.remove(k);
        }
    };

    private final SessaoPersistente persist = new SessaoPersistente() {
        public void registrar(String u, String k, String ip, String amb) {
            db.add(u + "|" + k);
        }
        public boolean estaValida(String u, String k, String amb) {
            return db.contains(u + "|" + k);
        }
        public void encerrar(String u, String k, String amb) {
            db.remove(u + "|" + k);
        }
        public int contarAtivas(String u, String amb) {
            return (int) db.stream().filter(e -> e.startsWith(u + "|")).count();
        }
    };

    private final SessaoService svc = new SessaoService(cache, persist);

    @Test
    void registrar_grava_nos_dois_e_valida_pelo_cache() {
        svc.registrar("K1", "jose", "/amb", "1.2.3.4");
        assertThat(cacheMap).containsKey("K1");
        assertThat(db).contains("jose|K1");
        assertThat(svc.validar("K1", "jose", "/amb")).isPresent();
    }

    @Test
    void miss_de_cache_revalida_na_scci_session_e_reidrata() {
        db.add("maria|K2");                 // existe so na base autoritativa (cache vazio)
        assertThat(cacheMap).doesNotContainKey("K2");
        Optional<Sessao> s = svc.validar("K2", "maria", "/amb");
        assertThat(s).isPresent();
        assertThat(cacheMap).containsKey("K2");   // reidratou o cache
    }

    @Test
    void invalida_quando_nao_esta_em_lugar_nenhum() {
        assertThat(svc.validar("K3", "ninguem", "/amb")).isEmpty();
    }

    @Test
    void encerrar_remove_dos_dois() {
        svc.registrar("K4", "jose", "/amb", "ip");
        svc.encerrar("K4");
        assertThat(cacheMap).doesNotContainKey("K4");
        assertThat(db).doesNotContain("jose|K4");
    }
}
