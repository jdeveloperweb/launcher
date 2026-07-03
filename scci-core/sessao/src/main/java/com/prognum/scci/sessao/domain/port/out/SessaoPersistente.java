package com.prognum.scci.sessao.domain.port.out;

/**
 * Port de saida: SESSAO PERSISTENTE na base do ambiente (tabela SCCI_SESSION), autoritativa —
 * igual ao launcher.pas. Implementa o VALIDA (VerificaSessionKeyExpirada): o login GRAVA o
 * sessionKey e o despacho REVALIDA o token (NO_USUARIO + SESSION_KEY) antes de executar o "w".
 */
public interface SessaoPersistente {

    /** Grava a sessao (login). Best-effort: nao deve derrubar o login se falhar. */
    void registrar(String usuario, String sessionKey, String ip, String ambiente);

    /** VALIDA: o token existe/esta vivo para o usuario? (VerificaSessionKeyExpirada) */
    boolean estaValida(String usuario, String sessionKey, String ambiente);

    /** Encerra a sessao (logout). */
    void encerrar(String usuario, String sessionKey, String ambiente);

    /** Quantas sessoes ativas o usuario tem (para o limite QtMaxLogin do launcher). */
    int contarAtivas(String usuario, String ambiente);
}
