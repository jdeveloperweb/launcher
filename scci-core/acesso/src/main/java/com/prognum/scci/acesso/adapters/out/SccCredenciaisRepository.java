package com.prognum.scci.acesso.adapters.out;

import com.prognum.scci.acesso.domain.model.CredenciaisUsuario;
import com.prognum.scci.acesso.domain.port.out.CredenciaisRepository;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
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
        boolean temAtivo = c.campoAtivo() != null && !c.campoAtivo().isBlank();
        String sql = "SELECT " + c.campoSenha() + " AS SENHA, "
                + c.campoDtValidade() + " AS DTVALID, "
                + c.campoUltimaTroca() + " AS ULTTROCA, "
                + c.campoMaxDias() + " AS MAXDIAS, "
                + c.campoMinDias() + " AS MINDIAS, "
                + c.campoMustChange() + " AS MUSTCHANGE"
                + (temAtivo ? ", " + c.campoAtivo() + " AS ATIVO " : " ")
                + "FROM " + c.tabela() + " WHERE " + c.campoUsuario() + " = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                boolean ativo = !temAtivo || interpretaAtivo(rs.getString("ATIVO"));
                return Optional.of(new CredenciaisUsuario(
                        rs.getString("SENHA"),
                        toDate(rs.getTimestamp("DTVALID")),
                        toDate(rs.getTimestamp("ULTTROCA")),
                        toInt(rs, "MAXDIAS"),
                        toInt(rs, "MINDIAS"),
                        rs.getString("MUSTCHANGE"),
                        ativo));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao consultar usuario no ambiente "
                    + c.host() + "/" + c.database(), e);
        }
    }

    /**
     * Interpreta o valor da coluna USERACTIVE. Conservador: SO os marcadores explicitos de inativo
     * ({@code N/F/I/0/NAO/INATIVO/DESATIVADO}) bloqueiam; ausencia/nulo/qualquer outro valor = ativo,
     * para nao travar login por dado inesperado (fiel ao legado, que so nega o que sabe ser inativo).
     */
    static boolean interpretaAtivo(String valor) {
        if (valor == null || valor.isBlank()) {
            return true;
        }
        String v = valor.trim().toUpperCase();
        return !(v.equals("N") || v.equals("F") || v.equals("I") || v.equals("0")
                || v.equals("NAO") || v.equals("INATIVO") || v.equals("DESATIVADO"));
    }

    private static LocalDate toDate(Timestamp t) {
        return t == null ? null : t.toLocalDateTime().toLocalDate();
    }

    private static Integer toInt(ResultSet rs, String col) throws SQLException {
        int v = rs.getInt(col);
        return rs.wasNull() ? null : v;
    }
}
