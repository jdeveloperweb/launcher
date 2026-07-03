package com.prognum.scci.acesso.adapters.out;

import com.prognum.scci.acesso.domain.model.HistoricoSenhas;
import com.prognum.scci.acesso.domain.port.out.SenhaRepository;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Adapter de saida: leitura/gravacao de senha para a troca (ExecutaPasswdBD do loginbd.pas).
 * Porte fiel do SccPasswordRepository do legado. Le a senha atual + NO_SENHA1..5 e GRAVA a nova
 * com ROTACAO do historico. O ambiente e resolvido internamente (LauncherEnvReader).
 */
@Component
public class SccSenhaRepository implements SenhaRepository {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public SccSenhaRepository(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public Optional<HistoricoSenhas> ler(String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT " + c.campoSenha() + " AS SENHA, "
                + "NO_SENHA1, NO_SENHA2, NO_SENHA3, NO_SENHA4, NO_SENHA5 "
                + "FROM " + c.tabela() + " WHERE " + c.campoUsuario() + " = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                List<String> anteriores = new ArrayList<>();
                for (int i = 1; i <= 5; i++) {
                    anteriores.add(rs.getString("NO_SENHA" + i));
                }
                return Optional.of(new HistoricoSenhas(rs.getString("SENHA"), anteriores));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao ler senhas em " + c.host() + "/" + c.database(), e);
        }
    }

    @Override
    public void gravar(String usuario, String ambiente, String novoHash) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "UPDATE " + c.tabela() + " SET "
                + c.campoMustChange() + " = ?, "
                + c.campoUltimaTroca() + " = ?, "
                + "NO_SENHA1 = NO_SENHA2, NO_SENHA2 = NO_SENHA3, NO_SENHA3 = NO_SENHA4, NO_SENHA4 = NO_SENHA5, "
                + "NO_SENHA5 = " + c.campoSenha() + ", "
                + c.campoSenha() + " = ? "
                + "WHERE " + c.campoUsuario() + " = ?";
        try (Connection conn = connections.abrir(c, false);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, "f");                                       // IN_TROCA_SENHA_PROXIMO_LOGIN
            ps.setTimestamp(2, new Timestamp(System.currentTimeMillis()));
            ps.setString(3, novoHash);
            ps.setString(4, usuario);
            if (ps.executeUpdate() == 0) {
                throw new IllegalStateException("usuario nao encontrado para gravar a senha");
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao gravar a senha em " + c.host() + "/" + c.database(), e);
        }
    }
}
