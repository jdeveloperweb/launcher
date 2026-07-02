package com.prognum.scci.documentos.adaptadores.saida;

import java.io.ByteArrayOutputStream;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;

import org.springframework.stereotype.Component;

import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import com.prognum.scci.documentos.dominio.port.out.ArmazenadorDocumento;

/**
 * Grava versão binária no SISTARQ — porte fiel de GravaBinarioVersao/InsereVersaoBinario/VerificaCriterios
 * (wsistarqlib), caminho DB-blob:
 *
 * <ol>
 *   <li><b>VerificaCriterios</b>: lê {@code IN_CRIA_VERSAO_ATUALIZADA}/{@code IN_CONTROLE_VERSAO} do SISTARQ;</li>
 *   <li>decide inserir NOVA versão (MAX(VERSAO)+1) ou atualizar a última;</li>
 *   <li>comprime (zlib) e grava em CONTROLEVERSAO ({@code DADO} BLOB, {@code COMPACTADO='T'}).</li>
 * </ol>
 *
 * Escopo: documento existente + DB-blob. FileSystem/S3, miniatura e criação de documento novo = extensão.
 * NOTA multi-banco: {@code COMPACTADO} é gravado como {@code 'T'/'F'} (char(1), convenção SCCI); em coluna
 * boolean nativa (ex.: Postgres bool) pode precisar de ajuste.
 */
@Component
public class ArmazenadorDocumentoJdbc implements ArmazenadorDocumento {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public ArmazenadorDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public int gravarVersao(int id, String nome, byte[] conteudo, String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        byte[] comprimido = deflate(conteudo);
        try (Connection conn = connections.abrir(c, false)) {
            boolean auto = conn.getAutoCommit();
            conn.setAutoCommit(false);
            try {
                boolean novaVersao = decideNovaVersao(conn, id);
                String nomeSistarq = nomeDoSistarq(conn, id, nome);
                int versao;
                if (novaVersao) {
                    versao = maxVersao(conn, id) + 1;
                    inserir(conn, id, versao, comprimido, conteudo.length, comprimido.length, nomeSistarq, usuario);
                } else {
                    versao = maxVersao(conn, id);
                    atualizar(conn, id, versao, comprimido, conteudo.length, comprimido.length, usuario);
                }
                conn.commit();
                return versao;
            } catch (Exception e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(auto);
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao gravar versao do documento " + id + " no ambiente " + c.database(), e);
        }
    }

    /** VerificaCriterios: cria versão a cada save, ou grava nova versão se ainda não há versão/última aprovada. */
    private boolean decideNovaVersao(Connection conn, int id) throws Exception {
        boolean criaVersao = false;
        boolean controleVersao = false;
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT IN_CRIA_VERSAO_ATUALIZADA, IN_CONTROLE_VERSAO FROM SISTARQ WHERE ID = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    criaVersao = "S".equalsIgnoreCase(trim(rs.getString(1)));
                    controleVersao = "S".equalsIgnoreCase(trim(rs.getString(2)));
                }
            }
        }
        if (criaVersao) {
            return true;
        }
        if (controleVersao) {
            // sem versões OU última já implantada (DT_IMPLANTACAO_VERSAO not null) => nova versão
            try (PreparedStatement ps = conn.prepareStatement(
                    "SELECT DT_IMPLANTACAO_VERSAO FROM CONTROLEVERSAO WHERE ID = ? ORDER BY VERSAO DESC")) {
                ps.setInt(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        return true;
                    }
                    rs.getTimestamp(1);
                    return !rs.wasNull();
                }
            }
        }
        return maxVersao(conn, id) == 0;   // sem versão ainda => grava a primeira
    }

    private int maxVersao(Connection conn, int id) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT COALESCE(MAX(VERSAO), 0) FROM CONTROLEVERSAO WHERE ID = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        }
    }

    /** RetornaFileName: o NOME canônico do documento no SISTARQ (fallback = nome enviado). */
    private String nomeDoSistarq(Connection conn, int id, String nomeEnviado) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement("SELECT NOME FROM SISTARQ WHERE ID = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    String n = rs.getString(1);
                    if (n != null && !n.isBlank()) {
                        return n;
                    }
                }
            }
        }
        return nomeEnviado == null ? "" : nomeEnviado;
    }

    private void inserir(Connection conn, int id, int versao, byte[] dado, int tam, int tamC,
                         String nome, String usuario) throws Exception {
        String sql = "INSERT INTO CONTROLEVERSAO "
                + "(ID, VERSAO, DADO, ALT_USUARIO, ALT_DATA, COMPACTADO, NOME, NU_TAMANHO_ARQUIVO, "
                + "NU_TAMANHO_COMPACTADO, TE_IMAGEM_REDUZIDA) VALUES (?, ?, ?, ?, ?, 'T', ?, ?, ?, '')";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            ps.setInt(2, versao);
            ps.setBytes(3, dado);
            ps.setString(4, usuario);
            ps.setTimestamp(5, Timestamp.valueOf(LocalDateTime.now()));
            ps.setString(6, nome);
            ps.setInt(7, tam);
            ps.setInt(8, tamC);
            ps.executeUpdate();
        }
    }

    private void atualizar(Connection conn, int id, int versao, byte[] dado, int tam, int tamC,
                           String usuario) throws Exception {
        String sql = "UPDATE CONTROLEVERSAO SET DADO = ?, ALT_USUARIO = ?, ALT_DATA = ?, COMPACTADO = 'T', "
                + "NU_TAMANHO_ARQUIVO = ?, NU_TAMANHO_COMPACTADO = ?, TP_GRAVACAO = NULL "
                + "WHERE ID = ? AND VERSAO = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setBytes(1, dado);
            ps.setString(2, usuario);
            ps.setTimestamp(3, Timestamp.valueOf(LocalDateTime.now()));
            ps.setInt(4, tam);
            ps.setInt(5, tamC);
            ps.setInt(6, id);
            ps.setInt(7, versao);
            ps.executeUpdate();
        }
    }

    /** CompactaStream do apilib = zlib (deflate). Casa com o InflaterInputStream do read. */
    private static byte[] deflate(byte[] bruto) {
        Deflater def = new Deflater(Deflater.DEFAULT_COMPRESSION);
        ByteArrayOutputStream out = new ByteArrayOutputStream(Math.max(64, bruto.length / 2));
        try (DeflaterOutputStream dos = new DeflaterOutputStream(out, def)) {
            dos.write(bruto);
        } catch (Exception e) {
            throw new IllegalStateException("falha ao compactar documento", e);
        } finally {
            def.end();
        }
        return out.toByteArray();
    }

    private static String trim(String s) {
        return s == null ? "" : s.trim();
    }
}
