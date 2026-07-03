package com.prognum.scci.documentos.adaptadores.saida;

import java.io.ByteArrayOutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.zip.Deflater;
import java.util.zip.DeflaterOutputStream;

import org.springframework.stereotype.Component;

import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import com.prognum.scci.documentos.dominio.port.out.ArmazenadorDocumento;

/**
 * Grava documento no SISTARQ — porte fiel de GravaBinarioVersao/InsereVersaoBinario/VerificaCriterios +
 * InsereArquivoVersao/InsereItemNaBase (wsistarqlib), caminho DB-blob:
 *
 * <ul>
 *   <li><b>gravarVersao(id)</b>: VerificaCriterios (flags do SISTARQ) → INSERT nova versão (MAX+1) ou
 *       UPDATE última em CONTROLEVERSAO ({@code DADO} BLOB + zlib);</li>
 *   <li><b>inserirArquivoVersao(idPai, nome)</b>: acha o nó (NOME+IDPAI) ou CRIA (generator {@code id_SistArq}
 *       + flags herdadas da pasta-pai + INSERT SISTARQ TIPO=2), depois grava a versão.</li>
 * </ul>
 *
 * Storage: escolhe FileSystem × banco pelo {@link LocalizadorArmazenamento} (fiel a
 * {@code RetornaLocalArmazenaDocImgs > '' e DirectoryExists}). No FileSystem grava o arquivo
 * ({@code RetornaFileSystemName}) e o registro com {@code TP_GRAVACAO=1} sem {@code DADO}; no banco grava o
 * BLOB {@code DADO} com {@code TP_GRAVACAO=NULL}. Miniatura e idRaizDoDoc = extensão. {@code COMPACTADO='T'}
 * (char(1), convenção SCCI); coluna boolean nativa pode precisar de ajuste (multi-banco).
 */
@Component
public class ArmazenadorDocumentoJdbc implements ArmazenadorDocumento {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;
    private final LocalizadorArmazenamento localizador;

