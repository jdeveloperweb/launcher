package com.prognum.launcher.legacy.db;

import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.Optional;

/**
 * Consulta o usuario na base do ambiente (igual ao TestaUsuario do loginbd.pas), usando as
 * colunas configuradas no launcherenv.ini. SOMENTE LEITURA.
 */
@Component
public class SccLoginRepository {

    private final JdbcConnectionFactory connections;

    public SccLoginRepository(JdbcConnectionFactory connections) {
        this.connections = connections;
    }

    /** Linha do usuario relevante para o login. */
    public record SccUser(
            String senhaHash,
            LocalDate dtValidade,
            LocalDate ultimaTroca,
            Integer maxDias,
            Integer minDias,
            String mustChange) {
    }

    public Optional<SccUser> buscar(SccDbConfig c, String usuario) {
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
                return Optional.of(new SccUser(
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

    private static Integer toInt(ResultSet rs, String col) throws java.sql.SQLException {
        int v = rs.getInt(col);
        return rs.wasNull() ? null : v;
    }
}
