package com.prognum.launcher.autenticacao.scc;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.prognum.launcher.autenticacao.mapeado.NovoUsuario;
import com.prognum.launcher.autenticacao.mapeado.UsuarioScci;
import com.prognum.launcher.autenticacao.port.out.ProvisionamentoUsuario;
import com.prognum.launcher.compartilhado.db.JdbcConnectionFactory;
import com.prognum.launcher.compartilhado.db.LauncherEnvReader;
import com.prognum.launcher.compartilhado.db.SccDbConfig;

/**
 * Adapter de saída do PROVISIONAMENTO dos logins payload-mapeado (família B). Porte fiel dos acessos a
 * banco dos loginXXX.pas (USUARIO/PERFIL/ENTIDADES/ENTIDADE_SCCI/PERFIL_SETOR/CADMUT) contra a base do
 * ambiente (launcherenv.ini). Queries ANSI-standard/parametrizadas => multi-banco; o único ponto
 * dependente de driver é o generator do UIDUSUARIO ({@link #proximoUid}), tratado por DRIVERNAME.
 */
@Component
public class SccProvisionamentoRepository implements ProvisionamentoUsuario {

    private static final Logger log = LoggerFactory.getLogger(SccProvisionamentoRepository.class);

    private final LauncherEnvReader env;
    private final JdbcConnectionFactory connections;

    public SccProvisionamentoRepository(LauncherEnvReader env, JdbcConnectionFactory connections) {
        this.env = env;
        this.connections = connections;
    }

    // ---- PERFIL ----

    @Override
    public Optional<Integer> perfilPorNome(String nomePerfil, boolean exato, String ambiente) {
        String sql = exato
                ? "SELECT COD_PERFIL FROM PERFIL WHERE NOME_PERFIL = ?"
                : "SELECT COD_PERFIL FROM PERFIL WHERE UPPER(NOME_PERFIL) = UPPER(?)";
        return umInteiro(ambiente, sql, nomePerfil);
    }

    @Override
    public boolean perfilExiste(int codPerfil, String ambiente) {
        return existe(ambiente, "SELECT COD_PERFIL FROM PERFIL WHERE COD_PERFIL = ?", codPerfil);
    }

    // ---- USUARIO ----

