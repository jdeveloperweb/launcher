
program loginbanese;

uses
{$IFDEF LINUX}
{$IFDEF FPC}
  unix,
{$ELSE}
  Libc,
{$ENDIF}
{$ENDIF}
  SysUtils, Classes, lib1, segurancabaneselib, {$IFNDEF FPC}SOAPHTTPClient,{$ENDIF}bdlib,
{$IFDEF LINUX}
  ssl_openssl, ssl_openssl11, ssl_openssl3,
{$ELSE}
  Rio,
{$ENDIF}
  xdb, pdb,scciio, punix,pxmllib,uloglib, aelib;



type
  tobj = class
        procedure OnBeforeExecute(const pMethodName: AnsiString; var SOAPRequest: WideString);
        procedure OnAfterExecute(const pMethodName: AnsiString; SOAPResponse: TStream);
      end;

var 
  Expirada : boolean;
  Contador: Integer;
  obj : tobj;

function GetSegurancaNetServiceSoap(URL:AnsiString; GeraArquivos:Boolean): SegurancaNetServiceSoap;
var
{$IFDEF FPC}
  RIO: ObjSegurancaNetServiceSoap;
{$ELSE}
  RIO: THTTPRIO;
{$ENDIF}
begin
  Result := nil;
{$IFDEF FPC}
  RIO := ObjSegurancaNetServiceSoap.Create(nil);
{$ELSE}
  RIO := THTTPRIO.Create(nil);
{$ENDIF}
  try
    RIO.URL := URL;
    if GeraArquivos then
    begin 
      RIO.OnBeforeExecute := {$IFDEF FPC}@{$ENDIF}obj.OnBeforeExecute;
      Rio.OnAfterExecute := {$IFDEF FPC}@{$ENDIF}obj.OnAfterExecute;
    end;
    Result := (RIO as SegurancaNetServiceSoap);
  finally
    if Result = nil then
      RIO.Free;
  end;
end;

procedure TObj.OnAfterExecute(const pMethodName: AnsiString; SOAPResponse: TStream);
var
  FileStream:TFileStream;
begin
  SOAPResponse.Position := 0;
  FileStream := TFileStream.Create(PegaDirAtv+'/webservice/retorno_'+inttostr(contador)+'.xml',fmOpenWrite);
  try
    FileStream.CopyFrom(SOAPResponse, SOAPResponse.Size);
  finally
    FileStream.free;
    SOAPResponse.Position := 0;
  end;
end;

procedure Tobj.OnBeforeExecute(const pMethodName: AnsiString; var SOAPRequest: WideString);
var
  f: Text;
begin 
  inc(Contador);
  assign(f,PegaDirAtv+'/webservice/envio_'+inttostr(Contador)+'.xml');
  rewrite(f);
  try
    writeln(f,SOAPRequest);
  finally
    close(f);
  end;
end;

procedure LimpaPerm(Conn : TSQLConnection; Usuario : AnsiString);
var
  QRY : TSQLQuery;
begin
  QRY := TSQLQuery.Create(nil);
  try
    Qry.SqlConnection := Conn;
    Qry.SQL.Add('delete from usuario_funcao where usuario = '+QuotedStr(Usuario));
    Qry.ExecSQL;
    Qry.Close;
  finally
    Qry.Free;
  end;
end;

procedure TestaUsuario(Conn : TSQLConnection; var usuario: AnsiString;Entidade : AnsiString);
var
  Qry : TSqlQuery;
begin
    QRY := TSQLQuery.Create(nil);
    try
      Qry.SqlConnection := Conn;
      Qry.SQL.Add('select usuario from usuario where usuario = '+QuotedStr(usuario));
      Qry.Open;
      if Qry.Eof then
      begin
        Qry.Close;
        Qry.Sql.Clear;
        Qry.SQL.Add( 'insert into usuario ('+
                     ' usuario,perf_primario,perf_secundario,ent_primaria,alt_usuario,uidusuario )  values ('+
                     QuotedStr(usuario)+',0,0,'+QuotedStr(Entidade)+',''Automatico'','+quotedstr(inttostr(LeGenerator(Conn,'GEN_UID_USUARIO')))+')');
        Qry.ExecSQL;
        //rshell('mkdir $HOME');
{$IFDEF LINUX}
        CreateDir(getenv('HOME'));
{$ELSE}
        CreateDir(GetEnvironmentVariable('HOME'));
	
