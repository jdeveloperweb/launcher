program loginsicoob;

uses {$IFDEF FPC} cthreads, {$ENDIF}SysUtils, lib1, pdb, scciio, xdb, parmlib, uloglib, punix, pxmllib, fpjwt, fpjwasha256,
     {HTTPSend,} Classes, {pIniFiles,} pcrypt, synautil, DateUtils, unix, aelib, ssl_openssl, ssl_openssl11, ssl_openssl3;


function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

// function DiretorioWebService : ansistring;
// var
//   Diretorio : ansistring;
// begin
//   Diretorio := GetEnv('SCCIDIRARQS')+PathDelim+'webservice';
//   if not DirectoryExists(Diretorio) then begin
//     Shell('mkdir '+Diretorio);
//     Shell('chmod o+w '+Diretorio);
//   end;
//   Result := Diretorio;
// end;

// function RetornaSequencial : integer;
// var
//   Arq         : ansistring;
//   StSeq       : TStringList;
//   Seq         : integer;
// begin
//   Arq := DiretorioWebService()+PathDelim+'sequencia.txt';
//   StSeq := TStringList.create;
//   try
//     if FileExists(Arq) then begin
//       StSeq.LoadFromFile(Arq);
//       Seq := ValInt(StSeq[0]);
//     end
//     else Seq := 0;
//     inc(Seq);
//     StSeq.clear;
//     StSeq.add(IntStr(Seq));
//     StSeq.SaveToFile(Arq);
//   finally
//     StSeq.free;
//   end;
//   Result := Seq;
// end;

procedure GravaScciSession(SessionKey, Usuario, IP, Login, Access, Refresh : AnsiString; Tempo : Integer);
var
  Qry : TSQLQuery;
  AccessStream,
  RefreshStream : TStringStream;
begin
  Qry := TSQLQuery.Create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);

    Qry.Sql.Add('INSERT INTO SCCI_SESSION (SESSION_KEY, NO_USUARIO, NU_IP_ACESSO, DT_HORA_SOLICITACAO, LOGIN, TOKEN,');
    Qry.Sql.Add('REFRESH_TOKEN, NU_SEGUNDOS_EXPIRACAO) VALUES ('+QuotedStr(SessionKey)+','+QuotedStr(Usuario)+',');
    Qry.Sql.Add(QuotedStr(IP)+',:wdt,'+QuotedStr(Login)+',:ACCESS,:REFRESH,'+IntStr(Tempo)+')');
    
    // DT_HORA_SOLICITACAO
    Qry.ParamByName('wdt').Datatype := ftDateTime;
    Qry.ParamByName('wdt').asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);

    // TOKENS
    AccessStream := TStringStream.create(Access);
    RefreshStream := TStringStream.create(Refresh);
    try
      AccessStream.position := 0;
      Qry.ParamByName('ACCESS').loadfromstream(AccessStream,ftblob);
      RefreshStream.position := 0;
      Qry.ParamByName('REFRESH').loadfromstream(RefreshStream,ftblob);
    finally
      AccessStream.free;
      RefreshStream.free;
    end;

    Qry.ExecSql;
    Qry.close;
  finally
    Qry.free;
  end;
end;

function ExecutaLoginSicoob(var Senha, Usuario, Ent1, Ent2 : AnsiString): boolean;
var
  Qry : TSQLQuery;
  st  : AnsiString;
begin
  result := false;
  st := WebDecrypt(Senha);
  if copy(st,1,5) = '!#___' then begin
    if length(Usuario) > 20 then
      raise exception.create('Nome do usuário ('+Quotedstr(Usuario)+') maior que o máximo permitido');
    
    Qry := TSQLQuery.Create(nil);
    try
      Senha := GeraToken(Usuario, Senha);
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.sql.Add('SELECT USUARIO, ENT_PRIMARIA, ENT_SECUNDARIA FROM USUARIO WHERE UPPER(USUARIO) = '+QuotedStr(UpStr(Usuario)));
      Qry.Open;
      if Qry.Eof then
        raise exception.create('Usuário não está cadastrado no SCCI')
      else begin
        Usuario := Qry.FieldByName('USUARIO').AsString;
        Ent1 := Qry.fieldByName('ENT_PRIMARIA').asString;
        Ent2 := Qry.fieldByName('ENT_SECUNDARIA').asString;
      end;
      result := true;
      Qry.close;
    finally
      Qry.free;
    end;
  end else
    raise exception.create('Senha incorreta');
