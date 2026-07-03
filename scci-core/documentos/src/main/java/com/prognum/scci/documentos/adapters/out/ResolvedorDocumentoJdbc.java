package com.prognum.scci.documentos.adapters.out;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Optional;

import org.springframework.stereotype.Component;

import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import com.prognum.scci.documentos.domain.port.out.ResolvedorDocumento;

/**
 * Resolve entidade → id no SISTARQ — porte fiel de ObtemIDS/ObtemIDSTarefa (apilib) + a caminhada da
 * árvore do SISTARQ (wsistarqlib: LeIDDoPath/LeIDdoDiretorio/LeIDdoItem):
 *
 * <ul>
 *   <li>nome do doc: {@code select NO_DOCUMENTO_SISTARQ from documento_operacao|documento_ocorrencia_sisat};</li>
 *   <li>pasta-pai:   {@code select CO_IDPAIDOCUMENTOS from PRETENDENTE|OCORRENCIA_SISAT} (só leitura; não gera árvore);</li>
 *   <li>caminhada:   SISTARQ é árvore (ID, NOME, IDPAI, TIPO=1 pasta) — desce por pasta e resolve o item folha.</li>
 * </ul>
 *
 * Tudo na base de atividade (PegaDirAtv/SCIS) — aqui, a conexão do ambiente. Query ANSI → multi-banco.
 */
@Component
public class ResolvedorDocumentoJdbc implements ResolvedorDocumento {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public ResolvedorDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public Optional<Integer> idPorOperacao(String nuPretendente, String nuDocumento, boolean caseSensitive,
                                           String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c)) {
            String noDoc = noDocumentoSistArq(conn,
                    "select NO_DOCUMENTO_SISTARQ from documento_operacao where nu_pretendente = ? and nu_documento = ?",
                    nuPretendente, nuDocumento);
            if (noDoc == null || noDoc.isBlank()) {
                return Optional.empty();
            }
            // GeraIDPaiDocumentosPretendente: NU_PRETENDENTE = operação com 9 dígitos (IntStr2(op,9))
            Integer idPai = idPaiDocumentos(conn,
                    "select CO_IDPAIDOCUMENTOS from PRETENDENTE where NU_PRETENDENTE = ?", pad9(valint(nuPretendente)));
            if (idPai == null) {
                return Optional.empty();
            }
            String path = "/" + noDoc.replace('\\', '/');
            int id = leIdDoPath(conn, path, idPai, caseSensitive);
            if (id < 0 && path.startsWith("//")) {              // fallback do GetDocumentoOperacao (barra dupla)
                id = leIdDoPath(conn, path.substring(1), idPai, caseSensitive);
            }
            return id >= 0 ? Optional.of(id) : Optional.empty();
        } catch (Exception e) {
            throw new IllegalStateException("falha ao resolver documento de operacao no ambiente " + c.database(), e);
        }
    }

    @Override
    public Optional<Integer> idPorSisat(int nuOcorrencia, String nuDocumento, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c)) {
            String noDoc = noDocumentoSistArq(conn,
                    "select NO_DOCUMENTO_SISTARQ from documento_ocorrencia_sisat where nu_ocorrencia = ? and nu_documento = ?",
                    String.valueOf(nuOcorrencia), nuDocumento);
            if (noDoc == null || noDoc.isBlank()) {
                return Optional.empty();
            }
            Integer idPai = idPaiDocumentos(conn,
                    "select CO_IDPAIDOCUMENTOS from OCORRENCIA_SISAT where NU_OCORRENCIA = ?", String.valueOf(nuOcorrencia));
            if (idPai == null) {
                return Optional.empty();
            }
            int id = leIdDoPath(conn, "/" + noDoc.replace('\\', '/'), idPai, false);
            return id >= 0 ? Optional.of(id) : Optional.empty();
        } catch (Exception e) {
            throw new IllegalStateException("falha ao resolver documento de sisat no ambiente " + c.database(), e);
        }
    }

    // ---- caminhada na árvore do SISTARQ ----

    /** LeIDDoPath: desce pastas (TIPO=1) e resolve o item folha. Path tipo {@code /pasta/sub/arquivo.pdf}. */
    private int leIdDoPath(Connection conn, String path, int idPai, boolean caseSensitive) throws Exception {
        String[] partes = path.split("/");
        int atual = idPai;
        int ultimo = ultimoNaoVazio(partes);
        if (ultimo < 0) {
            return -1;
        }
        for (int i = 0; i < partes.length; i++) {
            if (partes[i].isEmpty()) {
                continue;
            }
            if (i == ultimo) {
                return leIdDoItem(conn, partes[i], atual, caseSensitive);
            }
            atual = leIdDoDiretorio(conn, partes[i], atual);
            if (atual < 0) {
                return -1;
            }
        }
        return -1;
    }

    /** LeIDdoDiretorio: pasta (TIPO=1) por nome sob idpai (case-insensitive). */
    private int leIdDoDiretorio(Connection conn, String nome, int idPai) throws Exception {
        return primeiroId(conn,
                "SELECT ID FROM SISTARQ WHERE IDPAI = ? AND TIPO = 1 AND UPPER(NOME) = UPPER(?)", idPai, nome, false);
    }

    /** LeIDdoItem: item (folha) por nome sob idpai; case-sensitive opcional. */
    private int leIdDoItem(Connection conn, String nome, int idPai, boolean caseSensitive) throws Exception {
        String sql = caseSensitive
                ? "SELECT ID FROM SISTARQ WHERE IDPAI = ? AND NOME = ?"
                : "SELECT ID FROM SISTARQ WHERE IDPAI = ? AND UPPER(NOME) = UPPER(?)";
        return primeiroId(conn, sql, idPai, nome, true);
    }

    // ---- helpers ----

    private static int primeiroId(Connection conn, String sql, int idPai, String nome, boolean unused) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, idPai);
            ps.setString(2, nome);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt("ID") : -1;
            }
        }
    }

    private static String noDocumentoSistArq(Connection conn, String sql, String p1, String p2) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, p1);
            ps.setString(2, p2);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getString(1) : null;
            }
        }
    }

    /** CO_IDPAIDOCUMENTOS; null se não achar ou &le; 0 (só leitura — não gera árvore, como TestaIDPaiDocumentos). */
    private static Integer idPaiDocumentos(Connection conn, String sql, String param) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, param);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return null;
                }
                int id = rs.getInt(1);
                return id > 0 ? id : null;
            }
        }
    }

    private static int ultimoNaoVazio(String[] partes) {
        for (int i = partes.length - 1; i >= 0; i--) {
            if (!partes[i].isEmpty()) {
                return i;
            }
        }
        return -1;
    }

    private static int valint(String s) {
        if (s == null) {
            return 0;
        }
        int i = 0;
        StringBuilder sb = new StringBuilder();
        String t = s.trim();
        while (i < t.length() && Character.isDigit(t.charAt(i))) {
            sb.append(t.charAt(i++));
        }
        return sb.isEmpty() ? 0 : Integer.parseInt(sb.toString());
    }

    private static String pad9(int n) {
        return String.format("%09d", n);
    }
}
