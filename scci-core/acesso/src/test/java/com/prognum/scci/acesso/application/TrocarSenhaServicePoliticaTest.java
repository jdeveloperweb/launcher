package com.prognum.scci.acesso.application;

import com.prognum.scci.acesso.domain.model.HistoricoSenhas;
import com.prognum.scci.acesso.domain.model.ResultadoTroca;
import com.prognum.scci.acesso.domain.policy.PasswordPolicy;
import com.prognum.scci.acesso.domain.port.out.PoliticaSenhaResolver;
import com.prognum.scci.acesso.domain.port.out.SenhaRepository;
import com.prognum.scci.acesso.domain.port.out.VerificadorSenha;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Politica de senha POR AMBIENTE — o {@link TrocarSenhaService} resolve a politica pelo ambiente
 * (do launcherenv.ini). Prova: cliente SEM chaves de politica aceita uma senha simples (nao mais
 * rigido que o legado); cliente COM politica rejeita a mesma senha — so trocando o ambiente.
 */
class TrocarSenhaServicePoliticaTest {

    static class RepoFake implements SenhaRepository {
        String gravado;
        public Optional<HistoricoSenhas> ler(String u, String a) { return Optional.of(new HistoricoSenhas("H:atual", List.of())); }
        public void gravar(String u, String a, String hash) { this.gravado = hash; }
    }
    static final VerificadorSenha VERIF = new VerificadorSenha() {
        public boolean matches(String senha, String hash) { return ("H:" + senha).equals(hash); }
        public String gerarHashMd5Crypt(String senha) { return "$1$" + senha; }
    };
    static final PasswordPolicy PERMISSIVA = new PasswordPolicy(0, false, 0, 0, 0, 0, 0, 0);
    static final PasswordPolicy EXIGENTE = new PasswordPolicy(8, true, 1, 1, 1, 1, 3, 3);

    @Test
    void clienteSemPoliticaNoIni_aceitaSenhaSimples() {
        RepoFake repo = new RepoFake();
        PoliticaSenhaResolver permissiva = ambiente -> PERMISSIVA;
        ResultadoTroca r = new TrocarSenhaService(repo, VERIF, permissiva).trocar("joao", "atual", "abc", "/sem-politica");
        assertTrue(r.sucesso(), "sem chaves no .ini -> senha simples aceita: " + r.mensagem());
        assertEquals("$1$abc", repo.gravado);
    }

    @Test
    void clienteComPoliticaNoIni_rejeitaMesmaSenhaSimples() {
        RepoFake repo = new RepoFake();
        PoliticaSenhaResolver exigente = ambiente -> EXIGENTE;
        ResultadoTroca r = new TrocarSenhaService(repo, VERIF, exigente).trocar("joao", "atual", "abc", "/com-politica");
        assertFalse(r.sucesso(), "com politica exigente -> senha simples rejeitada");
        assertNull(repo.gravado, "nao grava quando a politica reprova");
    }

    @Test
    void politicaResolvidaPeloAmbiente() {
        PoliticaSenhaResolver porAmbiente = ambiente -> "/rigido".equals(ambiente) ? EXIGENTE : PERMISSIVA;
        assertTrue(new TrocarSenhaService(new RepoFake(), VERIF, porAmbiente).trocar("j", "atual", "abc", "/leniente").sucesso());
        assertFalse(new TrocarSenhaService(new RepoFake(), VERIF, porAmbiente).trocar("j", "atual", "abc", "/rigido").sucesso());
    }
}