end;

// function AtualizaSessaoSisbr(SessionKey : AnsiString): TDateTime;
// var
//   Qry : TSQLQuery;
//   HTTP : THTTPSend;
//   Data : TMemoryStream;
//   xml,
//   AtualizaSessao : TpXml;
//   ArqIni : TMemIniFile;
//   MsgErro,
//   Bearer,
//   Servidor,
//   AccessToken,
//   RefreshToken,
//   PayLoadEnvio : AnsiString;
//   DateTime : TDateTime;
//   TempoExpiracao : Integer;
//   AccessStream,
//   RefreshStream : TStringStream;
//   GeraArq : Boolean;
//   i, Seq : Integer;
// begin
//   HTTP := THTTPSend.Create;
//   Data := TMemoryStream.Create;
//   xml := TpXml.create;
//   AtualizaSessao := TpXml.Create;
//   if not FileExists(GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini') then
//     raise exception.create('Arquivo de configuração '+GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini inexistente');
//   ArqIni := TMemIniFile.Create(GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini');
//   Qry := TSQLQuery.Create(nil);
//   try
//     Qry.SqlConnection := GetSqlConnection(PegaDirTab);
//     Qry.SQL.Add('SELECT TOKEN, REFRESH_TOKEN FROM SCCI_SESSION WHERE SESSION_KEY = '+QuotedStr(SessionKey));
//     Qry.open;
//     Bearer       := Qry.FieldByName('TOKEN').AsString;
//     RefreshToken := Qry.FieldByName('REFRESH_TOKEN').AsString;
//     Qry.close;

//     Servidor := ArqIni.ReadString('ATUALIZASESSAOSISBR','SERVIDOR','');
//     if trim(Servidor) = '' then
//       raise exception.create('Não tem o servidor definido no servicoweb.ini');
//     GeraArq := false;
//     if pos(';',Servidor) > 0 then begin
//       if Uppercase(copy(Servidor,1,pos(';',Servidor)-1)) = 'GERAARQUIVOS' then begin
//         GeraArq := true;
//         Seq := RetornaSequencial;
//       end;
//       Servidor := copy(Servidor,pos(';',Servidor)+1,Length(Servidor));
//     end;
    
//     WriteStrToStream(HTTP.Document, 'x');
//     HTTP.Headers.Add('client_id: '+ArqIni.ReadString('ATUALIZASESSAOSISBR','client_id',''));
//     HTTP.Headers.Add('Authorization: Bearer '+Bearer);
//     HTTP.Headers.Add('accept: application/json');
    
//     if GeraArq then begin
//       for i := 0 to HTTP.Headers.count-1 do
//         AtualizaSessao.add('Header_'+IntToStr(i+1)).asstring := HTTP.Headers[i];
//       SetString(PayLoadEnvio, PAnsiChar(HTTP.Document.Memory), HTTP.Document.Size);
//       AtualizaSessao.add('Payload').asstring := PayLoadEnvio;
//       AtualizaSessao.add('Servidor').asstring := Servidor;
//       AtualizaSessao.add('RefreshToken').asstring := RefreshToken;
//       AtualizaSessao.toJsonFile(DiretorioWebService()+PathDelim+'envio_AtualizaSessaoSisbr_'+intstr(Seq)+'.json');
//     end;
    
//     if HTTP.HTTPMethod('POST', Servidor+'?refreshToken='+RefreshToken) then
//       Data.CopyFrom(HTTP.Document, 0);
//     case HTTP.ResultCode of
//       401 : MsgErro := 'Não autorizado, token inválido (401)';
//       403 : MsgErro := 'Acesso negado, usuário do token sem permissão (403)';
//       404 : MsgErro := 'Servidor respondeu : o endereço acessado não existe (404)';
//       429 : MsgErro := 'Servidor respondeu : o usuário atingiu o limite de requisições (429)';
//       500 : MsgErro := 'Erro interno nos serviços do Sicoob(500)';
//       else
//         MsgErro := 'Servidor respondeu com código '+inttostr(HTTP.ResultCode);
//     end;

//     xml.ParseStream(Data);
//     if GeraArq then
//       xml.toJsonFile(DiretorioWebService()+PathDelim+'retorno_AtualizaSessaoSisbr_'+intstr(Seq)+'.json');

//     if (Data.size = 0) or (not (HTTP.ResultCode in [200, 201])) then
//       raise exception.create(MsgErro);
      
