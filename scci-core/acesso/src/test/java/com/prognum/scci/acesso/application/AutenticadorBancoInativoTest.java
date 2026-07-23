package com.prognum.scci.acesso.application;

import com.prognum.scci.acesso.domain.model.CredenciaisUsuario;
import com.prognum.scci.acesso.domain.model.ResultadoLogin;
import com.prognum.scci.acesso.domain.port.out.CredenciaisRepository;
import com.prognum.scci.acesso.domain.port.out.VerificadorSenha;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * USERACTIVE (inativacao) — o {@link AutenticadorBanco} bloqueia um usuario cuja conta esta
 * inativa MESMO com a senha correta (fiel ao TestaUsuario do loginbd.pas), com codigo 'I'. Conta
 * ativa com a mesma senha loga normalmente ('T'). A senha ja bateu, entao o bloqueio nao conta
 * tentativa nem pede troca — e um estado de conta, nao de credencial.
 */
class AutenticadorBancoInativoTest {

    /** VerificadorSenha trivial: hash == "H:" + senha. */
    private static final VerificadorSenha VERIF = new VerificadorSenha() {
        public boolean matches(String senha, String hash) { return ("H:" + senha).equals(hash); }
        public String gerarHashMd5Crypt(String senha) { return "$1$" + senha; }
    };

    private static AutenticadorBanco comUsuario(CredenciaisUsuario u) {
        CredenciaisRepository repo = (usuario, ambiente) -> Optional.of(u);
        return new AutenticadorBanco(repo, VERIF, 5);
    }

    private static CredenciaisUsuario usuario(boolean ativo) {
        return new CredenciaisUsuario("H:segredo", null, null, null, null, "F", ativo);
    }

    @Test
    void contaInativa_bloqueiaMesmoComSenhaCorreta() {
        ResultadoLogin r = comUsuario(usuario(false)).autenticar("joao", "segredo", "/amb", "1.2.3.4");
        assertFalse(r.sucesso(), "conta inativa nao deve logar");
        assertEquals('I', r.codErro(), "codigo de conta inativa e 'I'");
    }

    @Test
    void contaAtiva_logaNormalmente() {
        ResultadoLogin r = comUsuario(usuario(true)).autenticar("joao", "segredo", "/amb", "1.2.3.4");
        assertTrue(r.sucesso(), "conta ativa com senha correta deve logar: " + r.mensagem());
        assertEquals('T', r.codErro());
    }

    @Test
    void inativa_mas_senhaErrada_continuaSendoFalhaDeCredencial() {
        // senha errada tem precedencia: nem revela que a conta existe/esta inativa (RN-031)
        ResultadoLogin r = comUsuario(usuario(false)).autenticar("joao", "errada", "/amb", "1.2.3.4");
        assertFalse(r.sucesso());
        assertEquals('F', r.codErro(), "senha errada -> 'F' (nao revela inativacao)");
    }
}
