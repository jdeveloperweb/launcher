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
 * Adapter de saída do storage de documentos — porte idiomático do {@code GetDocumentoPorId} do apilib.pas:
 *
 * <pre>
 *   select c.nome, s.nome as NomeSistarq, versao, dado, compactado, tp_gravacao
 *   from controleversao c, sistarq s
 *   where s.id = ? and c.id = s.id
 *   order by versao desc          -- pega a ÚLTIMA versão
 * </pre>
 *
 * Lê o BLOB {@code dado} e descomprime (zlib) quando {@code compactado='T'}. Multi-banco (query ANSI,
 * conexão pelo DRIVERNAME do launcherenv). Cobre o storage em BANCO (o caso comum); FileSystem/S3
 * (tp_gravacao) ficam como ponto de extensão — o apilib resolve via RetornaFileSystemName/S3, que dependem
 * de config/units externas ainda não portadas.
 *
 * NOTA de config: o documento vive na base de "atividade" (PegaDirAtv/SCIS) do apilib; aqui uso a conexão
 * do ambiente (launcherenv). Se o cliente separar a base de documentos, o ponto de ajuste é este adapter.
 */
@Component
public class RepositorioDocumentoJdbc implements RepositorioDocumento {

    private static final String SQL =
            "select c.nome as NOME, s.nome as NOMESISTARQ, versao, dado, compactado, tp_gravacao "
            + "from controleversao c, sistarq s where s.id = ? and c.id = s.id order by versao desc";

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public RepositorioDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public Optional<ArquivoBruto> buscarUltimaVersao(int id, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(SQL)) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {          // order by versao desc -> a 1a linha é a última versão
                    return Optional.empty();
                }
                String nome = rs.getString("NOME");
                if (nome == null || nome.isBlank()) {
                    nome = rs.getString("NOMESISTARQ");
                }
                byte[] dado = rs.getBytes("dado");
                if (dado == null) {
                    // tp_gravacao = FileSystem/S3: binário fora do banco (RetornaFileSystemName/S3) — não portado
                    throw new UnsupportedOperationException(
                            "documento " + id + " armazenado fora do banco (tp_gravacao=" + rs.getInt("tp_gravacao")
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
