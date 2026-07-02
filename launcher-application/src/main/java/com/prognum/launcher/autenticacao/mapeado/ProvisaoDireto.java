package com.prognum.launcher.autenticacao.mapeado;

import java.util.Optional;

import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;

/**
 * Porte fiel do logindireto.pas (ExecutaLoginDireto). O IdP já autenticou; o USUARIO vem como e-mail.
 * Só valida que o usuário existe (não provisiona, não mexe em perfil) e devolve a grafia real. Sem
 * '@' no usuário o legado responde 'F' — aqui vira exceção (o AutenticadorMapeado converte em 'F').
 */
public class ProvisaoDireto implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_DIRETO";

    private final ProvisionamentoUsuario repo;

    public ProvisaoDireto(ProvisionamentoUsuario repo) {
        this.repo = repo;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    @Override
    public DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String token) {
        if (usuario == null || usuario.indexOf('@') < 0) {
            throw new IllegalArgumentException("Usuario invalido para este acesso.");   // legado: 'F'
        }
        String semDominio = usuario.substring(0, usuario.indexOf('@'));
        Optional<UsuarioScci> u = repo.buscarPorUsuario(semDominio, ambiente);
        if (u.isEmpty()) {
            throw new IllegalStateException("Usuario nao cadastrado no SCCI.");
        }
        return new DadosProvisao(u.get().usuario(), token);
    }
}