{$ENDIF}		
      end 
      else { usuario existe - limpa perfis }
      begin
        Qry.Close;
        Qry.Sql.Clear;
        Qry.SQL.Add( 'update usuario set perf_primario = 0 ,perf_secundario = 0, ent_primaria = '+QuotedStr(Entidade)+', alt_usuario = ''Automatico'' where usuario = '+QuotedStr(usuario));
        Qry.ExecSQL;
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
end;

procedure GravaPerm(QRY : TSQLQuery; var usuario: AnsiString; codigo : integer);
begin
  if not ( Codigo in [9{,13}] ) then 
  begin
      Qry.ParamByName('usuario').AsString := usuario;
      Qry.ParamByName('codigo').AsInteger := codigo;
      try
        Qry.ExecSQL;
      except
        // ignorar qualquer permissão inexistente, enviada pelo serviço - sol.77738
      end;
  end;
end;
 	 
procedure ExecutaModoTeste(
                        Identificacao : Integer; 
                        Usuario,
                        Senha, 
                        IP:String;
                    var LoginOk:Boolean; 
                    var ResultStr: AnsiString;
                    var CodigoIdentificacaoAcesso : AnsiString);
var 
  p: TpXmlNode;
  xml: TpXml;
begin 
  xml := TpXml.Create;
  try
    xml.XMLParseFile(PegaDirAtv+'/webservice/retorno_TransEfetuarLoginWebService.xml');
    p := xml.DocumentElement['soap:Body']['TransEfetuarLoginWebServiceResponse'];
    LoginOK := p['TransEfetuarLoginWebServiceResult'].AsString = 'true';
    ResultStr := p['resultado'].AsString;
    CodigoIdentificacaoAcesso := p['codigoIdentificacaoAcesso'].AsString;
  finally
    xml.free;
  end;
end;

procedure ExecutaModoTestePasswd(
                        Usuario,
                        Senha,
                        NovaSenha:String;
                    var PasswdOk:Boolean;
                    var ResultStr: AnsiString);
var
  p: TpXmlNode;
  xml: TpXml;
begin
  xml := TpXml.Create;
  try
    xml.XMLParseFile(PegaDirAtv+'/webservice/retorno_TransMudarSenha.xml');
    p := xml.DocumentElement['soap:Body']['TransMudarSenha'];
    PasswdOK := p['TransMudarSenhaResult'].AsString = 'true';
    ResultStr := p['resultado'].AsString;
  finally
    xml.free;
  end;
end;

function ExecutaModoTesteExpirada(CodigoIdentificacaoAcesso:AnsiString):boolean;
var
  p: TpXmlNode;
  xml: TpXml;
begin
  xml := TpXml.Create;
  try
    xml.XMLParseFile(PegaDirAtv+'/webservice/retorno_TransVerificarSenhaExpirada.xml');
    p := xml.DocumentElement['soap:Body']['TransVerificarSenhaExpiradaResponse'];
    result := p['TransVerificarSenhaExpiradaResult'].AsString = 'true';
  finally
    xml.free;
  end;
end;


function ExecutaModoTesteObterAgenciaUsuario(CodigoIdentificacaoAcesso:AnsiString):integer;
var
  p: TpXmlNode;
  xml: TpXml;
begin
  {$IFDEF FPC}
  result := 0;
  {$ENDIF}
  xml := TpXml.Create;
  try
    xml.XMLParseFile(PegaDirAtv+'/webservice/retorno_TransObterAgenciaUsuario.xml');
    p := xml.DocumentElement['soap:Body']['TransObterAgenciaUsuarioResponse'];
    result := StrtoInt(p['TransObterAgenciaUsuarioResponse'].AsString) ;
  finally
    xml.free;
  end;
end;

function PegaPermissoesModoTeste:ArrayOfEntInterface;
var
  p: TpXmlNode;
  xml: TpXml;
  i: integer;
begin
  result := nil;
  xml := TpXml.Create;
  try
    xml.XMLParseFile(PegaDirAtv+'/webservice/retorno_TransObterPermissoes.xml');
    p := xml.DocumentElement['soap:Body']['TransObterPermissoesResponse']
             ['TransObterPermissoesResult'];
    setlength(Result,p.count);
    for i := 0 to p.count-1 do
    begin
      Result[i] := EntInterface.Create;
      Result[i].CodigoInterface := p[i]['CodigoInterface'].AsInteger;
      Result[i].DescricaoInterface := p[i]['DescricaoInterface'].AsString;
    end;
  finally
    xml.free;
  end;
end;

