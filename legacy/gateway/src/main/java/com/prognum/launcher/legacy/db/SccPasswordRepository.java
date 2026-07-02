package com.prognum.launcher.legacy.db;

import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Leitura/gravacao de senha para a troca (PASSWD do loginbd.pas, ExecutaPasswdBD).
 * Le a senha atual + historico NO_SENHA1..5 e grava a nova com ROTACAO do historico.
 */
@Component
public class SccPasswordRepository {

    private final JdbcConnectionFactory connections;

    public SccPasswordRepository(JdbcConnectionFactory connections) {
        this.connections = connections;
    }

    /** Senha atual + as 5 anteriores (NO_SENHA1..5), todas hashes md5crypt. */
    public record Senhas(String atual, List<String> anteriores) {
    }

    public Optional<Senhas> ler(SccDbConfig c, String usuario) {
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
                return Optional.of(new Senhas(rs.getString("SENHA"), anteriores));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao ler senhas em " + c.host() + "/" + c.database(), e);
        }
    }

    /**
     * Grava a nova senha (md5crypt) ROTACIONANDO o historico, igual ao ExecutaPasswdBD:
     * NO_SENHA1=NO_SENHA2, ..., NO_SENHA5=senha_atual, senha=nova; zera "trocar no proximo login".
     */
    public void gravar(SccDbConfig c, String usuario, String novoHash) {
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
