package com.prognum.scci.sessao.aplicacao;

import com.prognum.scci.sessao.dominio.model.Sessao;
import com.prognum.scci.sessao.dominio.port.in.SessaoUseCase;
import com.prognum.scci.sessao.dominio.port.out.RepositorioSessao;
import com.prognum.scci.sessao.dominio.port.out.SessaoPersistente;

import java.util.Optional;

/**
 * Gestao da sessao. Combina o cache RAPIDO (Redis, {@link RepositorioSessao}) com o store
 * AUTORITATIVO (SCCI_SESSION, {@link SessaoPersistente}) — o VALIDA do launcher.pas:
 *  - registrar (login): grava nos dois;
 *  - validar (despacho /w): Redis primeiro; no miss, revalida na SCCI_SESSION (VerificaSessionKeyExpirada)
 *    e reidrata o cache; vazio = sessao invalida/expirada -> o edge rejeita antes de executar.
 * POJO puro.
 */
public class SessaoService implements SessaoUseCase {

    private final RepositorioSessao cache;
    private final SessaoPersistente persistente;

    public SessaoService(RepositorioSessao cache, SessaoPersistente persistente) {
        this.cache = cache;
        this.persistente = persistente;
    }

    @Override
    public void registrar(String sessionKey, String usuario, String ambienteOperacional, String ip) {
        if (sessionKey == null) {
            return;
        }
        cache.salvar(sessionKey, new Sessao(usuario, ambienteOperacional));
        persistente.registrar(usuario, sessionKey, ip, ambienteOperacional);
    }

    @Override
    public Optional<Sessao> consultar(String sessionKey) {
        return sessionKey == null ? Optional.empty() : cache.buscar(sessionKey);
    }

    @Override
    public Optional<Sessao> validar(String sessionKey, String usuarioInformado, String ambienteInformado) {
        if (sessionKey == null) {
            return Optional.empty();
        }
        Optional<Sessao> emCache = cache.buscar(sessionKey);
        if (emCache.isPresent()) {
            return emCache;   // sessao viva no cache = valida (TTL renovado no buscar)
        }
        // miss: VALIDA na base autoritativa (SCCI_SESSION) com o usuario informado no request
        if (usuarioInformado != null
                && persistente.estaValida(usuarioInformado, sessionKey, ambienteInformado)) {
            Sessao s = new Sessao(usuarioInformado, ambienteInformado);
            cache.salvar(sessionKey, s);   // reidrata o cache
            return Optional.of(s);
        }
        return Optional.empty();
    }

    @Override
    public void encerrar(String sessionKey) {
        if (sessionKey == null) {
            return;
        }
        cache.buscar(sessionKey).ifPresent(s ->
                persistente.encerrar(s.usuario(), sessionKey, s.ambienteOperacional()));
        cache.remover(sessionKey);
    }

    @Override
    public int contarSessoesAtivas(String usuario, String ambiente) {
        if (usuario == null) {
            return 0;
        }
        return persistente.contarAtivas(usuario, ambiente);
    }
}