function ExecutaPasswdBanese(Servico,Usuario : AnsiString;
                            Senha,NovaSenha : AnsiString;
                            ModoTeste:Boolean;
                            ModoGeraArquivos:Boolean): boolean;
var
  RIO : SegurancaNetServiceSoap;
  PasswdOk : boolean;
  ResultStr:AnsiString;
begin
  ResultStr := '';
  Passwdok := false;
  if ModoTeste then
  begin
     ExecutaModoTestePasswd(Usuario,Senha,NovaSenha,
                            Passwdok, ResultStr);
     obj := nil;
  end
  else
  begin
    obj := tobj.create;
    RIO := GetSegurancaNetServiceSoap(Servico,ModoGeraArquivos);
    RIO.TransMudarSenha(Usuario,Senha,NovaSenha,
                                Passwdok, ResultStr);
  end;
  FreeAndNil(obj);
  result :=  PasswdOk ;
end;

function ExecutaLoginBanese(Servico:AnsiString; 
                            Identificacao : integer;
                            IP,Usuario : AnsiString;
                            var Senha : AnsiString;
                            ModoTeste:Boolean;
                            ModoGeraArquivos:Boolean;
                        var Expirada : boolean): boolean;
var
  Conn : TSQLConnection;
  QRY : TSQLQuery;
  RIO : SegurancaNetServiceSoap;
  LoginOk : boolean;
  Entidade,
  ResultStr:AnsiString;
  codigoIdentificacaoAcesso: AnsiString;
  ArrayOfEntInterface1: ArrayOfEntInterface;
  i : integer;
begin
  ResultStr := '';
  codigoIdentificacaoAcesso := '';
  ArrayOfEntInterface1 := nil;
  LoginOk := false;
  Expirada := false;
  Entidade := '1';
  Conn := GetSqlConnection(PegaDirTab);
  if ModoTeste then 
  begin
    ExecutaModoTeste(Identificacao,Usuario,Senha,IP,
                            LoginOk, ResultStr, CodigoIdentificacaoAcesso);
    if LoginOK then Expirada := ExecutaModoTesteExpirada(CodigoIdentificacaoAcesso);
    Entidade := IntToStr(ExecutaModoTesteObterAgenciaUsuario(CodigoIdentificacaoAcesso));
    obj := nil;
  end
  else 
  begin
    obj := tobj.create;
    RIO := GetSegurancaNetServiceSoap(Servico,ModoGeraArquivos);
    RIO.TransEfetuarLoginWebService(Identificacao,Usuario,Senha, IP, 
                                LoginOk, ResultStr, CodigoIdentificacaoAcesso);
    if LoginOK then Expirada := RIO.TransVerificarSenhaExpirada(CodigoIdentificacaoAcesso);
    Entidade := IntToStr(RIO.TransObterAgenciaUsuario(CodigoIdentificacaoAcesso));
  end;
  if LoginOk and not Expirada then
  begin
    result := true;
    Senha := CodigoIdentificacaoAcesso;
    if ModoTeste then
      ArrayOfEntInterface1 := PegaPermissoesModoTeste
    else
      ArrayOfEntInterface1 := RIO.TransObterPermissoes(codigoIdentificacaoAcesso,1);
    TestaUsuario(Conn,Usuario,Entidade);
    LimpaPerm(Conn,Usuario);
    QRY := TSQLQuery.Create(nil);
    try
      Qry.SqlConnection := Conn;
      Qry.SQL.Add('insert into usuario_funcao (Usuario,Codigo,tipo) values (:usuario,:codigo,''A'')');
      Qry.params[0].AsString := ''; // Para color os parametros para Oracle
      Qry.params[1].AsInteger := 0; 
      Qry.Prepared := true;
      for i := low(ArrayOfEntInterface1) to high(ArrayOfEntInterface1) do
      begin
        GravaPerm(Qry,Usuario,ArrayOfEntInterface1[i].CodigoInterface);
        {$IFDEF FPC}
          ArrayOfEntInterface1[i].free;
        {$ENDIF}
      end;
    finally
      Qry.Free;
    end;
  end
  else begin
    result := false; 
    if Expirada then Senha := CodigoIdentificacaoAcesso else Senha := ResultStr;
  end;
  FreeAndNil(obj);
end;


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
  buf[1] := 'a';
  len := length(st);
  if len > 1024 then len := 1024;
  wlen := len;
  move(wlen,buf[1],4 );
  move(st[1],buf[5],len );
{$IFDEF LINUX}  
  __write(handle,buf[1],len+4);
{$IFDEF FPC}
  fpfsync(Handle);
{$ELSE}
  fsync(Handle);
{$ENDIF}
{$ENDIF}  
end;