//     TempoExpiracao := xml['tempoExpiracao'].AsInteger;
//     AccessToken    := xml['accessToken'].AsString;
//     RefreshToken   := xml['refreshToken'].AsString;
//     DateTime := Now;
    
//     Qry.Sql.Clear;
//     Qry.Sql.Add('UPDATE SCCI_SESSION SET DT_HORA_SOLICITACAO = :wdt, NU_SEGUNDOS_EXPIRACAO = :TEMPO, ');
//     Qry.Sql.Add('TOKEN = :ACCESS, REFRESH_TOKEN = :REFRESH where SESSION_KEY = '+QuotedStr(SessionKey));
//     Qry.Params[0].Datatype := ftDateTime;
//     Qry.Params[0].asSqlTimeStamp := DateTimeToSqlTimeStamp(DateTime);
//     Qry.Params[1].Datatype := ftInteger;
//     Qry.Params[1].asInteger := TempoExpiracao;

//     // TOKENS
//     AccessStream := TStringStream.create(AccessToken);
//     RefreshStream := TStringStream.create(RefreshToken);
//     try
//       AccessStream.position := 0;
//       Qry.ParamByName('ACCESS').loadfromstream(AccessStream,ftblob);
//       RefreshStream.position := 0;
//       Qry.ParamByName('REFRESH').loadfromstream(RefreshStream,ftblob);
//     finally
//       AccessStream.free;
//       RefreshStream.free;
//     end;

//     Qry.ExecSql;
//     Qry.close;
//     result := DateTime;
//   finally
//     HTTP.free;
//     Data.free;
//     xml.free;
//     AtualizaSessao.free;
//     Qry.free;
//   end;
// end;

function ValidaUsuario(var SessionKey, Usuario : AnsiString): String;
var
  Qry : TSqlQuery;
  UltTroca : TDateTime;
  TempoExpiracao : Integer;
  sKey : AnsiString;
begin
    result := 'F';
    Qry := TSQLQuery.Create(nil);
    try
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.sql.add('SELECT NO_USUARIO, SESSION_KEY, DT_HORA_SOLICITACAO,NU_SEGUNDOS_EXPIRACAO');
      Qry.sql.add('FROM SCCI_SESSION WHERE NO_USUARIO=:usuario');
      Qry.sql.add('AND SESSION_KEY LIKE :sKey');
      Qry.paramByName('usuario').asString := usuario;
      Qry.paramByName('sKey').asString := '%'+SessionKey;
      Qry.Open;
      if not Qry.eof then begin
        sKey := Qry.fieldByName('SESSION_KEY').asString;
        UltTroca := Qry.FieldByName('DT_HORA_SOLICITACAO').AsDateTime;
        TempoExpiracao := Qry.FieldByName('NU_SEGUNDOS_EXPIRACAO').AsInteger;
        if (sKey = sessionKey) then begin
          // if (not (Qry.FieldByName('DT_HORA_SOLICITACAO').isNull)) and (now > IncSecond(Ulttroca, TempoExpiracao)) then
          //   Ulttroca := AtualizaSessaoSisbr(SessionKey);
          result := 'T'+FloattoStr(Ulttroca);
        end
        else if (SessionKey = copy(sKey, 5, length(sKey))) then begin
          //sessionKey existe mas é invalida (ACESSOSSIMULTANEOS)
          result := 'E';
          Qry.close;
          Qry.sql.clear;
          Qry.sql.add('DELETE FROM SCCI_SESSION WHERE SESSION_KEY=:sKey');
          Qry.paramByName('sKey').asString := sKey;
          Qry.ExecSql;
        end;
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
end;

function ExecutaValidaBD(var Senha : AnsiString; Usuario : AnsiString; var sessaoExpirada: boolean): boolean;
//Verificar se um token é valido
var
  wsenha : string;
begin
  result := false;
  try
    wsenha := ValidaUsuario(Senha,Usuario);
    if  copy(wsenha,1,1) = 'T' then
    begin
      Senha := copy(wsenha,2,length(wsenha));
      result := true;
    end
    else if copy(wsenha,1,1) = 'E' then
      sessaoExpirada := true
    else begin
      Senha := 'Token Informado para revalidacao e Invalido';
    end;
  finally
  end;
end;

