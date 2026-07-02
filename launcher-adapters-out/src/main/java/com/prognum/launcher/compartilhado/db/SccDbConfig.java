package com.prognum.launcher.compartilhado.db;

/**
 * Configuracao de conexao + colunas de um ambiente (secao [USERS] do launcherenv.ini).
 * Copia fiel do launcher SCCI (legado). 13 campos, na ordem do LauncherEnvReader.
 */
public record SccDbConfig(
        String driver,            // DRIVERNAME: POSTGRES | INTERBASE(Firebird) | ORACLE | MSSQL
        String host,              // DB_HOSTNAME (vazio = local)
        String database,          // DB (nome no Postgres; caminho .gdb no Firebird)
        String user,              // DB_USER
        String senha,             // DB_PASS ja tratada (TrataSenhaEncriptografada)
        String tabela,            // USERTABLE
        String campoUsuario,      // USERFIELD
        String campoSenha,        // USERPASSWORD
        String campoDtValidade,   // USERDTVALID
        String campoUltimaTroca,  // USERLASTPASS
        String campoMaxDias,      // USERMAXPASS
        String campoMinDias,      // USERMINPASS
        String campoMustChange    // USERMUSTCHANGE
) {
}
