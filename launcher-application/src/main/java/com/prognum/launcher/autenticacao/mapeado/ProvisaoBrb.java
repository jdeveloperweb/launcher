package com.prognum.launcher.autenticacao.mapeado;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;
import com.prognum.launcher.compartilhado.crypto.WcopCrypto;

/**
 * Porte fiel do loginbrb.pas (ExecutaLoginBrb). Autenticação OpenID já feita; o payload cifrado traz o
 * PERFIL. O usuário TEM que existir no SCCI (senão erro); se o perfil vindo do IdP mudou, atualiza o
 * PERF_PRIMARIO (com log). Login case-insensitive: devolve a grafia real da base.
 */
public class ProvisaoBrb implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_BRB";

    private static final Logger log = LoggerFactory.getLogger(ProvisaoBrb.class);

    private final ProvisionamentoUsuario repo;

    public ProvisaoBrb(ProvisionamentoUsuario repo) {
        this.repo = repo;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    @Override
    public DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String token) {
        PayloadMapeado p = PayloadMapeado.deXml(WcopCrypto.webDeCrypt(segredo));

        Optional<UsuarioScci> ou = repo.buscarPorUsuario(usuario, ambiente);
        if (ou.isEmpty()) {
            throw new IllegalStateException("Usuario nao cadastrado no SCCI.");
        }
        UsuarioScci u = ou.get();

        Integer cod = repo.perfilPorNome(p.perfil(), false, ambiente).orElse(null);
        if (cod == null) {
            throw new IllegalStateException("Usuario nao possui acesso ao SCCI.");
        }
        if (u.perfPrimario() == null || u.perfPrimario().intValue() != cod) {
            repo.atualizarPerfil(u.usuario(), cod, ambiente);
            log.info("provisao_brb_perfil_atualizado usuario={} de={} para={}", u.usuario(), u.nomePerfil(), p.perfil());
        }
        return new DadosProvisao(u.usuario(), token);
    }
}