// procedure VerificaIntegridadeDaMensagem(    sign : AnsiString; 
//                                         var Usuario,
//                                             Nome,
//                                             CPF,
//                                             AccessToken,
//                                             RefreshToken : AnsiString;
//                                         var TempoExpiracao : integer);
// var
//   json : tpXmlNode;
//   xml,
//   ObterToken,
//   AtualizaSessao : tpXml;
//   Bearer,
//   MsgErro,
//   PayLoad,
//   Servidor,
//   PayLoadEnvio : AnsiString;
//   HTTP : THTTPSend;
//   Data : TMemoryStream;
//   ArqIni : TMemIniFile;
//   key : TJWTKey;
//   hs256 : TJWTSignerHS256;
//   GeraArq : Boolean;
//   i, Seq : Integer;
// begin
//   json  := TpXmlNode.create(nil);
//   key   := TJWTKey.create(GetEnv('SECRET'));
//   hs256 := TJWTSignerHS256.create;
//   HTTP  := THTTPSend.Create;
//   Data  := TMemoryStream.Create;
//   xml   := TpXml.create;
//   ObterToken     := TpXml.create;
//   AtualizaSessao := TpXml.create;
//   if not FileExists(GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini') then
//     raise exception.create('Arquivo de configuração '+GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini inexistente');
//   ArqIni := TMemIniFile.Create(GetEnv('SCCIDIRARQS')+'/bancoob/servicoweb.ini');
//   try
//     if not hs256.Verify(sign, key) then
//       raise exception.create('Token inválido. Favor efetuar novo login via sistema Sisbr');
//     Servidor := ArqIni.ReadString('ObterTokenSisbr','SERVIDOR','');
//     if trim(Servidor) = '' then
//       raise exception.create('Não tem o servidor definido no servicoweb.ini');
//     GeraArq := false;
//     if pos(';',Servidor) > 0 then begin
//       if Uppercase(copy(Servidor,1,pos(';',Servidor)-1)) = 'GERAARQUIVOS' then begin
//         GeraArq := true;
//         Seq := RetornaSequencial;
//       end;
//       Servidor := copy(Servidor,pos(';',Servidor)+1,Length(Servidor));
//    end;

//     WriteStrToStream(HTTP.Document, 'grant_type=client_credentials');
//     HTTP.MimeType := 'application/x-www-form-urlencoded';
//     HTTP.Headers.Add('Authorization: Bearer '+ArqIni.ReadString('ObterTokenSisbr','Authorization',''));
    
//     if GeraArq then begin
//       for i := 0 to HTTP.Headers.count-1 do
//         ObterToken.add('Header_'+IntToStr(i+1)).asstring := HTTP.Headers[i];
//       SetString(PayLoadEnvio, PAnsiChar(HTTP.Document.Memory), HTTP.Document.Size);
//       ObterToken.add('Payload').asstring := PayLoadEnvio;
//       ObterToken.add('Servidor').asstring := Servidor;
//       ObterToken.toJsonFile(DiretorioWebService()+PathDelim+'envio_ObterTokenSisbr_'+intstr(Seq)+'.json');
//     end;

//     if HTTP.HTTPMethod('POST', Servidor) then
//       Data.CopyFrom(HTTP.Document, 0);
//     case HTTP.ResultCode of
//       401 : MsgErro := 'Não autorizado, token inválido (401)';
//       403 : MsgErro := 'Acesso negado, usuário do token sem permissão (403)';
//       404 : MsgErro := 'Servidor respondeu : o endereço acessado não existe (404)';
//       429 : MsgErro := 'Servidor respondeu : o usuário atingiu o limite de requisições (429)';
//       500 : MsgErro := 'Erro interno nos serviços do Sicoob(500)';
//       else
//         MsgErro := 'Servidor respondeu com código '+inttostr(HTTP.ResultCode);
//     end;

//     xml.ParseStream(Data);
//     if GeraArq then
//       xml.toJsonFile(DiretorioWebService()+PathDelim+'retorno_ObterTokenSisbr_'+intstr(Seq)+'.json');
    
//     if (Data.size = 0) or (not (HTTP.ResultCode in [200, 201])) then
//       raise exception.create(MsgErro);
    
//     Bearer := xml['access_token'].AsString;

//     PayLoad := ExtractWord(2,sign,['.']);
//     json.ParseString(DecodeBase64Url(PayLoad));
//     Payload := json.asstring;
//     json.ParseString(DecodeBase64Url(Payload));

