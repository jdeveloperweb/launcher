package com.prognum.comum.ambiente;



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

    public Connection abrir(SccDbConfig c, boolean somenteLeitura) throws SQLException {
        String url = montarUrl(c);
        Properties p = new Properties();
        if (c.user() != null) {
            p.setProperty("user", c.user());
        }
        if (c.senha() != null) {
            p.setProperty("password", c.senha());
        }
        Connection conn = DriverManager.getConnection(url, p);
        conn.setReadOnly(somenteLeitura);
        return conn;
    }

    String montarUrl(SccDbConfig c) {
        String host = (c.host() == null) ? "" : c.host().trim();
        String db = c.database() == null ? "" : c.database().trim();
        return switch (c.driver()) {
            case "POSTGRES" -> "jdbc:postgresql://" + hostOu(host, "localhost") + ":5432/" + db;
            case "ORACLE", "ORANET" -> "jdbc:oracle:thin:@" + hostOu(host, "localhost") + ":1521:" + db;
            case "MSSQL" -> "jdbc:sqlserver://" + hostOu(host, "localhost")
                    + ";databaseName=" + db + ";encrypt=false;trustServerCertificate=true";
            // INTERBASE/Firebird: host vazio = fbserver LOCAL (localhost:3050), NAO embedded
            // (embedded exigiria a lib nativa fbclient; o SCCI roda o Firebird server, inclusive p/ .gdb local).
            default -> "jdbc:firebirdsql://" + hostOu(host, "localhost") + ":3050/" + db;
        };
    }

    private static String hostOu(String host, String def) {
        return host.isEmpty() ? def : host;
    }
}
