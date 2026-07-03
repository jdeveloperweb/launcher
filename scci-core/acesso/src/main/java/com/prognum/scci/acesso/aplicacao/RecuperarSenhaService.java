package com.prognum.scci.acesso.aplicacao;

import com.prognum.scci.acesso.dominio.model.DadosRecuperacao;
import com.prognum.scci.acesso.dominio.model.ResultadoTroca;
import com.prognum.scci.acesso.dominio.port.in.RecuperarSenhaUseCase;
import com.prognum.scci.acesso.dominio.port.out.RecuperacaoSenhaRepository;
import com.prognum.scci.acesso.dominio.port.out.VerificadorSenha;
import com.prognum.scci.notificacao.dominio.model.Email;
import com.prognum.scci.notificacao.dominio.port.Notificador;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.security.SecureRandom;
import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Recuperacao de senha por e-mail ("esqueci a senha"), porte FIEL do ExecutaEmailPwd do loginbd.pas:
 *  1. bloqueia supervisor e CPF 111...11;
 *  2. confere que o CPF informado bate com o cadastrado no usuario;
 *  3. exige e-mail + SMTP cadastrados na entidade;
 *  4. gera senha TEMPORARIA (CPF[0:5] + aleatorio), grava (md5crypt) forcando troca no proximo login;
 *  5. envia a nova senha por e-mail via o contexto NOTIFICACAO ({@link Notificador}) — reaproveitavel.
 */
public class RecuperarSenhaService implements RecuperarSenhaUseCase {

    private static final Logger log = LoggerFactory.getLogger(RecuperarSenhaService.class);

    private final RecuperacaoSenhaRepository repo;
    private final VerificadorSenha passwords;
    private final Notificador notificador;
    private final SecureRandom rnd = new SecureRandom();

    public RecuperarSenhaService(RecuperacaoSenhaRepository repo, VerificadorSenha passwords,
                                 Notificador notificador) {
        this.repo = repo;
        this.passwords = passwords;
        this.notificador = notificador;
    }

    @Override
    public ResultadoTroca recuperar(String usuario, String cpf, String ambiente) {
        usuario = usuario == null ? "" : usuario.trim();
        String cpfDig = soDigitos(cpf);

        // 1) supervisor e CPF 111...11 sao bloqueados (sol.74694)
        if (usuario.equalsIgnoreCase("supervisor") || cpfDig.equals("11111111111")) {
            return new ResultadoTroca(false,
                    "Usuario invalido ou sem e-mail cadastrado. Procure o administrador do sistema!");
        }
        if (usuario.isBlank() || cpfDig.length() != 11) {
            return new ResultadoTroca(false, "CPF ou usuario incorreto.");
        }

        Optional<DadosRecuperacao> od = repo.buscar(usuario, ambiente);
        if (od.isEmpty() || !soDigitos(od.get().cpf()).equals(cpfDig)) {
            return new ResultadoTroca(false, "CPF ou usuario incorreto.");
        }
        DadosRecuperacao d = od.get();
        if (isBlank(d.email()) || isBlank(d.smtpHost())) {
            return new ResultadoTroca(false, "E-mail ou SMTP nao cadastrados. Procure o administrador do sistema!");
        }

        // 4) senha temporaria = CPF[0:5] + aleatorio(0..9999)
        String novaSenha = cpfDig.substring(0, 5) + rnd.nextInt(10000);
        String novoHash = passwords.gerarHashMd5Crypt(novaSenha);
        repo.gravarSenhaTemporaria(usuario, ambiente, novoHash);

        // 5) envia por e-mail (fora da regra: quem entrega e o contexto notificacao)
        String assunto = "Recuperacao de senha - SCCI";
        String corpo = "Sua nova senha temporaria e: " + novaSenha
                + "\n\nEla devera ser trocada no proximo acesso.";
        try {
            notificador.enviarEmail(new Email(d.smtpHost(), d.smtpUsuario(), d.smtpSenha(),
                    d.email(), assunto, corpo));
        } catch (RuntimeException e) {
            log.warn("email_pwd_falha_envio", kv("usuario", usuario), kv("erro", String.valueOf(e.getMessage())));
            return new ResultadoTroca(false, "Nao foi possivel enviar o e-mail. Tente novamente mais tarde.");
        }
        log.info("email_pwd", kv("usuario", usuario), kv("ambiente", ambiente));
        return new ResultadoTroca(true, "Uma nova senha foi enviada para o seu e-mail cadastrado.");
    }

    private static String soDigitos(String s) {
        return s == null ? "" : s.replaceAll("\\D", "");
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }
}
