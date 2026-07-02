package com.prognum.launcher.autenticacao.mapeado;

import com.prognum.launcher.autenticacao.mapeado.NovoUsuario;
import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;
import com.prognum.launcher.compartilhado.crypto.WcopCrypto;

/**
 * Porte fiel do loginitau.pas (ExecutaLoginItau). O payload decifrado é {@code !#___}+nome-do-perfil
 * (GRUPO). Valida o perfil (por NOME, exato), resolve a entidade default e o setor, e então provisiona
 * o USUARIO: UPDATE se já existe, INSERT caso contrário. Não corrige a grafia (usa o usuário informado).
 */
public class ProvisaoItau implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_ITAU";

    private final ProvisionamentoUsuario repo;

    public ProvisaoItau(ProvisionamentoUsuario repo) {
        this.repo = repo;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    @Override
    public DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String token) {
        String st = WcopCrypto.webDeCrypt(segredo);
        if (!st.startsWith(PayloadMapeado.PREFIXO)) {
            throw new IllegalStateException("Senha incorreta");
        }
        String perfil = st.substring(PayloadMapeado.PREFIXO.length());

        Integer cod = repo.perfilPorNome(perfil, true, ambiente).orElse(null);   // itau: match EXATO
        if (cod == null) {
            throw new IllegalStateException("Perfil do usuario inexistente");
        }
        int ent = repo.entidadeDefaultOuMenos1(ambiente);
        String setor = repo.obterSetor(cod, ent, ambiente);

        if (repo.buscarPorUsuarioOuEmail(usuario, ambiente).isPresent()) {
            repo.atualizarProvisao(usuario, cod, ent, setor, usuario, ambiente);
        } else {
            repo.inserir(new NovoUsuario(usuario, cod, ent, null, setor, usuario, token, null), ambiente);
        }
        return new DadosProvisao(null, token);   // itau não corrige a grafia (usa o usuário informado)
    }
}
