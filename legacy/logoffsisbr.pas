(*$V+*)
(*$H-*)

program logoffsisbr;

uses
  parmlib, uloglib, pxmllib, SysUtils, scciio, pdb, xdb, punix, HTTPSend, Classes, pIniFiles, synautil;

procedure Help;
begin
  writeln('logoffsisbr -z <LOGOUT/LOGOFF> <USER> <IP> <ORIGEM> [<Session Key>] [-n D(debug)]');
end;

procedure EncerraSessaoSisbr(SessionKey : AnsiString);
var
  Qry : TSQLQuery;
  HTTP : THTTPSend;
  Data : TMemoryStream;
  xml : TpXml;
  ArqIni : TMemIniFile;
  MsgErro,
  Bearer,
  AccessToken : AnsiString;
begin
  HTTP := THTTPSend.Create;
  Data := TMemoryStream.Create;
  xml := TpXml.create;
  if not FileExists(GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini') then
    raise exception.create('Arquivo de configuração '+GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini inexistente');
  ArqIni := TMemIniFile.Create(GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini');
  Qry := TSQLQuery.Create(nil);
  try
    WriteStrToStream(HTTP.Document, 'grant_type=client_credentials');
    HTTP.MimeType := 'application/x-www-form-urlencoded';
    HTTP.Headers.Add('Authorization: Bearer '+ArqIni.ReadString('ObterTokenSisbr','Authorization',''));
    if HTTP.HTTPMethod('POST', ArqIni.ReadString('ObterTokenSisbr','SERVIDOR','')) then
      Data.CopyFrom(HTTP.Document, 0);
    case HTTP.ResultCode of
      401 : MsgErro := 'Não autorizado, token inválido (401)';
      403 : MsgErro := 'Acesso negado, usuário do token sem permissão (403)';
      404 : MsgErro := 'Servidor respondeu : o endereço acessado não existe (404)';
      429 : MsgErro := 'Servidor respondeu : o usuário atingiu o limite de requisições (429)';
      500 : MsgErro := 'Erro interno nos serviços da Bancoob (500)';
      else
        MsgErro := 'Servidor respondeu com código '+inttostr(HTTP.ResultCode);
    end;
    if Data.size = 0 then
      raise exception.create(MsgErro);
    xml.ParseStream(Data);
    Bearer := xml['access_token'].AsString;
    HTTP.free; 
    Data.free;

    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.SQL.Add('select TOKEN from SCCI_SESSION where SESSION_KEY = '+QuotedStr(SessionKey));
    Qry.open;
    AccessToken := Qry.FieldByName('TOKEN').AsString;
    Qry.close;

    HTTP := THTTPSend.Create;
    Data := TMemoryStream.Create;
    WriteStrToStream(HTTP.Document, 'client_id='+ArqIni.ReadString('ENCERRASESSAOSISBR','client_id',''));
    HTTP.MimeType := 'application/json';
    HTTP.Headers.Add('Authorization: Bearer '+Bearer);
    if HTTP.HTTPMethod('POST', ArqIni.ReadString('ENCERRASESSAOSISBR','SERVIDOR','')+'?accessToken='+AccessToken) then
      Data.CopyFrom(HTTP.Document, 0);
    case HTTP.ResultCode of
      401 : MsgErro := 'Não autorizado, token inválido (401)';
      403 : MsgErro := 'Acesso negado, usuário do token sem permissão (403)';
      404 : MsgErro := 'Servidor respondeu : o endereço acessado não existe (404)';
      429 : MsgErro := 'Servidor respondeu : o usuário atingiu o limite de requisições (429)';
      500 : MsgErro := 'Erro interno nos serviços da Bancoob (500)';
      else
        MsgErro := 'Servidor respondeu com código '+inttostr(HTTP.ResultCode);
    end;
    if (Data.size = 0) and not (HTTP.ResultCode in [200, 201]) then
      raise exception.create(MsgErro)
  finally
    Qry.Sql.Clear;
    Qry.Sql.Add('delete from SCCI_SESSION where SESSION_KEY = '+QuotedStr(SessionKey));
    Qry.ExecSql;
    Qry.close;  
    Qry.free;
  end;
end;

var
  Xml : TpXml;
  co_aplic : TLogAplic;
  NomeUsuario : string;
  IP : string;
  msglog : string;
  origem : string;
  session_key : string;
begin
  session_key := '';
  if upcase(Parms.Subtipo[1].Tipo) = 'D' then
    LOGInibeErros := false;
  if parms.help then
    help
  else if parms.parmextra[0].tam < 3 then
    raise exception.create('Parâmetros insuficientes')
  else begin
    if (uppercase(Parms.parmextra[1].nome) = 'LOGOUT') or (uppercase(Parms.parmextra[1].nome) = 'LOGOFF') then
      co_aplic := logaplic_logout
    else
      co_aplic := logaplic_NaoDefinido;
    if co_aplic = logaplic_NaoDefinido then
      raise exception.create('Parâmetros inválidos')
    else begin
      NomeUsuario := parms.parmextra[2].nome;
      IP := parms.parmextra[3].nome;
      Origem := parms.parmextra[4].nome;
      if parms.parmextra[5].nome <> '' then session_key := parms.parmextra[5].nome;
      Xml := TpXml.create;
      try
        Xml.documentelement.nodename := 'SCCILOG';
        Xml.documentelement.addchild('TIPO').asstring := 'LOGOUT';
        msglog := 'Usuário '+nomeusuario+' se desconectou. ';
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
        if (co_aplic = logaplic_logout) and (session_key <> '') then EncerraSessaoSisbr(Session_Key);
      finally
        Xml.free;
      end;
    end;
  end;
end.
