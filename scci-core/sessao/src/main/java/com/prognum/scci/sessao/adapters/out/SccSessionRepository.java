package com.prognum.scci.sessao.adapters.out;

import com.prognum.scci.sessao.domain.port.out.SessaoPersistente;
import com.prognum.common.environment.JdbcConnectionFactory;
import com.prognum.common.environment.LauncherEnvReader;
import com.prognum.common.environment.SccDbConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;

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
    // Sessao mais antiga que isto (desde o login) nao conta no limite de acessos simultaneos e e
    // apagada no proximo login do usuario. Sem isto, quem fecha o navegador sem "Sair" deixa a linha
    // para sempre e trava no ACESSOSSIMULTANEOS (producao CDHU, 19/10/2026). 0 = conta todas.
    private final Duration idadeMaxima;
    private final Clock relogio;

    @Autowired
    public SccSessionRepository(LauncherEnvReader env, JdbcConnectionFactory connections,
                                @Value("${scci.sessao.idade-maxima-horas:12}") long idadeMaximaHoras) {
        this(env, connections, idadeMaximaHoras, Clock.systemUTC());
    }

    SccSessionRepository(LauncherEnvReader env, JdbcConnectionFactory connections,
                         long idadeMaximaHoras, Clock relogio) {
        this.env = env;
        this.connections = connections;
        this.idadeMaxima = idadeMaximaHoras > 0 ? Duration.ofHours(idadeMaximaHoras) : null;
        this.relogio = relogio;
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
            ps.setTimestamp(4, new Timestamp(relogio.millis()));
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
        // o corte usa o mesmo relogio da JVM que gravou DT_HORA_SOLICITACAO (registrar)
        Timestamp corte = idadeMaxima == null ? null : Timestamp.from(relogio.instant().minus(idadeMaxima));
        if (corte != null) {
            apagarAntigas(c, usuario, corte);
        }
        String sql = corte == null
                ? "SELECT COUNT(*) FROM SCCI_SESSION WHERE NO_USUARIO = ?"
                : "SELECT COUNT(*) FROM SCCI_SESSION WHERE NO_USUARIO = ? AND DT_HORA_SOLICITACAO >= ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            if (corte != null) {
                ps.setTimestamp(2, corte);
            }
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? rs.getInt(1) : 0;
            }
        } catch (Exception e) {
            log.warn("scci_session_contar_falha", kv("usuario", usuario),
                    kv("erro", String.valueOf(e.getMessage())));
            return 0;   // best-effort: nao bloqueia o login por falha na contagem
        }
    }

    /** Limpa as sessoes antigas do usuario (best-effort; a contagem ja ignora as antigas). */
    private void apagarAntigas(SccDbConfig c, String usuario, Timestamp corte) {
        String sql = "DELETE FROM SCCI_SESSION WHERE NO_USUARIO = ? AND DT_HORA_SOLICITACAO < ?";
        try (Connection conn = connections.abrir(c, false);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            ps.setTimestamp(2, corte);
            int n = ps.executeUpdate();
            if (n > 0) {
                log.info("scci_session_antigas_removidas", kv("usuario", usuario), kv("qtd", n));
            }
        } catch (Exception e) {
            log.warn("scci_session_limpar_falha", kv("usuario", usuario),
                    kv("erro", String.valueOf(e.getMessage())));
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
