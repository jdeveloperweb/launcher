package com.prognum.launcher.autenticacao.mapeado;

import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;
import com.prognum.comum.cripto.WcopCrypto;

/**
 * Porte fiel do loginunicred.pas (ExecutaLoginUnicred + ParseParametros). O payload CommaText traz
 * {@code jwt_id_identifier} (ex.: {@code nome.sobrenome.0060}) e {@code token_tag}. Extrai o usuário
 * (o identificador inteiro) e a entidade (bloco à direita do último '.'), critica a subordinação do
 * usuário à entidade e exige que o usuário já exista no SCCI (não provisiona). O usuário efetivo é o
 * identificador do JWT (vai para a sessão).
 */
public class ProvisaoUnicred implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_UNICRED";

    private final ProvisionamentoUsuario repo;

    public ProvisaoUnicred(ProvisionamentoUsuario repo) {
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
        PayloadMapeado p = PayloadMapeado.deCommaText(st);
        String entrada = p.valor("jwt_id_identifier");
        String usuarioEfetivo = entrada;                 // ParseParametros: Usuario := nome := entrada
        String entidade = entidadeDoIdentificador(entrada);

        if (usuarioEfetivo.length() > 20) {
            throw new IllegalStateException("Nome do usuario(" + usuarioEfetivo + ") maior que o maximo permitido");
        }
        if (!repo.usuarioSubordinadoAEntidade(usuarioEfetivo, entidade, ambiente)) {
            throw new IllegalStateException("Usuario nao subordinado a entidade informada");
        }
        if (repo.buscarPorUsuarioOuEmail(usuarioEfetivo, ambiente).isEmpty()) {
            throw new IllegalStateException(
                    "Usuario nao cadastrado no SCCI. Por favor entre em contato com o suporte para verificar o seu cadastro.");
        }
        return new DadosProvisao(usuarioEfetivo, token);
    }

    /** Bloco à direita do último '.' (a entidade). Se não houver '.', é a string inteira. */
    private static String entidadeDoIdentificador(String entrada) {
        int i = entrada.length() - 1;
        StringBuilder sb = new StringBuilder();
        while (i >= 0 && entrada.charAt(i) != '.') {
            sb.insert(0, entrada.charAt(i));
            i--;
        }
        return sb.toString();
    }
}