var
  GeraArquivos: Boolean;
  CanalLeitura,
  CanalEscrita : Integer; 
  OpStr,
  Novasenha,
  URL,
  ChaveSecao,
  MsgErro,
  Servico,
  IdStr: AnsiString;
  Identificacao: Integer;
  Usuario,
  Senha,
  IP : AnsiString;
  ModoTeste : boolean;
  QTDMAXLOGIN : integer;
begin
  QTDMAXLOGIN := 0;
  Expirada := false;
  NovaSenha := '';
  OpStr := '';
  Contador:= 0;
  MsgErro := '';
  ChaveSecao := '';
  URL := '';
  ModoTeste := false;
  GeraArquivos := false;
  CanalLeitura := 0;
  CanalEscrita := 1;
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
      if CanalEscrita = 0 then  // Usado para testes
      begin
        Servico := 'SIMULARETORNO:';
        IdStr := '88';
        Usuario := 'supervisor';
        Senha := 'tempo';
      end
      else 
      begin
        readlv(CanalLeitura,Servico);
        readlv(CanalLeitura,IdStr);
        readlv(CanalLeitura,OpStr);
        readlv(CanalLeitura,Usuario);
        readlv(CanalLeitura,Senha);
        readlv(CanalLeitura,NovaSenha);
      end;
      Identificacao := strtoint(IdStr);

    if uppercase(copy(Servico,1,14)) = 'SIMULARETORNO:' then
    begin
      Servico := copy(Servico,15,length(servico));
      ModoTeste := true;
    end
    else if uppercase(copy(Servico,1,13)) = 'GERAARQUIVOS:' then 
    begin
      Servico := copy(Servico,14,length(servico));
      GeraArquivos := true;
    end;
    // Ir no web servevice
    if (trim(Usuario) <> '') then
    begin
      if OpStr = 'LOGIN' then
      begin
        if usuario = 'usuarioweb' then begin
          if ExecutaLoginScci(Usuario,Senha,Expirada) then
            writelv(CanalEscrita,'T'+Senha)
          else if Expirada then  writelv(CanalEscrita,'E'+Senha)
          else writelv(CanalEscrita,'F'+Senha);
        end
        else begin
          try if NovaSenha <> '' then QTDMAXLOGIN := strtoint(NovaSenha); except QTDMAXLOGIN := 0; end;
          if ExecutaLoginBanese(Servico,Identificacao,IP,Usuario,Senha,ModoTeste,GeraArquivos,Expirada) then
          begin
            // Se resposta true então
            // Grava ou inclui usuário na tabela de usuáio as seguintes informações:
            //   Senha ( Chave de seção )
            //   Perfil primário e perfil segundário com 0.
            // Lê as permissões do usuário do web service
            //   Apagas as permissões que existirem e grava as novas permissões
            //   na tabela usuario_função
            // Envia a resposta e chave de seção  para o canal de escrita
            writelv(CanalEscrita,'T'+Senha);
            // Se a resposta for false
            if QTDMAXLOGIN > 1 then ValidaQtdLogin(QTDMAXLOGIN,usuario);
            GravaSection(Senha,Usuario,GetEnv('IP'));
          end else
            if Expirada then  writelv(CanalEscrita,'M'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
        end;
      end
      else if OpStr = 'VALIDA' then
           begin
             if ExecutaValidaBD(Servico,IdStr,Usuario,Senha,Expirada) then
               writelv(CanalEscrita,'T'+Senha)
             else if Expirada then writelv(CanalEscrita,'E'+Senha)
             else writelv(CanalEscrita,'F'+Senha);
           end
      else if OpStr = 'PASSWD' then
      begin
       if ExecutaPasswdBanese(Servico,Usuario,Senha,NovaSenha,ModoTeste,GeraArquivos) then
          writelv(CanalEscrita,'T'+Senha)
        else writelv(CanalEscrita,'F'+Senha);
      end;
    end
    else writelv(CanalEscrita,'FUsuario não informado');
       // Envia false e mensagem de erro
    except 
      on e : exception do
        writelv(CanalEscrita,'FErro de execução no loginbanese: '+E.message);
    end;
  // fim se
  finally
{$IFDEF LINUX}  
   __close(CanalLeitura);
   __close(CanalEscrita);
{$ENDIF}   
  end 
  else system.writeln( 'Parametros Incorretos');
end.
