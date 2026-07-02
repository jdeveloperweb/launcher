package com.prognum.launcher.autenticacao.scc;

import com.prognum.launcher.autenticacao.model.CredenciaisUsuario;
import com.prognum.launcher.autenticacao.port.out.CredenciaisRepository;
import com.prognum.launcher.compartilhado.db.JdbcConnectionFactory;
import com.prognum.launcher.compartilhado.db.LauncherEnvReader;
import com.prognum.launcher.compartilhado.db.SccDbConfig;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.Optional;

/**
 * Adapter de saida: consulta o usuario na base do ambiente (TestaUsuario do loginbd.pas), usando
 * as colunas do launcherenv.ini. Porte fiel do SccLoginRepository do legado. SOMENTE LEITURA.
 * O ambiente e resolvido internamente (LauncherEnvReader) — a aplicacao so conhece o port.
 */
@Component
public class SccCredenciaisRepository implements CredenciaisRepository {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public SccCredenciaisRepository(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public Optional<CredenciaisUsuario> buscar(String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT " + c.campoSenha() + " AS SENHA, "
                + c.campoDtValidade() + " AS DTVALID, "
                + c.campoUltimaTroca() + " AS ULTTROCA, "
                + c.campoMaxDias() + " AS MAXDIAS, "
                + c.campoMinDias() + " AS MINDIAS, "
                + c.campoMustChange() + " AS MUSTCHANGE "
                + "FROM " + c.tabela() + " WHERE " + c.campoUsuario() + " = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                return Optional.of(new CredenciaisUsuario(
                        rs.getString("SENHA"),
                        toDate(rs.getTimestamp("DTVALID")),
                        toDate(rs.getTimestamp("ULTTROCA")),
                        toInt(rs, "MAXDIAS"),
                        toInt(rs, "MINDIAS"),
                        rs.getString("MUSTCHANGE")));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao consultar usuario no ambiente "
                    + c.host() + "/" + c.database(), e);
        }
    }

    private static LocalDate toDate(Timestamp t) {
        return t == null ? null : t.toLocalDateTime().toLocalDate();
    }

    private static Integer toInt(ResultSet rs, String col) throws SQLException {
        int v = rs.getInt(col);
        return rs.wasNull() ? null : v;
    }
}
