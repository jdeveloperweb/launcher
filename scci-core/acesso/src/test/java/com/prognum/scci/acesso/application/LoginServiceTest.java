package com.prognum.scci.acesso.application;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.prognum.scci.acesso.domain.model.ResultadoLogin;
import com.prognum.scci.acesso.domain.port.out.Autenticador;
import com.prognum.scci.acesso.domain.port.out.ContadorTentativas;
import com.prognum.scci.acesso.domain.port.out.MetodoLoginResolver;
import com.prognum.scci.acesso.domain.port.out.VerificadorVersaoBanco;

/**
 * Trava o coordenador do login (comum a todos os clientes): sucesso emite sessionKey, credencial
 * inválida conta tentativa e escala para bloqueio. Fakes no lugar de Redis/DB.
 * (Doc Final de Requisitos: CAPTCHA removido — fora do escopo inicial.)
 */
class LoginServiceTest {

    /** Autenticador de teste: devolve o código fixo (F/T/...) sem tocar banco. */
    private static Autenticador banco(char cod) {
        return new Autenticador() {
            public String metodo() {
                return "BANCO";
            }
            public ResultadoLogin autenticar(String u, String s, String a, String ip) {
                return cod == 'T'
                        ? new ResultadoLogin(true, 'T', null, "OK", null)
                        : new ResultadoLogin(false, cod, null, "invalido", null);
            }
        };
    }

    /** ContadorTentativas em memória (o Redis real tem a mesma semântica). */
    private static class ContadorFake implements ContadorTentativas {
        final Map<String, Integer> m = new HashMap<>();
        public int registerFailure(String u) {
            return m.merge(u, 1, Integer::sum);
        }
        public int get(String u) {
            return m.getOrDefault(u, 0);
        }
        public void reset(String u) {
            m.remove(u);
        }
    }

    private final MetodoLoginResolver banco = a -> "BANCO";

    /** Verificador de versao do banco: por padrao LIBERA (Optional.empty), como um ambiente ok. */
    private static final VerificadorVersaoBanco VERSAO_OK = a -> Optional.empty();

    @Test
    void sucesso_emite_sessionkey() {
        LoginService svc = new LoginService(List.of(banco('T')), banco, new ContadorFake(), VERSAO_OK, 0, 5);
        ResultadoLogin r = svc.login("jose", "senha", "/amb", "1.2.3.4");
        assertThat(r.sucesso()).isTrue();
        assertThat(r.codErro()).isEqualTo('T');
        assertThat(r.sessionKey()).hasSize(29);
    }

    @Test
    void invalido_conta_tentativa_e_mantem_F() {
        ContadorFake c = new ContadorFake();
        LoginService svc = new LoginService(List.of(banco('F')), banco, c, VERSAO_OK, 0, 5);
        ResultadoLogin r = svc.login("jose", "errada", "/amb", "ip");
        assertThat(r.sucesso()).isFalse();
        assertThat(r.codErro()).isEqualTo('F');
        assertThat(c.get("jose")).isEqualTo(1);
    }

    @Test
    void escala_para_bloqueio_apos_max_erros() {
        ContadorFake c = new ContadorFake();
        LoginService svc = new LoginService(List.of(banco('F')), banco, c, VERSAO_OK, 0, 5);
        char ultimo = 'F';
        for (int i = 0; i < 6; i++) {                 // 6 falhas: passa de maxErros(5) -> X
            ultimo = svc.login("jose", "x", "/amb", "ip").codErro();
        }
        assertThat(ultimo).isEqualTo('X');            // bloqueado
    }

    @Test
    void versao_banco_incompativel_nega_login_sem_sessao() {
        // credencial OK (T), mas VERIFICAVERSAOBANCO acusa incompatibilidade -> login negado ('V'),
        // com a mensagem do legado e SEM emitir sessionKey (fiel ao TestaVersaoBanco do wae.pas).
        VerificadorVersaoBanco incompat =
                a -> Optional.of("Versão do Banco de Dados incompatível com a versão do Sistema");
        LoginService svc = new LoginService(List.of(banco('T')), banco, new ContadorFake(), incompat, 0, 5);
        ResultadoLogin r = svc.login("jose", "senha", "/amb", "1.2.3.4");
        assertThat(r.sucesso()).isFalse();
        assertThat(r.codErro()).isEqualTo('V');
        assertThat(r.sessionKey()).isNull();
        assertThat(r.mensagem()).contains("incompatível");
    }
}