    public ArmazenadorDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections,
            LocalizadorArmazenamento localizador) {
        this.env = env;
        this.connections = connections;
        this.localizador = localizador;
    }

    @Override
    public int gravarVersao(int id, String nome, byte[] conteudo, String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        byte[] comprimido = deflate(conteudo);
        try (Connection conn = abrirTx(c)) {
            try {
                int versao = escreverVersao(conn, ambiente, id, nomeDoSistarq(conn, id, nome), comprimido,
                        conteudo.length, comprimido.length, usuario);
                conn.commit();
                return versao;
            } catch (Exception e) {
                conn.rollback();
                throw e;
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao gravar versao do documento " + id + " no ambiente " + c.database(), e);
        }
    }

    @Override
    public int inserirArquivoVersao(int idPai, String nome, byte[] conteudo, String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        byte[] comprimido = deflate(conteudo);
        try (Connection conn = abrirTx(c)) {
            try {
                int id = acharOuCriarNo(conn, c, idPai, nome);
                escreverVersao(conn, ambiente, id, nome, comprimido, conteudo.length, comprimido.length, usuario);
                conn.commit();
                return id;                          // ID_INSERIDO do wdoc (novo ou existente)
            } catch (Exception e) {
                conn.rollback();
                throw e;
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao inserir documento em " + idPai + " no ambiente " + c.database(), e);
        }
    }

    // ---- criação/localização do nó (InsereArquivoVersao + InsereItemNaBase) ----

    /** Acha o documento {@code nome} sob {@code idPai} (valida propriedade de versão) ou cria um nó novo. */
    private int acharOuCriarNo(Connection conn, SccDbConfig c, int idPai, String nome) throws Exception {
        Optional<Integer> existente = idPorNomeEPai(conn, nome, idPai);
        if (existente.isPresent()) {
            exigeVersionavel(conn, existente.get());   // validaPropriedadesDoc: exists sem VERSAO/so-leitura => erro
            return existente.get();
        }
        int novoId = proximoIdSistarq(conn, c);
        Flags pai = flagsDoNo(conn, idPai);            // InsereItemNaBase copia as flags da pasta-pai
        String sql = "INSERT INTO SISTARQ (ID, IDPAI, NOME, TIPO, CO_TIPO_ARQUIVO, CO_IDENTIFICACAO, "
                + "IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA) "
                + "VALUES (?, ?, ?, 2, 0, 0, ?, ?, ?, ?)";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, novoId);
            ps.setInt(2, idPai);
            ps.setString(3, nome);
            ps.setString(4, pai.criaVersao);
            ps.setString(5, pai.oculto);
            ps.setString(6, pai.controleVersao);
            ps.setString(7, pai.soLeitura);
            ps.executeUpdate();
        }
        return novoId;
    }

    private Optional<Integer> idPorNomeEPai(Connection conn, String nome, int idPai) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement("SELECT ID FROM SISTARQ WHERE NOME = ? AND IDPAI = ?")) {
            ps.setString(1, nome);
            ps.setInt(2, idPai);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? Optional.of(rs.getInt(1)) : Optional.empty();
            }
        }
    }

    /** validaPropriedadesDoc: só gera versão se IN_CRIA_VERSAO_ATUALIZADA='S' e não for somente-leitura. */
    private void exigeVersionavel(Connection conn, int id) throws Exception {
        Flags f = flagsDoNo(conn, id);
        if (!"S".equalsIgnoreCase(f.criaVersao) || "S".equalsIgnoreCase(f.soLeitura)) {
            throw new IllegalStateException(
                    "A propriedade de gerar versao nao esta marcada ou a de somente leitura esta marcada");
        }
    }

    private Flags flagsDoNo(Connection conn, int id) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement(
                "SELECT IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA "
                + "FROM SISTARQ WHERE ID = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return new Flags("", "", "", "");
                }
                return new Flags(nz(rs.getString(1)), nz(rs.getString(2)), nz(rs.getString(3)), nz(rs.getString(4)));
            }
        }
    }

    private record Flags(String criaVersao, String oculto, String controleVersao, String soLeitura) {
    }

    // ---- escrita da versão (GravaBinarioVersao/InsereVersaoBinario) ----

    private int escreverVersao(Connection conn, String ambiente, int id, String nome, byte[] dado, int tam,
                               int tamC, String usuario) throws Exception {
        boolean fs = localizador.usaFileSystem(ambiente);   // RetornaLocalArmazenaDocImgs > '' e DirectoryExists
        int versao;
        if (decideNovaVersao(conn, id)) {
            versao = maxVersao(conn, id) + 1;
            if (fs) {
                inserirFileSystem(conn, ambiente, id, versao, dado, tam, tamC, nome, usuario);
            } else {
                inserir(conn, id, versao, dado, tam, tamC, nome, usuario);
            }
        } else {
            versao = maxVersao(conn, id);
            if (fs) {
                atualizarFileSystem(conn, ambiente, id, versao, dado, tam, tamC, usuario);
            } else {
                atualizar(conn, id, versao, dado, tam, tamC, usuario);
            }
        }
        return versao;
    }

    /** VerificaCriterios: cria versão a cada save, ou grava nova versão se ainda não há/última aprovada. */
    private boolean decideNovaVersao(Connection conn, int id) throws Exception {
        Flags f = flagsDoNo(conn, id);
        if ("S".equalsIgnoreCase(f.criaVersao)) {
            return true;
        }
        if ("S".equalsIgnoreCase(f.controleVersao)) {
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
        return maxVersao(conn, id) == 0;
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

    // ---- escrita da versão em FileSystem (InsereVersao/GravaBinarioVersao, ramo LocalArmazenaDocImgs > '') ----

    /** INSERT com {@code TP_GRAVACAO=1} (sem {@code DADO}) + arquivo em disco (RetornaFileSystemName). */
    private void inserirFileSystem(Connection conn, String ambiente, int id, int versao, byte[] dado, int tam,
                                   int tamC, String nome, String usuario) throws Exception {
        String sql = "INSERT INTO CONTROLEVERSAO "
                + "(ID, VERSAO, TP_GRAVACAO, ALT_USUARIO, ALT_DATA, COMPACTADO, NOME, NU_TAMANHO_ARQUIVO, "
                + "NU_TAMANHO_COMPACTADO, TE_IMAGEM_REDUZIDA) VALUES (?, ?, 1, ?, ?, 'T', ?, ?, ?, '')";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, id);
            ps.setInt(2, versao);
            ps.setString(3, usuario);
            ps.setTimestamp(4, Timestamp.valueOf(LocalDateTime.now()));
            ps.setString(5, nome);
            ps.setInt(6, tam);
            ps.setInt(7, tamC);
            ps.executeUpdate();
        }
        gravarArquivo(ambiente, id, versao, dado);
    }

    /** UPDATE zerando {@code DADO}, {@code TP_GRAVACAO=1} + arquivo em disco (sobrescreve a versão). */
    private void atualizarFileSystem(Connection conn, String ambiente, int id, int versao, byte[] dado, int tam,
                                     int tamC, String usuario) throws Exception {
        String sql = "UPDATE CONTROLEVERSAO SET DADO = NULL, ALT_USUARIO = ?, ALT_DATA = ?, COMPACTADO = 'T', "
                + "TP_GRAVACAO = 1, NU_TAMANHO_ARQUIVO = ?, NU_TAMANHO_COMPACTADO = ? "
                + "WHERE ID = ? AND VERSAO = ?";
        try (PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            ps.setTimestamp(2, Timestamp.valueOf(LocalDateTime.now()));
            ps.setInt(3, tam);
            ps.setInt(4, tamC);
            ps.setInt(5, id);
            ps.setInt(6, versao);
            ps.executeUpdate();
        }
        gravarArquivo(ambiente, id, versao, dado);
    }

    /**
     * Grava o binário (já deflacionado) no caminho do FileSystem, criando a árvore de diretórios
     * (GaranteCaminhoFileSystemName). Feito DEPOIS do SQL, dentro da mesma transação: se falhar, o caller
     * dá rollback (sem linha órfã); se o SQL falhar antes, nenhum arquivo é escrito.
     */
    private void gravarArquivo(String ambiente, int id, int versao, byte[] dado) throws Exception {
        Path arquivo = localizador.caminho(ambiente, id, versao);
        Files.createDirectories(arquivo.getParent());
        Files.write(arquivo, dado);
    }

    // ---- helpers ----

    private Connection abrirTx(SccDbConfig c) throws Exception {
        Connection conn = connections.abrir(c, false);
        conn.setAutoCommit(false);
        return conn;
    }

    /**
     * Generator {@code id_SistArq} (LeGenerator) — dependente de driver (igual ao UIDUSUARIO). No Postgres o
     * LeGenerator mapeia o generator p/ a SEQUENCE {@code sq_<nome-lower>}: {@code id_SistArq -> sq_id_sistarq}
     * (confirmado ao vivo; padrão do schema: {@code sq_gen_nu_perfil_sistarq} etc). Firebird usa o generator
     * pelo nome; Oracle/MSSQL best-effort (sem ambiente p/ validar).
     */
    private int proximoIdSistarq(Connection conn, SccDbConfig c) throws Exception {
        String driver = c.driver() == null ? "" : c.driver().toUpperCase();
        String sql = switch (driver) {
            case "POSTGRES" -> "SELECT nextval('sq_id_sistarq')";
            case "ORACLE", "ORANET" -> "SELECT sq_id_sistarq.NEXTVAL FROM DUAL";
            case "MSSQL" -> "SELECT NEXT VALUE FOR sq_id_sistarq";
            case "INTERBASE" -> "SELECT GEN_ID(id_SistArq, 1) FROM RDB$DATABASE";
            default -> "SELECT GEN_ID(id_SistArq, 1) FROM RDB$DATABASE";
        };
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
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

    private static String nz(String s) {
        return s == null ? "" : s.trim();
    }
}
