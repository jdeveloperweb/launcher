package com.prognum.launcher.autenticacao.scc;

import com.prognum.launcher.autenticacao.port.out.ValidacaoAcessoRepository;
import com.prognum.launcher.compartilhado.db.JdbcConnectionFactory;
import com.prognum.comum.ambiente.LauncherEnvReader;
import com.prognum.comum.ambiente.SccDbConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import static net.logstash.logback.argument.StructuredArguments.kv;

/**
 * Adapter das validacoes de acesso (ValidaCpf/ValidaProtocolo do loginbd.pas). SOMENTE LEITURA.
 * Porte do caminho simples (Entidade=0): existe operacao para o CPF? existe o protocolo? Sem o
 * refinamento de entidade subordinada (usa contexto de operador logado, ausente no login-por-CPF).
 */
@Component
public class SccValidacaoAcessoRepository implements ValidacaoAcessoRepository {

    private static final Logger log = LoggerFactory.getLogger(SccValidacaoAcessoRepository.class);

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public SccValidacaoAcessoRepository(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    @Override
    public boolean cpfComOperacao(String cpf, String ambiente) {
        String dig = cpf == null ? "" : cpf.replaceAll("\\D", "");
        if (dig.isEmpty()) {
            return true;
        }
        String pad14 = dig.length() < 14 ? "0".repeat(14 - dig.length()) + dig : dig;
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT 1 FROM OPERACAO_CREDITO oc "
                + "INNER JOIN PESSOA_PRETENDENTE pp ON pp.NU_PRETENDENTE = oc.NU_PRETENDENTE AND pp.NU_PESSOA = 1 "
                + "WHERE pp.NU_CPFCNPJ IN (?, ?)";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, dig);
            ps.setString(2, pad14);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();   // achou operacao para o CPF -> acesso valido
            }
        } catch (Exception e) {
            log.warn("valida_cpf_falha", kv("erro", String.valueOf(e.getMessage())));
            return false;
        }
    }

    @Override
    public boolean protocoloExiste(String protocolo, String ambiente) {
        String dig = protocolo == null ? "" : protocolo.replaceAll("\\D", "");
        if (dig.isEmpty()) {
            return true;
        }
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT 1 FROM OCORRENCIA_SISAT WHERE NU_PROTOCOLO_SISAT = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setLong(1, Long.parseLong(dig));
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next();
            }
        } catch (Exception e) {
            log.warn("valida_protocolo_falha", kv("erro", String.valueOf(e.getMessage())));
            return false;
        }
    }
}
