(*$V+*)
program logoutbanese;

uses
  SysUtils, segurancabaneselib, Classes, 
{$IFDEF FPC}
{$ELSE}
  SOAPHTTPClient,
{$ENDIF}
  scciio,
  parmlib, uloglib, pxmllib;



type
  tobj = class
          procedure OnBeforeExecute(const pMethodName: AnsiString; var SOAPRequest: WideString);
          procedure OnAfterExecute(const pMethodName: AnsiString; SOAPResponse: TStream);
         end;

var
  Xml : TpXml;
  co_aplic : TLogAplic;
  NomeUsuario : string;
  URL, Senha, IP : string;
  msglog : string;
  obj : tobj;
  ModoGerarArquivos,ModoTeste : boolean;
  Contador : integer;


procedure Help;
begin
  writeln('logoutbanese -z <ACAO> <USUARIO> <IP> <URL> <TOKEN> [-n D(debug)]');
end;


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
  inc(Contador);
  FileStream := TFileStream.Create('Retorno_'+pMethodName+inttostr(contador)+'.xml',fmOpenWrite);
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
  assign(f,'Envio_'+pMethodName+inttostr(Contador)+'.xml');
  rewrite(f);
  try
    writeln(f,SOAPRequest);
  finally
    close(f);
  end;
end;

procedure ExecutaModoTeste(
                    var Senha :String;
                    var LoginOk:Boolean; 
                    var ResultStr: AnsiString);
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
    Senha := p['codigoIdentificacaoAcesso'].AsString;
  finally
    xml.free;
  end;
end;


function ExecutaLogOutBanese( Servico,IP,Senha :AnsiString;ModoGerarArquivos : boolean): boolean;
var
  RIO : SegurancaNetServiceSoap;
  ResultStr:AnsiString;
  LogOutOK : boolean;
begin
  ResultStr := '';
  LogOutOK := true;
  if ModoTeste then ExecutaModoTeste(Senha,LogOutOK,ResultStr)
  else begin
    obj := tobj.create;
    RIO := GetSegurancaNetServiceSoap(Servico,ModoGerarArquivos);
    RIO.TransEfetuarLogOut(Senha,LogoutOK,ResultStr);
  end;
  result := LogOutOK;
  obj.free;
end;


procedure LogoutWS(Servico,IP,Senha:AnsiString);
begin
  URL := '';
  ModoTeste := false;
  ModoGerarArquivos := false;
  if uppercase(copy(Servico,1,14)) = 'SIMULARETORNO:' then
  begin
    Servico := copy(Servico,15,length(servico));
    ModoTeste := true;
  end;
  ExecutaLogoutBanese(Servico,IP,Senha,ModoGerarArquivos);
end;

begin
  if upcase(Parms.Subtipo[1].Tipo) = 'D' then
    LOGInibeErros := false;
  if parms.help then
    help
  else if parms.parmextra[0].tam < 3 then
    raise exception.create('Parâmetros insuficientes')
  else begin
    if (uppercase(Parms.parmextra[1].nome) = 'LOGOUT') or
            (uppercase(Parms.parmextra[1].nome) = 'LOGOFF') then
      co_aplic := logaplic_logout
    else
      co_aplic := logaplic_NaoDefinido;
    if co_aplic = logaplic_NaoDefinido then
      raise exception.create('Parâmetros inválidos')
    else begin
      NomeUsuario := parms.parmextra[2].nome;
      IP := parms.parmextra[5].nome;
      URL := parms.parmextra[3].nome;
      Senha :=  parms.parmextra[4].nome;
      Xml := TpXml.create;
      try
        Xml.documentelement.nodename := 'SCCILOG';
        if co_aplic = logaplic_logon then begin
            Xml.documentelement.addchild('TIPO').asstring := 'LOGON';
            msglog := 'Usuário '+nomeusuario+' se conectou';
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
        Xml.documentElement.addchild('USUARIO').asstring := nomeusuario;
        Xml.documentElement.addchild('IP').asstring := IP;
        GeraLog(Co_aplic,logseveridade_Aviso,'',nomeusuario,
                msglog+'. (IP:'+IP+')',
                '',XML);
        LogOutWS( URL,IP,Senha);
      finally
        Xml.free;
      end;
    end;
  end;
end.