    @Override
    public Optional<UsuarioScci> buscarPorUsuario(String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT U.USUARIO, U.PERF_PRIMARIO, P.NOME_PERFIL, U.NO_AUTENTICACAO_AD "
                + "FROM USUARIO U LEFT JOIN PERFIL P ON P.COD_PERFIL = U.PERF_PRIMARIO "
                + "WHERE UPPER(U.USUARIO) = UPPER(?)";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                Integer perf = rs.getInt("PERF_PRIMARIO");
                if (rs.wasNull()) {
                    perf = null;
                }
                return Optional.of(new UsuarioScci(rs.getString("USUARIO"), perf,
                        rs.getString("NOME_PERFIL"), rs.getString("NO_AUTENTICACAO_AD")));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao buscar usuario no ambiente " + c.host() + "/" + c.database(), e);
        }
    }

    @Override
    public Optional<UsuarioScci> buscarPorUsuarioOuEmail(String usuario, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT USUARIO FROM USUARIO WHERE USUARIO = ? OR NO_E_MAIL_EMISSAO = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            ps.setString(2, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return Optional.empty();
                }
                return Optional.of(new UsuarioScci(rs.getString("USUARIO"), null, null, null));
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao buscar usuario/email no ambiente " + c.database(), e);
        }
    }

    @Override
    public void atualizarPerfil(String usuario, int codPerfil, String ambiente) {
        executar(ambiente, "UPDATE USUARIO SET PERF_PRIMARIO = ? WHERE USUARIO = ?", codPerfil, usuario);
    }

    @Override
    public void atualizarEmailAd(String usuario, String emailAd, String ambiente) {
        executar(ambiente, "UPDATE USUARIO SET NO_AUTENTICACAO_AD = ? WHERE USUARIO = ?", emailAd, usuario);
    }

    @Override
    public void atualizarProvisao(String usuario, int perfPrimario, int entPrimaria, String coSetor,
                                  String nome, String ambiente) {
        executar(ambiente,
                "UPDATE USUARIO SET PERF_PRIMARIO = ?, ENT_PRIMARIA = ?, ALT_USUARIO = 'automatico', "
                        + "ALT_DATA = ?, CO_SETOR = ?, NOME = ? WHERE USUARIO = ?",
                perfPrimario, entPrimaria, Timestamp.valueOf(LocalDateTime.now()), coSetor, nome, usuario);
    }

    @Override
    public void inserir(NovoUsuario novo, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        List<String> cols = new ArrayList<>();
        List<Object> vals = new ArrayList<>();
        cols.add("USUARIO");                vals.add(novo.usuario());
        cols.add("PERF_PRIMARIO");          vals.add(novo.perfPrimario());
        cols.add("ENT_PRIMARIA");           vals.add(novo.entPrimaria());
        if (novo.entSecundaria() != null) {
            cols.add("ENT_SECUNDARIA");     vals.add(novo.entSecundaria());
        }
        cols.add("ALT_USUARIO");            vals.add("automatico");
        cols.add("ALT_DATA");               vals.add(Timestamp.valueOf(LocalDateTime.now()));
        if (novo.senhaToken() != null) {
            cols.add("SENHA");              vals.add(novo.senhaToken());
        }
        cols.add("CO_SETOR");               vals.add(novo.coSetor());
        cols.add("NOME");                   vals.add(novo.nome());
        if (novo.noAutenticacaoAd() != null) {
            cols.add("NO_AUTENTICACAO_AD"); vals.add(novo.noAutenticacaoAd());
        }
        try (Connection conn = connections.abrir(c)) {
            cols.add("UIDUSUARIO");         vals.add(proximoUid(c, conn));
            StringBuilder sql = new StringBuilder("INSERT INTO USUARIO (").append(String.join(", ", cols))
                    .append(") VALUES (").append("?, ".repeat(cols.size() - 1)).append("?)");
            try (PreparedStatement ps = conn.prepareStatement(sql.toString())) {
                aplicarParametros(ps, vals);
                ps.executeUpdate();
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao inserir usuario no ambiente " + c.database(), e);
        }
    }

    // ---- ENTIDADE / SETOR ----

    @Override
    public int entidadeDefault(String ambiente) {
        String v = entidadeUsuarioDefault(ambiente);
        if (v.isBlank()) {
            throw new IllegalStateException("ENTIDADEUSUARIODEFAULT ausente no launcherenv.ini");
        }
        if (ehNumerico(v)) {
            return Integer.parseInt(v);
        }
        // não-numérica: resolve por NOME em ENTIDADES (fiel ao loginc6)
        return umInteiro(ambiente, "SELECT COD_ENT FROM ENTIDADES WHERE NOME = ?", v)
                .orElseThrow(() -> new IllegalStateException("Nao foi possivel obter o codigo da entidade."));
    }

    @Override
    public int entidadeDefaultOuMenos1(String ambiente) {
        String v = entidadeUsuarioDefault(ambiente);
        if (v.isBlank()) {
            return -1;
        }
        if (!ehNumerico(v)) {
            throw new IllegalStateException("ENTIDADEUSUARIODEFAULT configurado errado");
        }
        return Integer.parseInt(v);
    }

    @Override
    public boolean entidadeExiste(int codEnt, String ambiente) {
        return existe(ambiente, "SELECT COD_ENT FROM ENTIDADES WHERE COD_ENT = ?", codEnt);
    }

    @Override
    public int entidadePorEntidadeLogin(String coEntidadeLogin, String ambiente) {
        return umInteiro(ambiente,
                "SELECT CO_ENTIDADE FROM ENTIDADE_SCCI WHERE CO_ENTIDADELOGIN = ?", coEntidadeLogin)
                .orElse(-1);
    }

    @Override
    public String obterSetor(int codPerfil, int codEntidade, String ambiente) {
        SccDbConfig c = env.ler(ambiente);
        String sql = "SELECT CO_SETOR FROM PERFIL_SETOR WHERE CO_PERFIL = ? AND CO_ENT = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setInt(1, codPerfil);
            ps.setInt(2, codEntidade);
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? nz(rs.getString(1)) : "";
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao obter setor no ambiente " + c.database(), e);
        }
    }

    // ---- checagens específicas ----

    @Override
    public boolean usuarioSubordinadoAEntidade(String usuario, String entidadeInformada, String ambiente) {
        if (entidadeInformada == null || entidadeInformada.isBlank()) {
            return true;   // sem entidade informada => sem crítica (fiel ao legado)
        }
        int alvo;
        try {
            alvo = Integer.parseInt(entidadeInformada.trim());
        } catch (NumberFormatException e) {
            return false;
        }
        SccDbConfig c = env.ler(ambiente);
        // caso-base fiel: usuário pertence (primária/secundária) à entidade informada.
        // NOTA: a subordinação TRANSITIVA (EntidadeSubordinadaAEntidade do sccilib, hierarquia de
        // ENTIDADES) ainda não está portada — validar antes do go-live do unicred p/ usuários cuja
        // entidade informada seja ANCESTRAL (não a própria). Ver docs/ANALISE-LEGADO.md.
        String sql = "SELECT ENT_PRIMARIA, ENT_SECUNDARIA FROM USUARIO WHERE USUARIO = ? OR NO_E_MAIL_EMISSAO = ?";
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            ps.setString(1, usuario);
            ps.setString(2, usuario);
            try (ResultSet rs = ps.executeQuery()) {
                if (!rs.next()) {
                    return false;
                }
                int prim = rs.getInt("ENT_PRIMARIA");
                int sec = rs.getInt("ENT_SECUNDARIA");
                boolean direto = prim == alvo || sec == alvo;
                if (!direto) {
                    log.warn("unicred_subordinacao_transitiva_nao_portada usuario={} entidade={}", usuario, alvo);
                }
                return direto;
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha ao checar subordinacao no ambiente " + c.database(), e);
        }
    }

    @Override
    public boolean existeContratoCpf(String cpf, String ambiente) {
        return existe(ambiente, "SELECT CO_CONTRATO FROM CADMUT WHERE CAD_CPF = ?", cpf);
    }

    // ---- generator do UIDUSUARIO (único ponto dependente de driver) ----

    private int proximoUid(SccDbConfig c, Connection conn) throws Exception {
        String driver = c.driver() == null ? "" : c.driver().toUpperCase();
        String sql = switch (driver) {
            case "POSTGRES" -> "SELECT nextval('GEN_UID_USUARIO')";
            case "ORACLE", "ORANET" -> "SELECT GEN_UID_USUARIO.NEXTVAL FROM DUAL";
            case "MSSQL" -> "SELECT NEXT VALUE FOR GEN_UID_USUARIO";
            case "INTERBASE" -> "SELECT GEN_ID(GEN_UID_USUARIO, 1) FROM RDB$DATABASE";
            default -> null;
        };
        if (sql == null) {
            log.warn("gen_uid_fallback_max driver={}", driver);   // fallback portável (não concorrente)
            sql = "SELECT COALESCE(MAX(UIDUSUARIO), 0) + 1 FROM USUARIO";
        }
        try (PreparedStatement ps = conn.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {
            return rs.next() ? rs.getInt(1) : 1;
        }
    }

    // ---- helpers ----

    private String entidadeUsuarioDefault(String ambiente) {
        return nz(env.ambienteEnv(ambiente, "").get("ENTIDADEUSUARIODEFAULT")).trim();
    }

    private Optional<Integer> umInteiro(String ambiente, String sql, Object param) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            aplicarParametros(ps, List.of(param));
            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() ? Optional.of(rs.getInt(1)) : Optional.empty();
            }
        } catch (Exception e) {
            throw new IllegalStateException("falha em consulta no ambiente " + c.database(), e);
        }
    }

    private boolean existe(String ambiente, String sql, Object param) {
        return umInteiro(ambiente, sql, param).isPresent();
    }

    private void executar(String ambiente, String sql, Object... params) {
        SccDbConfig c = env.ler(ambiente);
        try (Connection conn = connections.abrir(c);
             PreparedStatement ps = conn.prepareStatement(sql)) {
            aplicarParametros(ps, List.of(params));
            ps.executeUpdate();
        } catch (Exception e) {
            throw new IllegalStateException("falha em update no ambiente " + c.database(), e);
        }
    }

    private static void aplicarParametros(PreparedStatement ps, List<Object> vals) throws java.sql.SQLException {
        for (int i = 0; i < vals.size(); i++) {
            Object v = vals.get(i);
            int idx = i + 1;
            if (v instanceof Integer n) {
                ps.setInt(idx, n);
            } else if (v instanceof Timestamp t) {
                ps.setTimestamp(idx, t);
            } else {
                ps.setString(idx, v == null ? null : v.toString());
            }
        }
    }

    private static boolean ehNumerico(String s) {
        if (s == null || s.isBlank()) {
            return false;
        }
        for (int i = 0; i < s.length(); i++) {
            if (!Character.isDigit(s.charAt(i))) {
                return false;
            }
        }
        return true;
    }

    private static String nz(String s) {
        return s == null ? "" : s;
    }
}
