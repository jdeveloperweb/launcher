package com.prognum.common.environment;

/**
 * Politica de senha POR AMBIENTE, lida da secao [USERS] do launcherenv.ini (parametrizacao por
 * cliente, fiel ao loginbd). Todos default 0 = SEM exigencia (nao ser mais rigido que o legado quando
 * o cliente nao configura). Mapeamento das chaves:
 * <ul>
 *   <li>{@code minCaracteres}  = USERMINCARACPASS</li>
 *   <li>{@code minLetras}      = CARMINALFAPASS</li>
 *   <li>{@code minMaiusculas}  = CARMINALFAMAISPASS</li>
 *   <li>{@code minDigitos}     = CARMINNUMPASS</li>
 *   <li>{@code minEspeciais}   = CARMINESPPASS</li>
 *   <li>{@code maxRepetidos}   = USERMAXREPPASS</li>
 *   <li>{@code maxSequenciais} = USERMAXSEQPASS</li>
 * </ul>
 */
public record PoliticaSenhaIni(int minCaracteres, int minLetras, int minMaiusculas, int minDigitos,
                               int minEspeciais, int maxRepetidos, int maxSequenciais) {

    /** Nenhuma regra configurada (o cliente nao pede composicao/tamanho). */
    public boolean vazia() {
        return minCaracteres == 0 && minLetras == 0 && minMaiusculas == 0 && minDigitos == 0
                && minEspeciais == 0 && maxRepetidos == 0 && maxSequenciais == 0;
    }
}
