package com.prognum.scci.documentos.adaptadores.saida;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Optional;
import java.util.zip.InflaterInputStream;

import org.springframework.stereotype.Component;

import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import com.prognum.scci.documentos.dominio.ArquivoBruto;
import com.prognum.scci.documentos.dominio.port.out.RepositorioDocumento;

/**
 * Adapter de saída do storage — porte idiomático de GetDocumentoPorId / GetDocumentoPorIdVersao / ExcluiItem
 * (apilib.pas):
 *
 * <pre>
 *   select c.nome, s.nome as NomeSistarq, versao, dado, compactado, tp_gravacao
 *   from controleversao c, sistarq s
 *   where s.id = ? and c.id = s.id [and c.versao = ?]
 *   order by versao desc
 * </pre>
 *
 * Lê o BLOB {@code dado} e descomprime (zlib) quando {@code compactado='T'}. Cobre o storage em BANCO (o
 * caso comum); FileSystem/S3 ({@code tp_gravacao}) são ponto de extensão (RetornaFileSystemName/S3, em units
 * externas ainda não portadas). Query ANSI/parametrizada → multi-banco.
 *
 * NOTA: o documento vive na base de "atividade" (PegaDirAtv/SCIS) do apilib; aqui uso a conexão do ambiente
 * (launcherenv). Se o cliente separar a base de documentos, o ajuste é neste adapter.
 */
@Component
public class RepositorioDocumentoJdbc implements RepositorioDocumento {

    private static final String COLS =
            "c.nome as NOME, s.nome as NOMESISTARQ, versao, dado, compactado, tp_gravacao";
    private static final String SQL_ULTIMA =
            "select " + COLS + " from controleversao c, sistarq s "
            + "where s.id = ? and c.id = s.id order by versao desc";
    private static final String SQL_VERSAO =
            "select " + COLS + " from controleversao c, sistarq s "
            + "where s.id = ? and c.id = s.id and c.versao = ? order by versao desc";

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public RepositorioDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public Optional<ArquivoBruto> buscarUltimaVersao(int id, String ambiente) {
        return buscar(ambiente, SQL_ULTIMA, id, null);
    }

    @Override
    public Optional<ArquivoBruto> buscarVersao(int id, int versao, String ambiente) {
        return buscar(ambiente, SQL_VERSAO, id, versao);
    }

    private Optional<ArquivoBruto> buscar(String ambiente, String sql, int id, Integer versao) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            if (versao != null) {
                ps.setInt(2, versao);
            }
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {          // order by versao desc -> 1a linha = versão pedida/última
                    return Optional.empty();
                }
                String nome = rs.getString("NOME");
                if (nome == null || nome.isBlank()) {
                    nome = rs.getString("NOMESISTARQ");
                }
                byte[] dado = rs.getBytes("dado");
                if (dado == null) {
                    throw new UnsupportedOperationException(
                            "documento " + id + " fora do banco (tp_gravacao=" + rs.getInt("tp_gravacao")
                            + "); storage FileSystem/S3 ainda nao portado");
                }
                byte[] conteudo = compactado(rs.getString("compactado")) ? descomprimir(dado) : dado;
                return Optional.of(new ArquivoBruto(nome, conteudo));
            }
        } catch (UnsupportedOperationException e) {
            throw e;
        } catch (Exception e) {
            throw new IllegalStateException("falha ao ler documento " + id + " no ambiente " + c.database(), e);
        }
    }

    @Override
    public void excluir(int id, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c, false)) {   // escrita
            boolean auto = conn.getAutoCommit();
            conn.setAutoCommit(false);
            try (PreparedStatement pcv = conn.prepareStatement("delete from CONTROLEVERSAO where id = ?");
                 PreparedStatement psa = conn.prepareStatement("delete from SISTARQ where id = ?")) {
                pcv.setInt(1, id);
                pcv.executeUpdate();
                psa.setInt(1, id);
                psa.executeUpdate();
                conn.commit();
            } catch (Exception e) {
                conn.rollback();
                throw e;
            } finally {
                conn.setAutoCommit(auto);
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao excluir documento " + id + " no ambiente " + c.database(), e);
        }
    }

    /** {@code Compactado='T'} (BooleanToSqlboolean(true) do SCCI); tolera S/1/true. */
    private static boolean compactado(String v) {
        if (v == null) {
            return false;
        }
        String t = v.trim();
        return t.equalsIgnoreCase("T") || t.equalsIgnoreCase("S") || t.equals("1") || t.equalsIgnoreCase("true");
    }

    /** DescompactaStream do apilib = zlib (paszlib). Em Java: InflaterInputStream (formato zlib padrão). */
    private static byte[] descomprimir(byte[] comprimido) throws Exception {
        try (InflaterInputStream in = new InflaterInputStream(new ByteArrayInputStream(comprimido))) {
            ByteArrayOutputStream out = new ByteArrayOutputStream(Math.max(64, comprimido.length * 2));
            in.transferTo(out);
            return out.toByteArray();
        }
    }
}
