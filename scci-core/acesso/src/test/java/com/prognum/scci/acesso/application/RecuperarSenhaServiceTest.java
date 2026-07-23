package com.prognum.scci.acesso.application;

import com.prognum.scci.acesso.domain.model.DadosRecuperacao;
import com.prognum.scci.acesso.domain.model.ResultadoTroca;
import com.prognum.scci.acesso.domain.port.out.RecuperacaoSenhaRepository;
import com.prognum.scci.acesso.domain.port.out.VerificadorSenha;
import com.prognum.scci.notificacao.domain.model.Email;
import com.prognum.scci.notificacao.domain.port.Notificador;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * "Esqueci minha senha" — {@link RecuperarSenhaService} (porte do ExecutaEmailPwd do loginbd.pas).
 * Trava as regras: gera senha temporaria (CPF[0:5] + aleatorio), grava (md5crypt) FORCANDO troca no
 * proximo login e ENVIA por e-mail (SMTP da entidade); bloqueios (supervisor / CPF divergente /
 * sem e-mail-SMTP) NAO geram troca nem enviam.
 */
class RecuperarSenhaServiceTest {

    static class RepoFake implements RecuperacaoSenhaRepository {
        DadosRecuperacao dados;
        String senhaGravada;
        RepoFake(DadosRecuperacao d) { this.dados = d; }
        public Optional<DadosRecuperacao> buscar(String u, String a) { return Optional.ofNullable(dados); }
        public void gravarSenhaTemporaria(String u, String a, String hash) { this.senhaGravada = hash; }
    }
    static class VerFake implements VerificadorSenha {
        String senhaEmClaro;
        public boolean matches(String s, String h) { return false; }
        public String gerarHashMd5Crypt(String s) { this.senhaEmClaro = s; return "$1$fake$" + s; }
    }
    static class NotifFake implements Notificador {
        Email enviado;
        boolean falhar = false;
        public void enviarEmail(Email e) { if (falhar) throw new RuntimeException("smtp down"); this.enviado = e; }
    }

    private static RecuperarSenhaService svc(RepoFake r, VerFake v, NotifFake n) {
        return new RecuperarSenhaService(r, v, n);
    }
    private static DadosRecuperacao comEmail() {
        return new DadosRecuperacao("529.982.247-25", "user@cliente.com", "smtp.cliente.com", "smtpuser", "smtppass");
    }

    @Test
    void sucesso_geraSenhaTemporaria_gravaForcandoTroca_eEnviaEmail() {
        RepoFake repo = new RepoFake(comEmail());
        VerFake ver = new VerFake();
        NotifFake notif = new NotifFake();
        ResultadoTroca r = svc(repo, ver, notif).recuperar("joao", "52998224725", "/amb");
        assertTrue(r.sucesso(), r.mensagem());
        assertNotNull(repo.senhaGravada, "deve gravar a nova senha (hash)");
        assertTrue(repo.senhaGravada.startsWith("$1$"), "grava md5crypt");
        assertTrue(ver.senhaEmClaro.startsWith("52998"), "senha temporaria comeca com os 5 primeiros digitos do CPF");
        assertNotNull(notif.enviado, "deve enviar o e-mail");
        assertEquals("user@cliente.com", notif.enviado.para());
        assertEquals("smtp.cliente.com", notif.enviado.smtpHost(), "usa o SMTP da entidade (nao global)");
        assertTrue(notif.enviado.corpo().contains(ver.senhaEmClaro), "o e-mail leva a nova senha temporaria");
    }

    @Test
    void supervisor_bloqueado_naoGeraNemEnvia() {
        RepoFake repo = new RepoFake(comEmail());
        NotifFake notif = new NotifFake();
        ResultadoTroca r = svc(repo, new VerFake(), notif).recuperar("supervisor", "52998224725", "/amb");
        assertFalse(r.sucesso());
        assertNull(repo.senhaGravada);
        assertNull(notif.enviado);
    }

    @Test
    void cpfDivergenteDoCadastro_naoGeraNemEnvia() {
        RepoFake repo = new RepoFake(comEmail());
        NotifFake notif = new NotifFake();
        ResultadoTroca r = svc(repo, new VerFake(), notif).recuperar("joao", "11122233344", "/amb");
        assertFalse(r.sucesso());
        assertNull(repo.senhaGravada);
        assertNull(notif.enviado);
    }

    @Test
    void semEmailOuSmtpCadastrado_naoGera() {
        RepoFake repo = new RepoFake(new DadosRecuperacao("529.982.247-25", "", "", "", ""));
        NotifFake notif = new NotifFake();
        ResultadoTroca r = svc(repo, new VerFake(), notif).recuperar("joao", "52998224725", "/amb");
        assertFalse(r.sucesso());
        assertNull(repo.senhaGravada);
        assertNull(notif.enviado);
    }

    @Test
    void falhaNoEnvioDeEmail_reportaErro() {
        RepoFake repo = new RepoFake(comEmail());
        NotifFake notif = new NotifFake();
        notif.falhar = true;
        ResultadoTroca r = svc(repo, new VerFake(), notif).recuperar("joao", "52998224725", "/amb");
        assertFalse(r.sucesso(), "falha de SMTP deve reportar erro ao usuario");
    }
}
