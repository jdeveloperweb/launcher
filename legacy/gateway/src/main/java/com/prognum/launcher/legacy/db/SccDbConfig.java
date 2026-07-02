package com.prognum.launcher.legacy.db;

/**
 * Conexao + mapeamento de colunas de um ambiente, lido do launcherenv.ini [USERS]
 * (ver launcher.pas TLauncherEnv.LoadDBUsers). Espelha o que o daemon usa.
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
