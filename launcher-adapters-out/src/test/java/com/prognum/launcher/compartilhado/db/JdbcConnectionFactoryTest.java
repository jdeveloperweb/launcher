package com.prognum.launcher.compartilhado.db;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/** Evidência do multi-banco: a URL JDBC certa por DRIVERNAME (Postgres/Oracle/MSSQL/Firebird). */
class JdbcConnectionFactoryTest {

    private final JdbcConnectionFactory f = new JdbcConnectionFactory();

    private static SccDbConfig cfg(String driver, String host, String db) {
        return new SccDbConfig(driver, host, db, null, null, null, null, null, null, null, null, null, null);
    }

    @Test
    void postgres() {
        assertThat(f.montarUrl(cfg("POSTGRES", "10.3.98.200", "scat112934")))
                .isEqualTo("jdbc:postgresql://10.3.98.200:5432/scat112934");
    }

    @Test
    void oracle() {
        assertThat(f.montarUrl(cfg("ORACLE", "dbhost", "ORCL")))
                .isEqualTo("jdbc:oracle:thin:@dbhost:1521:ORCL");
    }

    @Test
    void sqlserver() {
        assertThat(f.montarUrl(cfg("MSSQL", "dbhost", "scci")))
                .isEqualTo("jdbc:sqlserver://dbhost;databaseName=scci;encrypt=false;trustServerCertificate=true");
    }

    @Test
    void firebird_remoto_e_embedded() {
        assertThat(f.montarUrl(cfg("INTERBASE", "dbhost", "/u/dados/base.gdb")))
                .isEqualTo("jdbc:firebirdsql://dbhost:3050//u/dados/base.gdb");
        assertThat(f.montarUrl(cfg("INTERBASE", "", "/u/dados/base.gdb")))   // host vazio = arquivo local
                .isEqualTo("jdbc:firebirdsql:embedded:/u/dados/base.gdb");
    }

    @Test
    void host_vazio_vira_localhost_no_postgres() {
        assertThat(f.montarUrl(cfg("POSTGRES", "", "db")))
                .isEqualTo("jdbc:postgresql://localhost:5432/db");
    }
}