//     Nome := json['nomeCompleto'].asstring;
//     Usuario := json['login'].asstring;
//     CPF := json['numeroCPF'].asstring;
//     AccessToken := json['chaveAcesso']['accessToken'].asstring;
//     RefreshToken := json['chaveAcesso']['refreshToken'].asstring;
//     TempoExpiracao := json['chaveAcesso']['tempoExpiracao'].asinteger;

//     HTTP.free; 
//     Data.free;
//     HTTP := THTTPSend.Create;
//     Data := TMemoryStream.Create;

//     Servidor := ArqIni.ReadString('ATUALIZASESSAOSISBR','SERVIDOR','');
//     if trim(Servidor) = '' then
//       raise exception.create('Não tem o servidor definido no servicoweb.ini');
//     GeraArq := false;
//     if pos(';',Servidor) > 0 then begin
//       if Uppercase(copy(Servidor,1,pos(';',Servidor)-1)) = 'GERAARQUIVOS' then
//         GeraArq := true;
//       Servidor := copy(Servidor,pos(';',Servidor)+1,Length(Servidor));
//    end;

//     WriteStrToStream(HTTP.Document, 'x');
//     HTTP.Headers.Add('client_id: '+ArqIni.ReadString('ATUALIZASESSAOSISBR','client_id',''));
//     HTTP.Headers.Add('Authorization: Bearer '+Bearer);
//     HTTP.Headers.Add('accept: application/json');
    
//     if GeraArq then begin
//       for i := 0 to HTTP.Headers.count-1 do
//         AtualizaSessao.add('Header_'+IntToStr(i+1)).asstring := HTTP.Headers[i];
//       SetString(PayLoadEnvio, PAnsiChar(HTTP.Document.Memory), HTTP.Document.Size);
//       AtualizaSessao.add('Payload').asstring := PayLoadEnvio;
//       AtualizaSessao.add('Servidor').asstring := Servidor;
//       AtualizaSessao.add('RefreshToken').asstring := RefreshToken;
//       AtualizaSessao.toJsonFile(DiretorioWebService()+PathDelim+'envio_AtualizaSessaoSisbr_'+intstr(Seq)+'.json');
//     end;
    
//     if HTTP.HTTPMethod('POST', Servidor+'?refreshToken='+RefreshToken) then
//       Data.CopyFrom(HTTP.Document, 0);
//     case HTTP.ResultCode of
//       401 : MsgErro := 'Não autorizado, token inválido (401)';
//       403 : MsgErro := 'Acesso negado, usuário do token sem permissão (403)';
//       404 : MsgErro := 'Servidor respondeu : o endereço acessado não existe (404)';
//       429 : MsgErro := 'Servidor respondeu : o usuário atingiu o limite de requisições (429)';
//       500 : MsgErro := 'Erro interno nos serviços do Sicoob(500)';
//       else
//         MsgErro := 'Servidor respondeu com código '+inttostr(HTTP.ResultCode);
//     end;
    
//     xml.ParseStream(Data);
//     if GeraArq then
//       xml.toJsonFile(DiretorioWebService()+PathDelim+'retorno_AtualizaSessaoSisbr_'+intstr(Seq)+'.json');
    
//     if (Data.size = 0) or (not (HTTP.ResultCode in [200, 201])) then
//       raise exception.create(MsgErro);
    
//     TempoExpiracao := xml['tempoExpiracao'].AsInteger;
//     AccessToken    := xml['accessToken'].AsString;
//     RefreshToken   := xml['refreshToken'].AsString;
//   finally
//     json.free;
//     hs256.free;
//     HTTP.free;
//     Data.free;
//     xml.free;
//     ObterToken.free;
//     AtualizaSessao.free;
//     ArqIni.free;
//   end;
// end;

function readlv(handle : integer;var st : ansistring): integer;
{$IFDEF LINUX}
var
  bsize : longint;
{$ENDIF}
begin
{$IFDEF LINUX}
  bsize := 0;
  __read(Handle,bsize,4);
  setlength(st,bsize);
  result := __read(Handle,st[1],bSize);
{$ELSE}
  result := 0;
{$ENDIF}
end;

procedure writelv(handle : integer;st : AnsiString);
var wlen, len : longint;
    buf : array [1..1035] of char;
begin
  len := length(st);
  buf[1] := #0;
  if len > 1024 then len := 1024;
  wlen := len;
  move(wlen,buf[1],4 );
  move(st[1],buf[5],len );
{$IFDEF LINUX}
  __write(handle,buf[1],len+4);
  {$IFDEF FPC} fpfsync(Handle);{$ELSE} fsync(Handle); {$ENDIF}
{$ENDIF}
end;

