package com.prognum.scci.acesso.application.mapeado;

import java.util.Optional;

import com.prognum.scci.acesso.domain.mapeado.DadosProvisao;
import com.prognum.scci.acesso.domain.mapeado.PayloadMapeado;
import com.prognum.scci.acesso.domain.mapeado.UsuarioScci;
import com.prognum.scci.acesso.domain.port.out.ProvisionamentoUsuario;
import com.prognum.common.crypto.WcopCrypto;

/**
 * Porte fiel do logincashmeweb.pas (ExecutaLoginCashmeWeb). Dois ramos, decididos pelo formato do
 * USUARIO:
 * <ul>
 *   <li><b>e-mail</b> ('@'): igual ao brb — usuário deve existir, valida/atualiza perfil, devolve grafia real;</li>
 *   <li><b>CPF</b> (sem '@'): completa com zeros à esquerda (14), exige contrato em CADMUT e entra como
 *       {@code usuarioweb:} (login=F+cpf) — acesso "consulta por CPF" sem cadastro de USUARIO.</li>
 * </ul>
 * No ramo CPF o payload NÃO é decifrado (o legado só chama TrataParamsEntrada quando há '@').
 */
public class ProvisaoCashmeweb implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_CASHMEWEB";

    private final ProvisionamentoUsuario repo;

    public ProvisaoCashmeweb(ProvisionamentoUsuario repo) {
        this.repo = repo;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    @Override
    public DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String token) {
        if (usuario != null && usuario.indexOf('@') >= 0) {
            return ramoEmail(usuario, segredo, ambiente, token);
        }
        return ramoCpf(usuario, ambiente, token);
    }

    private DadosProvisao ramoEmail(String usuario, String segredo, String ambiente, String token) {
        PayloadMapeado p = PayloadMapeado.deXml(WcopCrypto.webDeCrypt(segredo));
        String semDominio = usuario.substring(0, usuario.indexOf('@'));

        Optional<UsuarioScci> ou = repo.buscarPorUsuario(semDominio, ambiente);
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
        }
        return new DadosProvisao(u.usuario(), token);
    }

    private DadosProvisao ramoCpf(String usuario, String ambiente, String token) {
        String cpf = LegadoStr.lpadZeros(usuario == null ? "" : usuario, 14);
        if (!repo.existeContratoCpf(cpf, ambiente)) {
            throw new IllegalStateException("Nao existem contratos para o CPF acessado.");
        }
        // legado: Usuario := 'usuarioweb:' (login = 'F'+cpf) -> sessão do modo consulta-por-CPF
        return new DadosProvisao("usuarioweb:", token);
    }
}
