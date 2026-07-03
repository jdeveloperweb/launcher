package com.prognum.scci.acesso.aplicacao.mapeado;

import java.util.Objects;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.prognum.scci.acesso.dominio.mapeado.DadosProvisao;
import com.prognum.scci.acesso.dominio.mapeado.NovoUsuario;
import com.prognum.scci.acesso.dominio.mapeado.PayloadMapeado;
import com.prognum.scci.acesso.dominio.mapeado.UsuarioScci;
import com.prognum.scci.acesso.dominio.port.out.ProvisionamentoUsuario;
import com.prognum.comum.cripto.WcopCrypto;

/**
 * Porte fiel do loginc6.pas (ExecutaLoginC6). Autenticação OpenID já feita; payload traz o PERFIL.
 * Valida o perfil, e então:
 * <ul>
 *   <li>se o usuário existe: atualiza PERF_PRIMARIO e/ou NO_AUTENTICACAO_AD quando mudaram (com log);</li>
 *   <li>se não existe: provisiona (INSERT) resolvendo entidade default e setor.</li>
 * </ul>
 * Login case-insensitive: devolve a grafia real. O e-mail AD é o USUARIO original (antes de tirar o domínio).
 */
public class ProvisaoC6 implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_C6";

    private static final Logger log = LoggerFactory.getLogger(ProvisaoC6.class);

    private final ProvisionamentoUsuario repo;

    public ProvisaoC6(ProvisionamentoUsuario repo) {
        this.repo = repo;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    @Override
    public DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String token) {
        PayloadMapeado p = PayloadMapeado.deXml(WcopCrypto.webDeCrypt(segredo));

        Integer cod = repo.perfilPorNome(p.perfil(), false, ambiente).orElse(null);
        if (cod == null) {
            throw new IllegalStateException("Usuario nao possui acesso ao SCCI.");
        }

        String emailAd = usuario == null ? "" : usuario;
        String login = usuario;
        if (login != null && login.indexOf('@') >= 0) {
            login = login.substring(0, login.indexOf('@'));
        }

        Optional<UsuarioScci> ou = repo.buscarPorUsuario(login, ambiente);
        if (ou.isPresent()) {
            UsuarioScci u = ou.get();
            if (u.perfPrimario() == null || u.perfPrimario().intValue() != cod) {
                repo.atualizarPerfil(u.usuario(), cod, ambiente);
                log.info("provisao_c6_perfil_atualizado usuario={} novo={}", u.usuario(), p.perfil());
            }
            if (!Objects.equals(emailAd, u.noAutenticacaoAd() == null ? "" : u.noAutenticacaoAd())) {
                repo.atualizarEmailAd(u.usuario(), emailAd, ambiente);
                log.info("provisao_c6_emailad_atualizado usuario={}", u.usuario());
            }
            return new DadosProvisao(u.usuario(), token);
        }

        // não existe -> provisiona
        int codEnt = repo.entidadeDefault(ambiente);
        String setor = repo.obterSetor(cod, codEnt, ambiente);
        // loginc6 NÃO grava SENHA no INSERT (senhaToken=null); grava sim o NO_AUTENTICACAO_AD
        repo.inserir(new NovoUsuario(login, cod, codEnt, null, setor, login, null, emailAd), ambiente);
        log.info("provisao_c6_usuario_criado usuario={} perfil={} entidade={}", login, p.perfil(), codEnt);
        return new DadosProvisao(login, token);
    }
}
