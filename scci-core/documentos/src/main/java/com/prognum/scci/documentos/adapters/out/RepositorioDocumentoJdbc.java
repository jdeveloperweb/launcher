package com.prognum.scci.documentos.adapters.out;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Optional;
import java.util.zip.InflaterInputStream;

import org.springframework.stereotype.Component;

import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import com.prognum.scci.documentos.domain.ArquivoBruto;
import com.prognum.scci.documentos.domain.port.out.RepositorioDocumento;

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
 * Lê o BLOB {@code dado} e descomprime (zlib) quando {@code compactado='T'}. Cobre os dois storages do SCCI:
 * <ul>
 *   <li><b>BANCO</b> ({@code dado} preenchido) — lê o próprio BLOB;</li>
 *   <li><b>FileSystem</b> ({@code tp_gravacao=1}, {@code dado} nulo) — porte de {@code RetornaFileSystemName}
 *       / {@code EncodeInvBase64ForFilenames} (wsistarqlib): o arquivo vive em
 *       {@code <base>/<e0>/<e1>/<e2>/<enc>.<versao3>}, onde {@code enc} = 6 primeiros chars do base64 dos 4
 *       bytes (little-endian) do ID, com {@code '/'→'_'}. Descomprime igual ao BLOB.</li>
 * </ul>
 * O <b>base</b> ({@code scciconf.LocalArmazenaDocImgs}) é configurável por {@code scci.documentos.armazena-dir}
 * (default {@code <ambiente>/doc}). S3 fica como ponto de extensão. Query ANSI/parametrizada → multi-banco.
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
    private final LocalizadorArmazenamento localizador;

    public RepositorioDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections,
            LocalizadorArmazenamento localizador) {
        this.env = env;
        this.connections = connections;
        this.localizador = localizador;
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
                int versaoLida = rs.getInt("versao");
                int tpGravacao = rs.getInt("tp_gravacao");
                byte[] dado = rs.getBytes("dado");
                if (dado == null) {                       // storage FileSystem (tp_gravacao=1): arquivo em disco
                    dado = lerDoFileSystem(ambiente, id, versaoLida, tpGravacao);
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

    /**
     * Lê o binário do FileSystem (porte de {@code RetornaFileSystemName}, wsistarqlib). Só {@code tp_gravacao=1}
     * (FileSystem); S3 ({@code tp_gravacao=2}) ainda não portado.
     */
    private byte[] lerDoFileSystem(String ambiente, int id, int versao, int tpGravacao) throws Exception {
        if (tpGravacao != 1) {                            // 2 = S3 (RetornaLocalArmazenaDocImgs -> LocalArmazenamentoS3)
            throw new UnsupportedOperationException(
                    "documento " + id + " em storage S3 (tp_gravacao=" + tpGravacao + ") ainda nao portado");
        }
        Path arquivo = localizador.caminho(ambiente, id, versao);
        if (!Files.isReadable(arquivo)) {
            throw new IllegalStateException("documento " + id + " v" + versao
                    + ": arquivo FileSystem nao encontrado em " + arquivo);
        }
        return Files.readAllBytes(arquivo);
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
