package com.prognum.scci.acesso.application;

import com.prognum.scci.acesso.domain.model.CredenciaisUsuario;
import com.prognum.scci.acesso.domain.model.ResultadoLogin;
import com.prognum.scci.acesso.domain.port.out.Autenticador;
import com.prognum.scci.acesso.domain.port.out.CredenciaisRepository;
import com.prognum.scci.acesso.domain.port.out.VerificadorSenha;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

/**
 * Autenticação BANCO — o login padrão do SCCI (loginbd.pas: TestaUsuario/ExecutaLoginBD): senha
 * md5crypt na base do ambiente + estados da conta. Verifica a credencial e devolve o código de
 * estado (F/E/M/C/T); NÃO conta tentativa, NÃO emite sessionKey (isso é do coordenador LoginService).
 * SOMENTE LEITURA (não altera o banco). POJO puro.
 */
public class AutenticadorBanco implements Autenticador {

    public static final String METODO = "BANCO";

    private final CredenciaisRepository repo;
    private final VerificadorSenha passwords;
    private final int diasAviso;

    public AutenticadorBanco(CredenciaisRepository repo, VerificadorSenha passwords, int diasAviso) {
        this.repo = repo;
        this.passwords = passwords;
        this.diasAviso = diasAviso;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    @Override
    public ResultadoLogin autenticar(String usuario, String senha, String ambiente, String ip) {
        Optional<CredenciaisUsuario> ou = repo.buscar(usuario, ambiente);
        if (ou.isEmpty()) {
            return falha();   // inexistente responde igual a senha errada (RN-031)
        }
        CredenciaisUsuario u = ou.get();
        boolean senhaBranca = u.senhaHash() == null || u.senhaHash().isBlank();
        if (senhaBranca || !passwords.matches(senha, u.senhaHash())) {
            return falha();
        }

        // conta inativa (USERACTIVE do loginbd.pas): senha bateu, mas a conta esta desativada -> bloqueia
        // antes de qualquer estado de senha (nao faz sentido pedir troca a um usuario inativo)
        if (!u.ativo()) {
            return new ResultadoLogin(false, 'I', null, "Usuario inativo. Procure o administrador.", null);
        }

        // credencial OK -> estados (TestaUsuario do loginbd.pas)
        LocalDate hoje = LocalDate.now();
        if (u.dtValidade() != null && u.dtValidade().isBefore(hoje)) {
            return new ResultadoLogin(false, 'E', null, "Conta expirada.", null);
        }
        if (u.maxDias() != null && u.maxDias() > 0 && u.ultimaTroca() != null
                && hoje.isAfter(u.ultimaTroca().plusDays(u.maxDias()))) {
            return new ResultadoLogin(false, 'M', null, "Sua senha deve ser trocada.", null);
        }
        String mc = u.mustChange() == null ? "" : u.mustChange().trim().toUpperCase();
        if (mc.equals("T") || mc.equals("V")) {
            return new ResultadoLogin(false, 'M', null, "Sua senha deve ser trocada no proximo login.", null);
        }

        // aviso de expiração próxima (C) — senão, ok (T)
        if (u.minDias() != null && u.minDias() > 0 && u.ultimaTroca() != null
                && hoje.isAfter(u.ultimaTroca().plusDays(u.minDias()))) {
            int base = (u.maxDias() != null && u.maxDias() > 0) ? u.maxDias() : u.minDias();
            long faltam = ChronoUnit.DAYS.between(hoje, u.ultimaTroca().plusDays(base));
            if (faltam >= 0 && faltam <= diasAviso) {
                return new ResultadoLogin(true, 'C', null, "Senha expira em breve.", (int) faltam);
            }
        }
        return new ResultadoLogin(true, 'T', null, "OK", null);
    }

    private static ResultadoLogin falha() {
        return new ResultadoLogin(false, 'F', null, "Usuario ou senha invalidos.", null);
    }
}
