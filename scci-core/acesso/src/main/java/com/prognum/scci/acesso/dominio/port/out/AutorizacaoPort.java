package com.prognum.scci.acesso.dominio.port.out;

/**
 * Port de saida de AUTORIZACAO — permissao por operacao (UsuarioTemPerm/TemPermissao do SCCI).
 *
 * DECISAO (validada 2026-07-02): a autorizacao por operacao NAO e responsabilidade do launcher e
 * sim dos PROGRAMAS. No SCCI, {@code UsuarioTemPerm(PegaUsuario, NumPerm)} e chamado DENTRO das
 * rotinas (apiscci/apilib), levantando "Usuario nao tem permissao". E {@code PegaUsuario} resolve o
 * usuario por {@code getenv('USER')} (scciio.pas). O reator ja injeta {@code USER=<usuario da sessao
 * VALIDA'da>} no ambiente do programa (ver LauncherEnvReader.ambienteEnv), entao o programa enforca a
 * permissao do usuario CORRETO — como o launcher legado (que tambem NAO faz gate proprio). Validado:
 * {@code GetSetaPermissoes} devolve TEMPERM_* = true para supervisor e false para usuario inexistente.
 * O front esconde botoes por {@code permissao="NNNN"} usando essa mesma lista (metodo despachado no /w).
 *
 * Portanto NAO ha adapter: reimplementar o gate no launcher DUPLICARIA a logica do programa (nao-fiel
 * e arriscado). Este port fica como HOOK OPCIONAL para um eventual defense-in-depth na borda — hoje
 * deliberadamente sem uso.
 */
public interface AutorizacaoPort {

    /** Hook opcional de checagem na borda (nao usado — os programas ja enforcam via getenv('USER')). */
    boolean podeExecutar(String usuario, String ambiente, String operacao);
}
