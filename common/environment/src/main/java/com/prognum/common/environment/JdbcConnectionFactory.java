package com.prognum.common.environment;



import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.util.Properties;

/**
 * Abre conexao JDBC conforme o DRIVERNAME do launcherenv.ini (igual ao DBINIT do launcher.pas:
 * INTERBASE=Firebird, POSTGRES, ORACLE, MSSQL). Copia fiel do launcher SCCI (legado).
 */
public class JdbcConnectionFactory {

    public Connection abrir(SccDbConfig c) throws SQLException {
        return abrir(c, true);
    }

    /** Diretorio default do tnsnames.ora (fallback do OCI e do SCCI); sobrescrevivel por env TNS_ADMIN. */
    private static final String TNS_ADMIN_PADRAO = "/etc";

    public Connection abrir(SccDbConfig c, boolean somenteLeitura) throws SQLException {
        String url = montarUrl(c);
        Properties p = new Properties();
        if (c.user() != null) {
            p.setProperty("user", c.user());
        }
        if (c.senha() != null) {
            p.setProperty("password", c.senha());
        }
        // Oracle por ALIAS TNS (ex.: DB=11g): o driver thin (Java puro) precisa saber onde esta o
        // tnsnames.ora para resolver o alias. O OCI do legado cai no fallback /etc; o thin NAO herda
        // TNS_ADMIN do ambiente, entao setamos explicitamente (aponta pro MESMO tnsnames.ora do legado).
        if (ehOracle(c.driver()) && ehAliasTns(c)) {
            p.setProperty("oracle.net.tns_admin", tnsAdmin());
        }
        Connection conn = DriverManager.getConnection(url, p);
        conn.setReadOnly(somenteLeitura);
        return conn;
    }

    String montarUrl(SccDbConfig c) {
        String host = (c.host() == null) ? "" : c.host().trim();
        String db = c.database() == null ? "" : c.database().trim();
        return switch (c.driver()) {
            // stringtype=unspecified: params String se comportam como LITERAL (o PG coage pro tipo da
            // coluna), igual ao Pascal (QuotedStr). Sem isso, "integer = character varying" nas comparacoes
            // numericas bindadas como texto (nu_pretendente/nu_documento). Firebird/Oracle ja coagem.
            case "POSTGRES" -> "jdbc:postgresql://" + hostOu(host, "localhost") + ":5432/" + db
                    + "?stringtype=unspecified";
            case "ORACLE", "ORANET" -> urlOracle(host, db);
            case "MSSQL" -> "jdbc:sqlserver://" + hostOu(host, "localhost")
                    + ";databaseName=" + db + ";encrypt=false;trustServerCertificate=true";
            // INTERBASE/Firebird: host vazio = fbserver LOCAL (localhost:3050), NAO embedded
            // (embedded exigiria a lib nativa fbclient; o SCCI roda o Firebird server, inclusive p/ .gdb local).
            default -> "jdbc:firebirdsql://" + hostOu(host, "localhost") + ":3050/" + db;
        };
    }

    /**
     * URL do driver thin (Java puro) para Oracle. No SCCI o launcherenv.ini configura Oracle de duas
     * formas — refletindo como o OCI do legado (DBINIT) conecta:
     * <ul>
     *   <li><b>Sem DB_HOSTNAME</b> (ex.: {@code DB=11g}): {@code DB} e um ALIAS TNS (ou um descriptor
     *       completo). Deixa o driver resolver pelo tnsnames.ora — {@code @<alias>}. Fiel ao OCI, que
     *       le o mesmo tnsnames; trocar host/versao/servico fica no tnsnames, sem mexer no codigo.</li>
     *   <li><b>Com DB_HOSTNAME</b>: EZConnect com SERVICE_NAME — {@code @//host:porta/servico}. Porta
     *       vem de {@code host:porta} no DB_HOSTNAME, ou 1521 por default. (O formato antigo {@code :SID}
     *       de dois-pontos quebra em Oracle que registra por SERVICE_NAME — ORA-12505.)</li>
     * </ul>
     */
    private static String urlOracle(String host, String db) {
        if (host.isEmpty()) {
            return "jdbc:oracle:thin:@" + db;   // alias TNS ou descriptor -> resolve via tnsnames.ora
        }
        int idx = host.indexOf(':');
        String h = (idx < 0) ? host : host.substring(0, idx);
        String porta = (idx < 0) ? "1521" : host.substring(idx + 1).trim();
        return "jdbc:oracle:thin:@//" + h + ":" + porta + "/" + db;
    }

    private static boolean ehOracle(String driver) {
        return "ORACLE".equals(driver) || "ORANET".equals(driver);
    }

    /** Alias TNS = sem host e {@code DB} e um nome simples (nao EZConnect, nao descriptor). */
    private static boolean ehAliasTns(SccDbConfig c) {
        String host = (c.host() == null) ? "" : c.host().trim();
        String db = (c.database() == null) ? "" : c.database().trim();
        return host.isEmpty() && !db.isEmpty()
                && db.indexOf('(') < 0 && db.indexOf('/') < 0 && db.indexOf(':') < 0;
    }

    /** Onde esta o tnsnames.ora: env TNS_ADMIN se definido, senao /etc (fallback do OCI/SCCI). */
    private static String tnsAdmin() {
        String v = System.getenv("TNS_ADMIN");
        return (v == null || v.isBlank()) ? TNS_ADMIN_PADRAO : v.trim();
    }

    private static String hostOu(String host, String def) {
        return host.isEmpty() ? def : host;
    }
}