procedure ExtraiToken(Sign: AnsiString; var AccessToken: AnsiString);
var
  xml: TpXml;
begin
  xml := TpXml.create;
  try
    Xml.parseString(Sign);
    accessToken := Xml['token'].asString;
  finally
    Xml.free;
  end;
end;

var
  CanalLeitura,
  CanalEscrita : Integer;
  OpStr,
  Novasenha,
  Servico,
  IdStr,
  Usuario,
  Senha,
  IP,
  CPF,
  sign,
  Nome,
  Login,
  AccessToken,
  RefreshToken,
  Ent1,
  Ent2 : AnsiString;
  QTDMAXLOGIN,
  TempoExpiracao : integer;
  Expirada : boolean;
begin
  Expirada := false;
  NovaSenha := '';
  OpStr := '';
  Servico := '';
  OpStr := '';
  CanalLeitura := 0;
  CanalEscrita := 1;
  QTDMAXLOGIN := 0;
  CPF := '';
  Nome := '';
  AccessToken := '';
  RefreshToken := '';
  TempoExpiracao := 0;
  Ent1 := '';
  Ent2 := '';
  if (Paramcount = 3) then
  try
  // Receber o canal de leitura e escrita nos parâmetros 1-> leitura 2->escrita
    try
      CanalLeitura := strtoint(ParamStr(1));
      CanalEscrita := strtoint(ParamStr(2));
  // Receber o IP como parâmetro 3
      IP := ParamStr(3);
  // Le pelo canal de leitura as variáveis de sistema, serviço e identificação
  // usuario e senha
      if CanalEscrita = 0 then begin // Usado para testes
        Servico := 'SIMULARETORNO:';
        IdStr := '88';
        Usuario := 'supervisor';
        Senha := 'tempo';
      end
      else begin
        readlv(CanalLeitura,Servico);
        readlv(CanalLeitura,IdStr);
        readlv(CanalLeitura,OpStr);
        readlv(CanalLeitura,Usuario);
        readlv(CanalLeitura,Senha);
        readlv(CanalLeitura,NovaSenha);
      end;
      if (trim(Usuario) <> '') then begin
        if OpStr = 'LOGIN' then begin
          sign := copy(WebDecrypt(senha),6,length(WebDecrypt(senha)));
        //   VerificaIntegridadeDaMensagem(sign,Usuario,Nome,CPF,AccessToken,RefreshToken,TempoExpiracao);
          ExtraiToken(sign,AccessToken);
          try if NovaSenha <> '' then QTDMAXLOGIN := strtoint(NovaSenha); except QTDMAXLOGIN := 0; end;
          try
            if ExecutaLoginSicoob(Senha,Usuario,Ent1,Ent2) then begin
              writelv(CanalEscrita,'T'+Senha+':'+Usuario+':SelecionaEnt');
              if QTDMAXLOGIN > 1 then ValidaQtdLogin(QTDMAXLOGIN,Usuario);
              GravaScciSession(Senha,Usuario,IP,Nome,AccessToken,RefreshToken,TempoExpiracao);
            end else raise exception.create('Erro pedindo credenciais');
          except
            on e : exception do begin
              writelv(CanalEscrita,'F'+e.message);
            end;  
          end;
// Para implementar Senha expirada enviar 'E' no lugar do F
        end
        else if OpStr = 'VALIDA' then begin
          if ExecutaValidaBD(Senha,Usuario,Expirada) then
            writelv(CanalEscrita,'T'+Senha)
          else if Expirada then writelv(CanalEscrita,'E'+Senha)
          else writelv(CanalEscrita,'F'+Senha);
        end;
      end
      else writelv(CanalEscrita,'FUsuario não informado');
    // Envia false e mensagem de erro
    except
      on e : exception do begin
//    writelv(CanalEscrita,'FErro de execução no loginoauth: '+E.message+char(13)+' OPSTR '+OpStr+' SERV '+Servico+' USR '+Usuario);
        writelv(CanalEscrita,'F'+E.message+char(13));
      end;
    end;
  // fim se
  finally
{$IFDEF LINUX}
   __close(CanalLeitura);
   __close(CanalEscrita);
{$ENDIF}    
  end
  else system.writeln('Parametros Incorretos');
end.
