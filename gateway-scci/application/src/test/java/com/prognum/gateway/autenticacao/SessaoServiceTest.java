package com.prognum.gateway.autenticacao;

import com.prognum.gateway.autenticacao.model.Sessao;
import com.prognum.gateway.autenticacao.port.out.RepositorioSessao;
import com.prognum.gateway.autenticacao.port.out.SegurancaIntegracao;
import com.prognum.gateway.autenticacao.port.out.SessaoPersistente;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/** Gestão de sessão + VALIDA (cache Redis + SCCI_SESSION), fiel ao launcher.pas. */
class SessaoServiceTest {

    private final RepositorioSessao cache = mock(RepositorioSessao.class);
    private final SessaoPersistente persistente = mock(SessaoPersistente.class);
    private final SegurancaIntegracao integracao = mock(SegurancaIntegracao.class);
    private final SessaoService svc = new SessaoService(cache, persistente, integracao);

    @Test
    void registrar_grava_nos_dois() {
        svc.registrar("KEY", "joao", "/amb", "1.2.3.4");
        verify(cache).salvar(eq("KEY"), eq(new Sessao("joao", "/amb")));
        verify(persistente).registrar("joao", "KEY", "1.2.3.4", "/amb");
    }

    @Test
    void registrar_sessionKey_null_nao_faz_nada() {
        svc.registrar(null, "joao", "/amb", "ip");
        verify(cache, never()).salvar(any(), any());
        verify(persistente, never()).registrar(any(), any(), any(), any());
    }

    @Test
    void validar_cache_hit_nao_toca_na_base() {
        when(cache.buscar("KEY")).thenReturn(Optional.of(new Sessao("joao", "/amb")));
        Optional<Sessao> r = svc.validar("KEY", "joao", "/amb");
        assertThat(r).isPresent();
        verify(persistente, never()).estaValida(any(), any(), any());
    }

    @Test
    void validar_cache_miss_revalida_na_scci_session_e_reidrata() {
        when(cache.buscar("KEY")).thenReturn(Optional.empty());
        when(persistente.estaValida("joao", "KEY", "/amb")).thenReturn(true);
        Optional<Sessao> r = svc.validar("KEY", "joao", "/amb");
        assertThat(r).contains(new Sessao("joao", "/amb"));
        verify(cache).salvar("KEY", new Sessao("joao", "/amb"));   // reidratou o cache
    }

    @Test
    void validar_miss_e_scci_invalida_retorna_vazio() {
        when(cache.buscar("KEY")).thenReturn(Optional.empty());
        when(persistente.estaValida(any(), any(), any())).thenReturn(false);
        assertThat(svc.validar("KEY", "joao", "/amb")).isEmpty();
    }

    @Test
    void validar_sessionKey_null_vazio() {
        assertThat(svc.validar(null, "joao", "/amb")).isEmpty();
    }

    // ---- conta de integracao (loginintegracao): validacao STATELESS contra SEG_IDENTIFICACAO ----

    @Test
    void integracao_sessionkey_bate_seg_identificacao_valida_sem_tocar_store() {
        when(integracao.identificacao("/cdhu-ht/api")).thenReturn("DXJKLDEOSX");
        Optional<Sessao> r = svc.validar("DXJKLDEOSX", "loginintegracao", "/cdhu-ht/api");
        assertThat(r).contains(new Sessao("loginintegracao", "/cdhu-ht/api"));
        verify(cache, never()).buscar(any());                         // stateless: nem olha o cache
        verify(persistente, never()).estaValida(any(), any(), any()); // nem a SCCI_SESSION
    }

    @Test
    void integracao_sessionkey_errada_vazio() {
        when(integracao.identificacao("/cdhu-ht/api")).thenReturn("DXJKLDEOSX");
        assertThat(svc.validar("CHAVE_ERRADA", "loginintegracao", "/cdhu-ht/api")).isEmpty();
    }

    @Test
    void integracao_ambiente_sem_seg_identificacao_vazio() {
        when(integracao.identificacao(any())).thenReturn(null);   // ambiente sem SEG_IDENTIFICACAO
        assertThat(svc.validar("qualquer", "loginintegracao", "/cdhu-ht/api")).isEmpty();
    }

    @Test
    void encerrar_remove_do_cache_e_da_base() {
        when(cache.buscar("KEY")).thenReturn(Optional.of(new Sessao("joao", "/amb")));
        svc.encerrar("KEY");
        verify(persistente).encerrar("joao", "KEY", "/amb");
        verify(cache).remover("KEY");
    }

    @Test
    void contarSessoesAtivas_delega() {
        when(persistente.contarAtivas("joao", "/amb")).thenReturn(3);
        assertThat(svc.contarSessoesAtivas("joao", "/amb")).isEqualTo(3);
        assertThat(svc.contarSessoesAtivas(null, "/amb")).isZero();
    }
}
