package com.prognum.scci.acesso.aplicacao.mapeado;

import com.prognum.scci.acesso.dominio.mapeado.DadosProvisao;
import com.prognum.scci.acesso.dominio.mapeado.NovoUsuario;
import com.prognum.scci.acesso.dominio.mapeado.PayloadMapeado;
import com.prognum.scci.acesso.dominio.port.out.ProvisionamentoUsuario;
import com.prognum.comum.cripto.WcopCrypto;

/**
 * Porte fiel do loginailos.pas (ExecutaLoginAilos + ParseSenha). O payload CommaText traz atributos de
 * diretório (memberof, Givename, PhysicalDeliveryOfficeName). Deriva cooperativa/PA, resolve as
 * entidades via ENTIDADE_SCCI (CO_ENTIDADELOGIN), valida entidades (secundária, primária) e perfil (por
 * código) e provisiona (INSERT) só se o usuário ainda não existe. Não corrige a grafia.
 */
public class ProvisaoAilos implements EstrategiaProvisao {

    public static final String METODO = "MAPEADO_AILOS";

    private final ProvisionamentoUsuario repo;

    public ProvisaoAilos(ProvisionamentoUsuario repo) {
        this.repo = repo;
    }

    @Override
    public String metodo() {
        return METODO;
    }

    /** Resultado do ParseSenha (entidades como strings; "" = sem entidade). */
    private record Atributos(String entPrimaria, String entSecundaria, String perfil, String setor, String nome) {
    }

    private Atributos parse(String decifrado, String ambiente) {
        PayloadMapeado p = PayloadMapeado.deCommaText(decifrado);
        String memberof = p.valor("memberof");
        String nome = p.valor("Givename");
        String office = p.valor("PhysicalDeliveryOfficeName");

        String cooperativa = memberof.length() >= 4 ? memberof.substring(0, 4) : memberof;
        String setor = "1";
        String perfil = LegadoStr.rightStr(memberof, 3);
        String entPrimaria;
        String entSecundaria = "";

        if (office.length() >= 2 && office.substring(0, 2).equalsIgnoreCase("PA")) {
            String pa = LegadoStr.lpadZeros(office.substring(2).trim(), 5);
            entPrimaria = intstr(repo.entidadePorEntidadeLogin(LegadoStr.rightStr(cooperativa, 2) + pa, ambiente));
            entSecundaria = intstr(repo.entidadePorEntidadeLogin(LegadoStr.rightStr(cooperativa, 2) + "00000", ambiente));
        } else {
            entPrimaria = intstr(repo.entidadePorEntidadeLogin(LegadoStr.rightStr(cooperativa, 2) + "00000", ambiente));
        }
        if (entPrimaria.equals("-1")) {
            entPrimaria = "";
        }
        if (entSecundaria.equals("-1")) {
            entSecundaria = "";
        }
        return new Atributos(entPrimaria, entSecundaria, perfil, setor, nome);
    }

    @Override
    public DadosProvisao provisiona(String usuario, String segredo, String ambiente, String ip, String token) {
        String st = WcopCrypto.webDeCrypt(segredo);
        if (!st.startsWith(PayloadMapeado.PREFIXO)) {
            throw new IllegalStateException("Senha incorreta");
        }
        Atributos a = parse(st, ambiente);
        String nome = a.nome().isBlank() ? usuario : a.nome();

        // ValidaEntidade secundária -> primária (ordem e mensagens fiéis ao legado)
        int entSec = validaEntidade(a.entSecundaria(), "Entidade secundaria do usuario inexistente", ambiente);
        int entPrim = validaEntidade(a.entPrimaria(), "Entidade primaria do usuario inexistente", ambiente);

        int perfil = LegadoStr.valint(a.perfil());
        if (!repo.perfilExiste(perfil, ambiente)) {
            throw new IllegalStateException("Perfil do usuario inexistente");
        }

        if (repo.buscarPorUsuarioOuEmail(usuario, ambiente).isEmpty()) {
            Integer entSecCol = entSec > -1 ? entSec : null;   // legado: ENT_SECUNDARIA nula se -1
            repo.inserir(new NovoUsuario(usuario, perfil, entPrim, entSecCol, a.setor(), nome, token, null), ambiente);
        }
        return new DadosProvisao(null, token);
    }

    /** ValidaEntidade: "" => sem crítica (-1); senão a entidade tem que existir. Devolve o COD_ENT. */
    private int validaEntidade(String entidade, String msgErro, String ambiente) {
        if (entidade == null || entidade.isBlank()) {
            return -1;
        }
        int cod = LegadoStr.valint(entidade);
        if (!repo.entidadeExiste(cod, ambiente)) {
            throw new IllegalStateException(msgErro);
        }
        return cod;
    }

    /** intstr(-1) = "-1"; intstr(n) = "n" (o intstr do legado). */
    private static String intstr(int n) {
        return Integer.toString(n);
    }
}
