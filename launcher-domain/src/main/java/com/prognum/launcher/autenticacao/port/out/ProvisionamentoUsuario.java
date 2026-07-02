package com.prognum.launcher.autenticacao.port.out;

import java.util.Optional;

import com.prognum.launcher.autenticacao.mapeado.NovoUsuario;
import com.prognum.launcher.autenticacao.mapeado.UsuarioScci;

/**
 * Port de saída para o PROVISIONAMENTO de usuário dos logins payload-mapeado (família B). Concentra
 * TODOS os acessos a banco que os loginXXX.pas fazem depois que o IdP externo já autenticou: buscar/
 * inserir/atualizar USUARIO, resolver PERFIL/ENTIDADE/SETOR e checagens específicas (CADMUT p/ CPF,
 * ENTIDADE_SCCI p/ cooperativa, subordinação de entidade). Cada operação é ANSI-standard/parametrizada
 * (multi-banco). O adapter JDBC lê tabela/colunas do ambiente via launcherenv.ini.
 *
 * SOMENTE as escritas de provisionamento (INSERT/UPDATE USUARIO) alteram a base — fiéis ao legado.
 */
public interface ProvisionamentoUsuario {

    // ---- PERFIL ----

    /** COD_PERFIL por NOME_PERFIL. {@code exato=false} usa UPPER dos dois lados (c6/brb/cashmeweb);
     *  {@code exato=true} compara literal (loginitau). Vazio se não achar. */
    Optional<Integer> perfilPorNome(String nomePerfil, boolean exato, String ambiente);

    /** Valida existência de um COD_PERFIL (loginailos.ValidaPerfil, por código). */
    boolean perfilExiste(int codPerfil, String ambiente);

    // ---- USUARIO ----

    /** Busca por UPPER(USUARIO)=UPPER(?) devolvendo grafia real + perfil/nome-perfil/e-mail AD
     *  (colunas ausentes viram null). Usado por c6/brb/cashmeweb/direto. */
    Optional<UsuarioScci> buscarPorUsuario(String usuario, String ambiente);

    /** Busca por USUARIO=? OR NO_E_MAIL_EMISSAO=? (loginitau/ailos/unicred). Só a existência importa;
     *  devolve a grafia real do USUARIO. */
    Optional<UsuarioScci> buscarPorUsuarioOuEmail(String usuario, String ambiente);

    /** UPDATE USUARIO SET PERF_PRIMARIO=? WHERE USUARIO=? (brb/c6/cashmeweb). */
    void atualizarPerfil(String usuario, int codPerfil, String ambiente);

    /** UPDATE USUARIO SET NO_AUTENTICACAO_AD=? WHERE USUARIO=? (loginc6). */
    void atualizarEmailAd(String usuario, String emailAd, String ambiente);

    /** INSERT INTO USUARIO (...) — provisionamento JIT (itau/c6/ailos). */
    void inserir(NovoUsuario novo, String ambiente);

    /** UPDATE USUARIO com perfil+entidade+setor+nome (o ramo "já existe" do loginitau). */
    void atualizarProvisao(String usuario, int perfPrimario, int entPrimaria, String coSetor,
                           String nome, String ambiente);

    // ---- ENTIDADE / SETOR ----

    /** Entidade default do ambiente (ENTIDADEUSUARIODEFAULT do launcherenv.ini); se não for numérica,
     *  resolve por NOME em ENTIDADES. Lança se ausente. Usado no INSERT de c6. */
    int entidadeDefault(String ambiente);

    /** Entidade default do loginitau: ENTIDADEUSUARIODEFAULT numérica; vazia => -1; não-numérica => erro. */
    int entidadeDefaultOuMenos1(String ambiente);

    /** Valida existência de um COD_ENT (loginailos.ValidaEntidade). String vazia => sem crítica (true,
     *  devolve -1 via {@link #entidadeInexistente()} na estratégia). */
    boolean entidadeExiste(int codEnt, String ambiente);

    /** CO_ENTIDADE por CO_ENTIDADELOGIN em ENTIDADE_SCCI (loginailos); -1 se não achar. */
    int entidadePorEntidadeLogin(String coEntidadeLogin, String ambiente);

    /** CO_SETOR por (CO_PERFIL, CO_ENT) em PERFIL_SETOR; vazio se não achar (ObtemSetor). */
    String obterSetor(int codPerfil, int codEntidade, String ambiente);

    // ---- checagens específicas ----

    /** loginunicred: usuário é subordinado à entidade informada (hierarquia de ENTIDADES). Se
     *  {@code entidadeInformada} vazia => sem crítica (true). */
    boolean usuarioSubordinadoAEntidade(String usuario, String entidadeInformada, String ambiente);

    /** logincashmeweb (ramo CPF): existe contrato para o CPF em CADMUT (CAD_CPF=?). */
    boolean existeContratoCpf(String cpf, String ambiente);

    /** Sentinela "entidade inexistente" do legado (intstr(-1)). */
    static int entidadeInexistente() {
        return -1;
    }
}
