package com.prognum.scci.acesso.application;

import com.prognum.scci.acesso.domain.model.HistoricoSenhas;
import com.prognum.scci.acesso.domain.model.ResultadoTroca;
import com.prognum.scci.acesso.domain.policy.PasswordPolicy;
import com.prognum.scci.acesso.domain.port.in.TrocarSenhaUseCase;
import com.prognum.scci.acesso.domain.port.out.PoliticaSenhaResolver;
import com.prognum.scci.acesso.domain.port.out.SenhaRepository;
import com.prognum.scci.acesso.domain.port.out.VerificadorSenha;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Optional;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Troca de senha nativa (PASSWD do loginbd.pas / ExecutaPasswdBD), contra a base real do ambiente.
 * Porte FIEL do WcopPasswordService do launcher SCCI (legado). POJO puro (wiring no bootstrap):
 *  1. verifica a senha ATUAL (md5crypt);
 *  2. aplica a POLITICA de complexidade;
 *  3. checa o RODIZIO (nova != atual e != NO_SENHA1..5);
 *  4. GRAVA a nova (md5crypt $1$) rotacionando o historico.
 */
public class TrocarSenhaService implements TrocarSenhaUseCase {

    private static final Logger log = LoggerFactory.getLogger(TrocarSenhaService.class);

    private final SenhaRepository repo;
    private final VerificadorSenha passwords;
    private final PoliticaSenhaResolver politicas;

    public TrocarSenhaService(SenhaRepository repo, VerificadorSenha passwords, PoliticaSenhaResolver politicas) {
        this.repo = repo;
        this.passwords = passwords;
        this.politicas = politicas;
    }

    @Override
    public ResultadoTroca trocar(String usuario, String senhaAtual, String novaSenha, String ambiente) {
        usuario = usuario == null ? "" : usuario.trim();
        if (usuario.isBlank() || senhaAtual == null || novaSenha == null) {
            return new ResultadoTroca(false, "Dados incompletos para a troca de senha.");
        }

        Optional<HistoricoSenhas> os = repo.ler(usuario, ambiente);
        if (os.isEmpty()) {
            return new ResultadoTroca(false, "Usuario ou senha invalidos.");
        }
        HistoricoSenhas s = os.get();

        // 1) senha atual
        if (!passwords.matches(senhaAtual, s.atual())) {
            return new ResultadoTroca(false, "Senha atual incorreta.");
        }
        // 2) politica POR AMBIENTE (do launcherenv.ini; sem chaves = permissiva, igual ao legado)
        PasswordPolicy.Resultado pr = politicas.resolver(ambiente).validar(novaSenha);
        if (!pr.ok()) {
            return new ResultadoTroca(false, pr.mensagem());
        }
        // 3) rodizio (atual + NO_SENHA1..5)
        if (jaUsada(novaSenha, s)) {
            return new ResultadoTroca(false, "Esta senha ja foi usada anteriormente.");
        }
        // 4) grava (md5crypt $1$<salt6>$) rotacionando o historico
        String novoHash = passwords.gerarHashMd5Crypt(novaSenha);
        repo.gravar(usuario, ambiente, novoHash);
        log.info("web_passwd", kv("usuario", usuario), kv("ambiente", ambiente));
        return new ResultadoTroca(true, "Senha alterada com sucesso.");
    }

    /** Igual ao TestaSenhaRepetida: a nova nao pode bater com a atual nem com NO_SENHA1..5. */
    boolean jaUsada(String novaSenha, HistoricoSenhas s) {
        if (passwords.matches(novaSenha, s.atual())) {
            return true;
        }
        for (String h : s.anteriores()) {
            if (h != null && !h.isBlank() && passwords.matches(novaSenha, h)) {
                return true;
            }
        }
        return false;
    }
}
