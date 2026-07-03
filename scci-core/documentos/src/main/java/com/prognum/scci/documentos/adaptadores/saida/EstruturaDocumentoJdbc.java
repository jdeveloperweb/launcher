package com.prognum.scci.documentos.adaptadores.saida;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import org.springframework.stereotype.Component;

import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import com.prognum.scci.documentos.dominio.port.out.EstruturaDocumento;

/**
 * Estrutura/metadados do SISTARQ — porte de PutNome/PutPasta (apiscci) + AlteraNomeDoc/InsereItemNaBase:
 * renomear (UPDATE SISTARQ.NOME com guardas de TIPO) e criar pasta (INSERT SISTARQ TIPO=1, id via generator
 * {@code id_SistArq}). Query ANSI → multi-banco.
 */
@Component
public class EstruturaDocumentoJdbc implements EstruturaDocumento {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public EstruturaDocumentoJdbc(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public void renomear(int id, String novoNome, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c, false)) {
            String tipo = tipoDoNo(conn, id);
            if ("3".equals(tipo)) {
                throw new IllegalStateException("Nao e possivel renomear a Lixeira");
            }
            if ("0".equals(tipo)) {
                throw new IllegalStateException("Nao e possivel renomear a aba Documentos");
            }
            try (PreparedStatement ps = conn.prepareStatement("UPDATE SISTARQ SET NOME = ? WHERE ID = ?")) {
                ps.setString(1, novoNome);
                ps.setInt(2, id);
                ps.executeUpdate();
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao renomear documento " + id + " no ambiente " + c.database(), e);
        }
    }

    @Override
    public int criarPasta(int idPai, String nome, boolean exibePastas, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c, false)) {
            int novoId = proximoIdSistarq(conn, c);
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO SISTARQ (ID, IDPAI, NOME, TIPO, IN_EXIBE_PASTA) VALUES (?, ?, ?, 1, ?)")) {
                ps.setInt(1, novoId);
                ps.setInt(2, idPai);
                ps.setString(3, nome);
                ps.setString(4, exibePastas ? "S" : "N");
                ps.executeUpdate();
            }
            return novoId;
        } catch (Exception e) {
            throw new IllegalStateException("falha ao criar pasta em " + idPai + " no ambiente " + c.database(), e);
        }
    }

    private static String tipoDoNo(Connection conn, int id) throws Exception {
        try (PreparedStatement ps = conn.prepareStatement("SELECT TIPO FROM SISTARQ WHERE ID = ?")) {
            ps.setInt(1, id);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? String.valueOf(rs.getInt("TIPO")) : "";
            }
        }
    }

    /** Generator id_SistArq — dependente de driver (igual ao UIDUSUARIO/InsereItemNaBase). */
    private int proximoIdSistarq(Connection conn, SccDbConfig c) throws Exception {
        String driver = c.driver() == null ? "" : c.driver().toUpperCase();
        String sql = switch (driver) {
            case "POSTGRES" -> "SELECT nextval('id_SistArq')";
            case "ORACLE", "ORANET" -> "SELECT id_SistArq.NEXTVAL FROM DUAL";
            case "MSSQL" -> "SELECT NEXT VALUE FOR id_SistArq";
            default -> "SELECT GEN_ID(id_SistArq, 1) FROM RDB$DATABASE";
        };
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 0;
        }
    }
}
