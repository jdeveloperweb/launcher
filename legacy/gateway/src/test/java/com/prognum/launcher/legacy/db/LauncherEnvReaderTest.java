package com.prognum.launcher.legacy.db;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Parsing do launcherenv.ini com o conteudo REAL do c6bank (scat112934). */
class LauncherEnvReaderTest {

    private final LauncherEnvReader reader = new LauncherEnvReader();

    @Test
    void parse_c6bank_postgres() {
        List<String> ini = List.of(
                "[ENVIRONMENT]",
                "MAXCONN=10",
                "[USERS]",
                "DB=scat112934",
                "DRIVERNAME=POSTGRES",
                "DB_USER=postgres",
                "DB_PASS=wpostgres",
                "#DB_HOSTNAME=localhost",
                "DB_HOSTNAME=10.3.98.200",
                "USERTABLE=usuario",
                "USERFIELD=USUARIO",
                "USERPASSWORD=senha",
                "USERDTVALID=DT_VALIDADE_USUARIO",
                "USERLASTPASS=DT_ULTIMA_TROCA_SENHA",
                "USERMAXPASS=NU_MAX_DIAS_TROCA_SENHA",
                "USERMUSTCHANGE=IN_TROCA_SENHA_PROXIMO_LOGIN",
                "USERMINPASS=NU_MIN_DIAS_TROCA_SENHA");

        SccDbConfig c = reader.parse(ini);

        assertEquals("POSTGRES", c.driver());
        assertEquals("10.3.98.200", c.host());
        assertEquals("scat112934", c.database());
        assertEquals("postgres", c.user());
        assertEquals("wpostgres", c.senha());          // texto puro (sem [..])
        assertEquals("usuario", c.tabela());
        assertEquals("USUARIO", c.campoUsuario());
        assertEquals("senha", c.campoSenha());
        assertEquals("DT_VALIDADE_USUARIO", c.campoDtValidade());
        assertEquals("NU_MAX_DIAS_TROCA_SENHA", c.campoMaxDias());
    }
}
