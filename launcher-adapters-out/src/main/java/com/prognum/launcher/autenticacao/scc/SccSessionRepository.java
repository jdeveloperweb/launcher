package com.prognum.launcher.autenticacao.scc;

import com.prognum.launcher.autenticacao.port.out.SessaoPersistente;
import com.prognum.launcher.compartilhado.db.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter de saida: SESSAO PERSISTENTE na SCCI_SESSION do ambiente — o VALIDA do launcher.pas
 * (VerificaSessionKeyExpirada faz SELECT por NO_USUARIO + SESSION_KEY). O login GRAVA; o despacho
 * REVALIDA. Colunas: session_key, no_usuario, nu_ip_acesso, in_em_login, dt_hora_solicitacao.
 */
@Component
public class SccSessionRepository implements SessaoPersistente {

    private static final Logger log = LoggerFactory.getLogger(SccSessionRepository.class);

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public SccSessionRepository(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public void registrar(String usuario, String sessionKey, String ip, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "INSERT INTO SCCI_SESSION "
                + "(SESSION_KEY, NO_USUARIO, NU_IP_ACESSO, IN_EM_LOGIN, DT_HORA_SOLICITACAO) "
                + "VALUES (?, ?, ?, 'T', ?)";
        try (Connection conn = connections.abrir(c, false);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, sessionKey);
            ps.setString(2, usuario);
            ps.setString(3, ip == null ? "" : ip);
            ps.setTimestamp(4, new Timestamp(System.currentTimeMillis()));
            ps.executeUpdate();
        } catch (Exception e) {
            // best-effort: nao derruba o login se a gravacao da sessao falhar (o Redis ja tem).
            log.warn("scci_session_registrar_falha", kv("usuario", usuario),
                    kv("erro", String.valueOf(e.getMessage())));
        }
    }

    @Override
    public boolean estaValida(String usuario, String sessionKey, String ambiente) {
        if (usuario == null || sessionKey == null) {
            return false;
        }
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT 1 FROM SCCI_SESSION WHERE NO_USUARIO = ? AND SESSION_KEY = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            ps.setString(2, sessionKey);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        } catch (Exception e) {
            log.warn("scci_session_valida_falha", kv("usuario", usuario),
                    kv("erro", String.valueOf(e.getMessage())));
            return false;
        }
    }

    @Override
    public int contarAtivas(String usuario, String ambiente) {
        if (usuario == null) {
            return 0;
        }
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT COUNT(*) FROM SCCI_SESSION WHERE NO_USUARIO = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        } catch (Exception e) {
            log.warn("scci_session_contar_falha", kv("usuario", usuario),
                    kv("erro", String.valueOf(e.getMessage())));
            return 0;   // best-effort: nao bloqueia o login por falha na contagem
        }
    }

    @Override
    public void encerrar(String usuario, String sessionKey, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "DELETE FROM SCCI_SESSION WHERE SESSION_KEY = ?";
        try (Connection conn = connections.abrir(c, false);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, sessionKey);
            ps.executeUpdate();
        } catch (Exception e) {
            log.warn("scci_session_encerrar_falha", kv("usuario", usuario),
                    kv("erro", String.valueOf(e.getMessage())));
        }
    }
}
