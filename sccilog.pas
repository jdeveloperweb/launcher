(*$V+*)
(*$H-*)

program sccilog;

uses
  lib1, datalib, pdb, parmlib, uloglib, pxmllib, SysUtils, scciio, xdb;

procedure Help;
begin
  writeln('sccilog -z <LOGON/LOGIN/LOGOUT/LOGOFF/LOGINERR/LOGPASSWD> <USER> <IP> <ORIGEM> [<Session Key>] [-n D(debug)]');
end;

{
procedure WriteLog(st:string);
var f : text;
begin
    assign (f,'/var/log/launcher.log');
    try
      if not FileExists('/var/log/launcher.log') then rewrite(f)
      else  append(f);
      writeln(f,st);
    finally
      close(f);
    end;
end;
}

var
  Xml : TpXml;
  co_aplic : TLogAplic;
  NomeUsuario : string;
  IP : string;
  msglog : string;
  origem : string;
  session_key : string;
  Qry : TSqlQuery;
  Transaction : TTransactionDesc;
begin
  session_key := '';
  if upcase(Parms.Subtipo[1].Tipo) = 'D' then
    LOGInibeErros := false;
  if parms.help then
    help
  else if parms.parmextra[0].tam < 3 then
    raise exception.create('Parâmetros insuficientes')
  else begin
    if (uppercase(Parms.parmextra[1].nome) = 'LOGON') or
       (uppercase(Parms.parmextra[1].nome) = 'LOGIN') then
      co_aplic := logaplic_logon
    else if (uppercase(Parms.parmextra[1].nome) = 'LOGINERR') then 
      co_aplic := logaplic_loginerr
    else if (uppercase(Parms.parmextra[1].nome) = 'LOGOUT') or
            (uppercase(Parms.parmextra[1].nome) = 'LOGOFF') then
      co_aplic := logaplic_logout
    else if (uppercase(Parms.parmextra[1].nome) = 'LOGPASSWD') then
      co_aplic := logaplic_altsenha
    else
      co_aplic := logaplic_NaoDefinido;
    if co_aplic = logaplic_NaoDefinido then
      raise exception.create('Parâmetros inválidos')
    else begin
      Qry   := TSqlQuery.Create(nil);
      try
        NomeUsuario := parms.parmextra[2].nome;
        IP := parms.parmextra[3].nome;
        Origem := parms.parmextra[4].nome;
        if parms.parmextra[5].nome <> '' then session_key := parms.parmextra[5].nome;
        Xml := TpXml.create;
        Qry.SqlConnection := GetSqlConnection(PegaDirTab);
        try
          Xml.documentelement.nodename := 'SCCILOG';
          if co_aplic = logaplic_logon then begin
              if uppercase(Qry.SqlConnection.DriverName) <> 'OPENODBC' then begin
                Transaction.TransactionID := (Random(1000) + 1);
                Transaction.IsolationLevel := xilReadCommitted;
                Qry.SqlConnection.StartTransaction(Transaction);
              end;
              Xml.documentelement.addchild('TIPO').asstring := 'LOGON';
              try
                Qry.sql.add('SELECT USUARIO, DT_VALIDADE_USUARIO FROM USUARIO');
                Qry.sql.add('WHERE UPPER(USUARIO)=:usuario');
                Qry.paramByName('usuario').AsString := UpStr(NomeUsuario);
                Qry.open;
                if not Qry.eof then begin
                  NomeUsuario := Qry.fieldByName('USUARIO').asString;
                  if ((Qry.fieldBYName('DT_VALIDADE_USUARIO').isNull) or 
                     (juliano(DateTimeToData(Qry.fieldByName('DT_VALIDADE_USUARIO').asDateTime)) > juliano(DataH))) then begin
                    Qry.close;
                    Qry.sql.Clear;
                    Qry.sql.add('UPDATE USUARIO SET DT_ULTIMO_ACESSO=:DT_ULTIMO_ACESSO');
                    Qry.sql.add(' WHERE USUARIO=:usuario');
                    Qry.paramByName('DT_ULTIMO_ACESSO').datatype := ftdatetime;
                    Qry.paramByName('usuario').datatype := ftstring;            
                    Qry.paramByName('DT_ULTIMO_ACESSO').AsDateTime := Now();
                    Qry.paramByName('usuario').AsString := NomeUsuario;
                    Qry.ExecSql;
                  end;
                end else
                  Qry.close;

                msglog := 'Usuário '+nomeusuario+' se conectou';
                if uppercase(Qry.SqlConnection.DriverName) <> 'OPENODBC' then
                  Qry.SqlConnection.Commit(Transaction);
              except
                on E: Exception do begin
                  if uppercase(Qry.SqlConnection.DriverName) <> 'OPENODBC' then
                    Qry.SqlConnection.RollBack(Transaction);
                end;
              end;
          end
          else if co_aplic = logaplic_altsenha then begin
              Xml.documentelement.addchild('TIPO').asstring := 'LOGPASSW';
              msglog := 'Usuário '+nomeusuario+' trocou a senha';
          end
          else if co_aplic = logaplic_loginerr then
          begin
              Xml.documentelement.addchild('TIPO').asstring := 'LOGINERR';
              msglog := 'Erro de Login do usuário : '+nomeusuario;
          end
          else begin
            Xml.documentelement.addchild('TIPO').asstring := 'LOGOUT';
            msglog := 'Usuário '+nomeusuario+' se desconectou. ';
          end;
          if Origem = '' then
            msglog := msglog + ' - interface CORP'
          else begin
            msglog := msglog + '-interface ' + Origem;
            Xml.documentElement.addchild('ORIGEM').asstring := Origem;
          end;
          Xml.documentElement.addchild('USUARIO').asstring := nomeusuario;
          Xml.documentElement.addchild('IP').asstring := IP;
          GeraLog(Co_aplic,logseveridade_Aviso,'',nomeusuario,
                  msglog+'-IP:'+IP,
                  '',XML);
          if (co_aplic = logaplic_logout) and (session_key <> '') then EliminaSession_key(Session_Key);
        finally
          Xml.free;
        end;
      finally
        Qry.free;
      end;
    end;
  end;
end.
