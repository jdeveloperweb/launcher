package com.prognum.scci.acesso.adaptadores.saida;

import com.prognum.scci.acesso.dominio.model.DadosRecuperacao;
import com.prognum.scci.acesso.dominio.port.out.RecuperacaoSenhaRepository;
import com.prognum.comum.ambiente.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.util.Optional;

/**
 * Adapter de saida da recuperacao de senha (ExecutaEmailPwd do loginbd.pas). Le usuario + SMTP da
 * entidade primaria e grava a senha TEMPORARIA marcando IN_TROCA_SENHA_PROXIMO_LOGIN='T'.
 */
@Component
public class SccRecuperacaoSenhaRepository implements RecuperacaoSenhaRepository {

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public SccRecuperacaoSenhaRepository(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public Optional<DadosRecuperacao> buscar(String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT u.CPF, u.NO_E_MAIL_EMISSAO AS EMAIL, "
                + "e.NO_SMTP_EMISSAO_E_MAIL AS SMTP, e.NO_USUARIO_LOGIN_SMTP AS SMTP_USER, "
                + "e.NO_SENHA_E_MAIL_EMISSAO AS SMTP_SENHA "
                + "FROM USUARIO u LEFT JOIN ENTIDADES e ON e.COD_ENT = u.ENT_PRIMARIA "
                + "WHERE u." + c.campoUsuario() + " = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                return Optional.of(new DadosRecuperacao(
                        rs.getString("CPF"), rs.getString("EMAIL"), rs.getString("SMTP"),
                        rs.getString("SMTP_USER"), rs.getString("SMTP_SENHA")));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao ler dados de recuperacao em "
                    + c.host() + "/" + c.database(), e);
        }
    }

    @Override
    public void gravarSenhaTemporaria(String usuario, String ambiente, String novoHash) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "UPDATE " + c.tabela() + " SET "
                + c.campoMustChange() + " = 'T', "     // forca troca no proximo login
                + c.campoUltimaTroca() + " = ?, "
                + c.campoSenha() + " = ? "
                + "WHERE " + c.campoUsuario() + " = ?";
        try (Connection conn = connections.abrir(c, false);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setTimestamp(1, new Timestamp(System.currentTimeMillis()));
            ps.setString(2, novoHash);
            ps.setString(3, usuario);
            if (ps.executeUpdate() == 0) {
                throw new IllegalStateException("usuario nao encontrado para gravar a senha temporaria");
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao gravar a senha temporaria em "
                    + c.host() + "/" + c.database(), e);
        }
    }
}
