program wcorp;
 
uses SysUtils, Classes, ucommunication, punix, pxmllib, pIniFiles, pcrypt,
     lib1, stringtransf, synautil, HTTPSend, strutils,
     {$IFDEF LINUX} base64, ssl_openssl, ssl_openssl11, ssl_openssl3, fpjwt, pjwk, prsasign, smv, {$ENDIF} md5lib;

const
  // w.ini TipoLogin default em branco
  cTipoLogin_SiteMinder = 'SiteMinder';
  cSenha_SiteMinder = '!_____';
  
type
  EOauthErro = class(Exception);

  Tdebug = Class
    FPID,
    FPath: AnsiString;
    FAberto: boolean;
    FArquivo: Text;
    procedure abre;
    procedure fecha;
    procedure write(msg:AnsiString);
    constructor create;
    destructor destroy; override;
    property PID: AnsiString read FPID write FPID;
    property PATH: AnsiString read FPATH write FPATH;
  end;

  TpWIni = record
             usuarioWeb,
             senhaWeb,
             tokenWeb,
             ambienteOperacional,
             auth_url,
             scope,
             client_id,
             client_secret,
             token_url,
             tokeninfo_url,
             redirect_url,
             logout_url,
             memberof,
             group_prefix,
             id_identifier,
             ApiAppId,
             ApiAppSecret,
             user_siteminder,
             jwt_id_identifier,
             jwt_memberof,
             jwt_PhysicalDeliveryOfficeName,
             Token_Tag,
             authType,
             metodosPermitidos,
             HUBSessionKey,
             HUBToken : AnsiString;
           end;
var
  Entrada:AnsiString;
  i:integer;
  Debug: TDebug;
  Criptografa: boolean;
  TipoLogin : string;
  wini: TpWIni;
  
function codifica(entrada: AnsiString) : AnsiString;
var
  j : byte;
  l : integer;
  i : integer;
begin
  Result := ansiToUtf8(entrada);
  if Criptografa then
  begin
    j := 0;
    l := length(Result);
    for i := 1 to l do 
      // Não altera os caracteres extendidos utf8
      if ((ord(Result[i]) and $80) <> $80) then
      begin
        j := byte(j + 1);
        Result[i] := chr(ord(Result[i]) xor ($70 + (j and 15)));
      end;
    insert('.*(@',result,1);
  end;
end;

(*function convBarraU(entrada:AnsiString): AnsiString;
const 
  charset: set of char = ['0'..'9','A'..'F','a'..'f'];
var
  i,l: integer;
  s:AnsiString;
begin
  i := 1;
  l := length(entrada);
  result := '';
  while (i <= l) do
  begin
    if (entrada[i] = '\') and (i+6<=l) and (entrada[i+1] = 'u') and 
       (entrada[i+2] in charset) and (entrada[i+3] in charset) and
       (entrada[i+4] in charset) and (entrada[i+5] in charset) then
    begin
      s := copy(entrada,i+2,4);
      result := result + Utf8Encode(WideString(WideChar(StrToInt('$'+s))));
      i := i + 6;
    end
    else 
    begin 
      result := result + entrada[i];
      inc(i);
    end;
  end;
end;  *)

function GetServerPath(Path_Info:AnsiString):AnsiString;
begin
  i := length(Path_info);
  while(i > 1) and (Path_Info[i] <> '/') do dec(i);
  dec(i);
  while(i > 1) and (Path_Info[i] <> '/') do dec(i);
  result := copy(Path_Info,1,i);    
end;

procedure DecodeProgramNameAndMethod(Path_Info:AnsiString; out ProgramName,MethodName:AnsiString);
var
  i,j: Integer;
begin
  i := length(Path_info);
  while(i > 1) and (Path_Info[i] <> '/') do dec(i);
  j := i;
  dec(j);
  while(j > 1) and (Path_Info[j] <> '/') do dec(j);
  MethodName := copy(Path_Info,i,MaxInt);
  ProgramName := copy(Path_Info,j,i-j+1);
  if (length(ProgramName)>0) and (ProgramName[1] = '/') then delete(ProgramName,1,1);
  if (length(ProgramName)>0) and (ProgramName[length(ProgramName)] = '/') then delete(ProgramName,length(ProgramName),1);
  if (length(MethodName)>0) and (MethodName[1] = '/') then delete(MethodName,1,1);
  if (length(MethodName)>0) and (MethodName[length(MethodName)] = '/') then delete(MethodName,length(MethodName),1);
  if (length(MethodName)>0) then MethodName[1] := UpCase(MethodName[1]);
end;

procedure LeConfig(out Server,Port,Contexto:AnsiString; out wini: TpWini);
var
  Ini : TMemIniFile;
begin
  Ini := TMemIniFile.Create('w.ini');
  try
    Server := Ini.ReadString('Servidor','Servidor','');
    Port := Ini.ReadString('Servidor','Porta','');
    Contexto := Ini.ReadString('Servidor','Contexto','CORP_WEB');
    Criptografa := Ini.ReadString('Servidor','Criptografa','F') = 'T';
    TipoLogin := Ini.ReadString('Servidor','TipoLogin','');
    wini.UsuarioWeb := Ini.ReadString('Simulador','usuarioweb','usuarioweb');
    wini.senhaWeb := Ini.ReadString('Simulador','senhaweb','branco');
    wini.tokenweb := Ini.ReadString('Simulador','tokenweb','MDNKMIMJPOPDPDPLOKOLOPBO');
    wini.ambienteOperacional := Ini.ReadString('Servidor', 'AmbienteOperacional', '');
    if wini.ambienteOperacional = '' then
      wini.ambienteOperacional := Ini.ReadString('Servidor', 'ambienteOperacional', '');
    wini.metodosPermitidos := Ini.ReadString('Servidor', 'Metodos', '');
    wini.auth_url := Ini.ReadString('Oauth','auth_url','');
    wini.memberof   := Ini.ReadString('Oauth','memberof','');
    wini.group_prefix := Ini.ReadString('Oauth','group_prefix','');
    wini.redirect_url := Ini.ReadString('Oauth','redirect_url','');
    wini.client_id := Ini.ReadString('Oauth','client_id','');
    wini.client_secret := Ini.ReadString('Oauth','client_secret','');
    wini.scope := Ini.ReadString('Oauth','scope','');
    wini.id_identifier := Ini.ReadString('Oauth','id_identifier','');
    wini.token_url := Ini.ReadString('Oauth','token_url','');
    wini.tokeninfo_url := Ini.ReadString('Oauth','tokeninfo_url','');
    wini.logout_url := Ini.ReadString('Oauth','logout_url','');
    wini.ApiAppId := Ini.ReadString('ApiSeg','AppId','');
    wini.ApiAppSecret := Ini.ReadString('ApiSeg','AppSecret','');
    wini.user_siteminder := Ini.ReadString('Servidor','User_SiteMinder','HTTP_SM_USER');
    wini.jwt_id_identifier := Ini.ReadString('Oauth','jwt_id_identifier','');
    wini.jwt_memberof := Ini.ReadString('Oauth','jwt_memberof','');
    wini.jwt_PhysicalDeliveryOfficeName := Ini.ReadString('Oauth','jwt_PhysicalDeliveryOfficeName','');
    wini.Token_Tag := Ini.readstring('Oauth','token_tag','');
    wini.authType := Ini.readstring('Oauth','authType','');
    wini.HUBToken := Ini.readstring('ApiSeg', 'hub_token', '');
    wini.HUBSessionKey := Ini.readstring('ApiSeg', 'hub_senha', '');
  finally
    Ini.free;
  end;
end;

procedure  DecodeServerPath(Entrada:AnsiString; out Server,Port,ServerPath:AnsiString);
var
  i,j: integer;
begin
  Server := '';
  Port := '';
  ServerPath := '';
  if copy(Entrada,length(Entrada),1) <> '/' then
      Entrada := Entrada + '/';
  i := pos('/',Entrada);
  if (i > 1) then
  begin
    Server := copy(Entrada,1,i-1);
    j := pos(':',Server);
    Port := copy(Server,j+1,MaxInt);
    Server := copy(Server,1,j-1);
    Serverpath := copy(Entrada,i,MaxInt); // Inclui a barra
  end
  else
    Serverpath := Entrada;
end;

procedure GetParamsOauth();
begin
  writeln('Content-Type: application/json; charset=utf-8',#10#13);
  write(codifica('{"success": "true",'+
              '"auth_url": "' + wini.auth_url + '",' +
              '"redirect_url": "' + wini.redirect_url + '",' +
              '"client_id": "' + wini.client_id + '",' + 
              '"logout_url": "' + wini.logout_url + '",' + 
              '"scope": "' + wini.scope + '"' +
              '}'));
end;    

function retornaUserNameOauth(Params: TpXml; var Group : AnsiString ):AnsiString;
var
  Http: THttpSend;
  XmlAux,
  Xml: TpXml;
  Ok: boolean;
  wtoken : ansistring;
  BodyParam : ansistring;
  wnode : tpxmlnode;
  wmemberof : string;
  id_token : ansistring;
  Json : TpXml;
  Parametros : THashedStringlist;
begin
  result := '';
  Group := '';
  wmemberof := '';
  Http := THttpSend.Create;
  XML := TpXml.Create;
  XmlAux := TpXml.create;
  try
    if Params['code'].AsString <> '' then
    begin
//debug.write('URL : '+ wini.token_url+' code = '+Params['code'].AsString);
      bodyparam := 'code='+Params['code'].AsString +
                   '&client_id='+wini.client_id +
                   '&client_secret='+wini.client_secret +
                   '&redirect_uri='+Params['redirect_Uri'].asstring +
                   '&grant_type=authorization_code';
      HTTP.MimeType := 'application/x-www-form-urlencoded';
      Http.Document.position := 0;
      WriteStrToStream(Http.Document,bodyparam);
      ok := Http.HttpMethod('POST',wini.token_url);
//debug.write('Request do token ok ');
      if not ok then raise Exception.Create('Erro no chamada do token: ' + inttostr(http.ResultCode));
      Http.Document.position := 0;
//http.document.savetofile('/tmp/log_token.txt');
      Http.Document.position := 0;
      Xml.ParseStream(Http.Document);
      if (trim(wini.tokenInfo_url) = '') and
         (wini.jwt_id_identifier > '') and
         ((wini.jwt_memberof > '') or (comparetext(wini.authType,'KEYCLOAK')=0)) then begin
         id_token := DecodeBase64URL(extractword(2,xml['id_token'].asstring,['.'])); // header.payload.sign
         Json := TpXml.create;
         Parametros := THashedStringlist.create;
         try
           json.parsestring(id_token);
           if assigned(Json[wini.jwt_id_identifier]) then
             result := Json[wini.jwt_id_identifier].asstring
           else  
             result := '';
           
           if wini.jwt_memberof > '' then begin
             if assigned(Json[wini.jwt_memberof]) then
               Parametros.values['memberof'] := Json[wini.jwt_memberof].asstring
             else
               Parametros.values['memberof'] := '';
           end;
(*
           if assigned(Json['Givename']) then
             Parametros.values['Givename'] := Json['Givename'].asstring
           else
             Parametros.values['Givename'] := '';
*)
           if wini.jwt_PhysicalDeliveryOfficeName > '' then begin
             if assigned(Json[wini.jwt_PhysicalDeliveryOfficeName]) then
               Parametros.values['PhysicalDeliveryOfficeName'] := Json[wini.jwt_PhysicalDeliveryOfficeName].asstring
             else
               Parametros.values['PhysicalDeliveryOfficeName'] := '';
           end;

           if comparetext(wini.authType,'KEYCLOAK')=0 then begin
             //result := extractword(1,result,['.']); // USUARIO.ENTIDADE;  O usuário deve ser o givenname inteiro         
             Parametros.values['jwt_id_identifier'] := Json[wini.jwt_id_identifier].asstring;
             if wini.token_tag > '' then begin
               if assigned(Xml[wini.Token_Tag]) then
                 Parametros.values['Token_Tag'] := Xml[wini.Token_Tag].asstring
               else
                 Parametros.values['Token_Tag'] := '';  
             end;
           end;  
           group := Parametros.Commatext;
         finally
           Json.free;
           Parametros.free;
         end;
      end
      else if (pos('brb', wini.scope) > 0) and (wini.token_tag > '') then begin 
        wtoken := DecodeBase64URL(extractword(2,xml[wini.token_tag].asstring,['.']));
        Json := TpXml.create;
        try
          xmlAux.documentElement.nodeName := 'params';
//	  xmlAux.documentElement.add('token').asString := extractword(2,xml[wini.token_tag].asstring,['.']);
          xmlAux.documentElement.add('token').asString := copy(extractword(2,xml[wini.token_tag].asstring,['.']),1,1500);
          xmlAux.documentElement.add('expiresIn').asString := xml['expires_in'].asString;
          Json.ParseString(wtoken);
          if assigned(Json[wini.jwt_id_identifier]) then
            result := Json[wini.jwt_id_identifier].asstring
          else  
            result := '';
          if wini.memberof <> '' then
          begin
            case WordCount(wini.memberof,['.']) of
              1: wnode := json[0];
              2: wnode := json[ExtractWord(1,wini.memberof,['.'])];
              3: wnode := json[ExtractWord(1,wini.memberof,['.'])][ExtractWord(2,wini.memberof,['.'])];
            end;
            wmemberof := ExtractWord( WordCount(wini.memberof,['.']),wini.memberof,['.']);
            for i := 0 to wnode.count - 1 do
            begin
              if wnode[i].nodename = wmemberof then
                if copy(wnode[i].nodevalue,1,length(wini.group_prefix)) = wini.group_prefix then
                  xmlAux.documentElement.add('perfil').asString := copy(wnode[i].nodevalue,length(wini.group_prefix)+1,length(wnode[i].nodevalue));
            end;
          end;
          xmlAux.documentElement.add('ipAddr').asString := json['ipaddr'].asString;
          Group := xmlAux.code;
        finally
          Json.free;
        end;
      end
      else if (pos('openid', wini.scope) > 0) and (wini.token_tag > '') then begin 
        //OPEN ID / COGNITO
        wtoken := DecodeBase64URL(extractword(2,xml[wini.token_tag].asstring,['.']));
        Json := TpXml.create;
        try
          Json.ParseString(wtoken);
          if assigned(Json[wini.jwt_id_identifier]) then
            result := Json[wini.jwt_id_identifier].asstring
          else  
            result := '';
          xmlAux.documentElement.nodeName := 'params';
          xmlAux.documentElement.add('token').asString := copy(extractword(2,xml[wini.token_tag].asstring,['.']),1,1500);
          xmlAux.documentElement.add('expiresIn').asString := xml['expires_in'].asString;
          if wini.tokeninfo_url > '' then
          begin
            wtoken := xml[wini.token_tag].asString;
            Http.Clear;
            Http.Document.Position := 0;
            BodyParam := '$count=true' +
                         '&$filter=startswith(displayName,'+QuotedStr(wini.group_prefix)+')'+
                         '&$select=displayName';
            HTTP.MimeType := 'application/x-www-form-urlencoded';
            Http.Headers.Add('Authorization: Bearer ' + wtoken);
            Http.Headers.Add('ConsistencyLevel: eventual');
            Http.Document.Position := 0;
            ok := http.HTTPMethod('GET', wini.tokeninfo_url + '?'+BodyParam);
            if not ok then
              raise  Exception.Create('Erro na chamada do tokeninfo: ' + inttostr(http.ResultCode));
            Xml.DocumentElement.Clear;
            Http.Document.Position := 0;
            Xml.ParseStream(Http.Document);
            if assigned(xml['value']['displayName']) and 
               (copy(xml['value']['displayName'].asString, 1, length(wini.group_prefix)) = wini.group_prefix) then
              xmlAux.documentElement.add('perfil').asString := copy(xml['value']['displayName'].asString, 
                                                    1 + length(wini.group_prefix),
                                                    length(xml['value']['displayName'].asString));
          end;
          xmlAux.documentElement.add('ipAddr').asString := json['ipaddr'].asString;
          Group := xmlAux.code;
        finally
          Json.free;
        end;
      end
      else begin
        wtoken := xml['access_token'].AsString;
        Http.Clear;
        Xml.DocumentElement.Clear;
//debug.write('URL : '+ wini.tokeninfo_url+'access_token = '+wtoken);
        ok := Http.HttpMethod('GET',wini.tokenInfo_url+'?access_token='+wtoken);
//debug.write('Request do user ok ');
        if not ok then raise  Exception.Create('Erro na chamada do tokeninfo: ' + inttostr(http.ResultCode));
        Http.Document.position := 0;
//http.document.savetofile('/tmp/log_access.txt');
        Http.Document.position := 0;
        Xml.ParseStream(Http.Document);
//debug.write('usr = '+ copy(xml[ExtractWord(1,wini.id_identifier,['.'])][ExtractWord(2,wini.id_identifier,['.'])][ExtractWord(3,wini.id_identifier,['.'])].AsString,1,20));
        case WordCount(wini.id_identifier,['.']) of
          1: result := copy(xml[wini.id_identifier].AsString,1,20);
          2: result := copy(xml[ExtractWord(1,wini.id_identifier,['.'])][ExtractWord(2,wini.id_identifier,['.'])].AsString,1,20);
          3: result := copy(xml[ExtractWord(1,wini.id_identifier,['.'])][ExtractWord(2,wini.id_identifier,['.'])][ExtractWord(3,wini.id_identifier,['.'])].AsString,1,20);
        end;
        if wini.memberof <> '' then
        begin
          case WordCount(wini.memberof,['.']) of
            1: wnode := xml[0];
            2: wnode := xml[ExtractWord(1,wini.memberof,['.'])];
            3: wnode := xml[ExtractWord(1,wini.memberof,['.'])][ExtractWord(2,wini.memberof,['.'])];
          end;
          wmemberof := ExtractWord( WordCount(wini.memberof,['.']),wini.memberof,['.']);
          for i := 0 to wnode.count - 1 do
          begin
            if wnode[i].nodename = wmemberof then
              if copy(wnode[i].nodevalue,1,length(wini.group_prefix)) = wini.group_prefix then
                 Group := copy(wnode[i].nodevalue,length(wini.group_prefix)+1,length(wnode[i].nodevalue));
          end;
        end;
      end;
    end
    else begin
      ok := Http.HttpMethod('GET',wini.tokenInfo_url+'?access_token='+
                            Params['accessToken'].AsString);
      Http.Document.position := 0;
      Xml.ParseStream(Http.Document);
      result := copy(xml[wini.id_identifier].AsString,1,20);
    end;
  finally
//debug.write('Fim getuser=====');
    Http.free;
    Xml.free;
    XmlAux.free;
  end;
end;

procedure DoLogin(Server,Port,Contexto:AnsiString;Params:TpXMl);
var
  p: tpXmlNode;
  pCCPClient: TpCCPClient;
  ServerPath,
  LServer,
  LPort: AnsiString;
  Usuario,
  SessionKey,
  Senha: AnsiString;
  alerta : ansistring;
  BufInOut : TMemoryStream;
  Listain : TpMemory;
  ListaOut : TpMemory;
  Oauth: boolean;
  Group : AnsiString;
  SelecionaEnt: AnsiString;
begin
  Oauth:= false;
  SelecionaEnt:= '';
  Group := '';
  alerta := '';
  LServer := '';
  LPort := '';
  ServerPath := '';
  p := TpXmlNode.Create(nil);
  pCCPClient := TpCCPCLient.Create(nil);
  writeln('Content-Type: application/json; charset=utf-8',#10#13);
  decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
  try
    try
      if comparetext(TipoLogin,cTipoLogin_SiteMinder) = 0 then begin
        Usuario := GetEnv(wini.user_siteminder);
//        Usuario := 'supervisor';
        Senha := cSenha_SiteMinder;
      end
      // scat 93840 - loginsisbr
      else if Params['JWT'].AsString > '' then begin
        Usuario := Params['userName'].AsString;
        Senha := WebCrypt('!#___'+Params['JWT'].AsString);
      end
      else if (Params['accessToken'].AsString > '') or (Params['code'].AsString > '')  then
      begin
        try
          Usuario := retornaUserNameOauth(Params,Group);
        except
          on E:exception do
            raise EOauthErro.create(e.message);
        end;
        Oauth := true;
        if Group <> '' then  senha := WebCrypt('!#___'+Group)
        else senha := md5crypt(Pchar(Usuario),Pchar('$1$'+Usuario));
      end 
      else
      begin
        Usuario := Params['userName'].AsString;
        if Usuario = '' then Usuario := wini.UsuarioWeb;
        Senha := Params['password'].AsString;
        if (Usuario = wini.UsuarioWeb) and (Senha = '') then
          Senha := wini.SenhaWeb;
      end;

      pCCPClient.Params.Values['User'] := Usuario;
      pCCPClient.Params.Values['Password'] := Senha;
      if LServer > '' then
        pCCPClient.Params.Values['Server'] := LServer
      else
        pCCPClient.Params.Values['Server'] := Server;
      if LPort > '' then
        pCCPClient.Params.Values['Socket'] := LPort
      else
        pCCPClient.Params.Values['Socket'] := Port;
      pCCPClient.Params.Values['Captcha'] := Params['captcha'].AsString;
      pCCPClient.Params.Values['Origin'] := 'ScciCorpWeb='+Params['REMOTE_ADDR'].AsString;
      pCCPClient.Params.Values['Serverpath'] := ServerPath;
      pCCPClient.Login;
      BufInOut := TMemoryStream.Create;
      Listain := TpMemory.Create;
      ListaOut := TpMemory.Create;
      try
        ListaOut.addval('REMOTE_ADDR', GetEnv('REMOTE_ADDR'));
        ListaOut.SaveToStream(BufInOut);
        BufInOut.Position := 0;
        pCCPClient.Exec('wae.validaambiente',BufInOut);
        ListaIn.LoadFromStream(BufInOut);
        if Listain.readval('MsgAlertaExpiracao') > '' then
          alerta := ',' + '"message": "'+Listain.readval('MsgAlertaExpiracao')+'"';
      finally
        BufInOut.free;
        Listain.free;
        ListaOut.free;
      end;
      if (alerta = '') and (pCCPClient.params.values['AlertaExpiracaoSenha'] <> '') then
        alerta := ',' + '"message": "' + pCCPClient.Params.Values['AlertaExpiracaoSenha'] + '"';

      if Oauth then
      begin
        senha := pCCPClient.Params.Values['Password'];
        if (pos('brb', wini.scope) > 0) then begin
          //a verificação é case-INsensitive então temos que ler o usuario correto, que é devolvido junto com a sessionKey.
          if (pos(':', Senha) > 0) then begin
            usuario := copy(senha, pos(':', senha) + 1, length(senha) - 1);
            senha := copy(senha, 1, pos(':', senha) - 1);
          end
        end
        else if (pos('openid', wini.scope) > 0) then begin
          if (pos(':SelecionaEnt', senha) > 0) then begin
            senha := copy(senha, 1, length(senha) - length(':SelecionaEnt'));
            SelecionaEnt := ', "selecionaEnt": "true"';
            usuario := palavra(senha,2,':',#255,#255);
          end;  
          if (pos('@', usuario) > 0) then begin
            //se o usuario é um email temos que ler o usuario que voltou do login
            usuario := copy(usuario, 1, pos('@', usuario) - 1);
            if (pos(':', Senha) > 0) then begin
              usuario := copy(senha, pos(':', senha) + 1, length(senha) - 1);
              senha := copy(senha, 1, pos(':', senha) - 1);
            end
          end
          else if (pos(':', Senha) > 0) then begin
            //se o usuario nao é email, é cpf... então não temos q ler o usuario mas ainda temos q limpar a senha
            senha := copy(senha, 1, pos(':', senha) - 1);
          end;
        end;
        write(codifica('{"success": "true",'+
              '"userName": "'+usuario+'",'+
              '"acessToken":"' + Params['accessToken'].AsString+'",'+
              '"sessionKey": "' + copy(intstr2(getpid,5),1,5) + WebCrypt(senha) + '",' +
              '"contexto": "' + contexto + '"' + alerta + selecionaEnt +
              '}'))

      end 
      else if (comparetext(TipoLogin,cTipoLogin_SiteMinder) = 0) or Oauth then
        write(codifica('{"success": "true",'+
              '"userName": "'+usuario+'",'+
              '"acessToken":"' + Params['accessToken'].AsString+'",'+
              '"sessionKey": "' + copy(intstr2(getpid,5),1,5) + WebCrypt(pCCPClient.Params.Values['Password']) + '",' +
              '"contexto": "' + contexto + '"' + alerta +
              '}'))
      else if (Usuario = wini.usuarioWeb) and (Senha = wini.Senhaweb) then
      // Com este usuário e senha não envia de volta a sessionkey
        write(codifica('{"success": "true",'+
              '"contexto": "' + contexto + '"' + alerta +
              '}'))
      else if Params['JWT'].AsString > '' then begin
        //LOGIN SISBR
        usuario := palavra(pCCPClient.Params.Values['Password'], 2, ';', #255, #255);
        sessionKey := palavra(pCCPClient.Params.Values['Password'], 1, ';', #255, #255);
        write(codifica('{"success": "true",'+
              '"sessionKey": "' + copy(intstr2(getpid,5),1,5) + WebCrypt(sessionKey) + '",' +
              '"userName": "' + usuario + '",' +
              '"contexto": "' + contexto + '"' + alerta +
              '}'));
      end
      else begin
        write(codifica('{"success": "true",'+
              '"sessionKey": "' + copy(intstr2(getpid,5),1,5) + WebCrypt(pCCPClient.Params.Values['Password']) + '",' +
              '"contexto": "' + contexto + '"' + alerta +
              '}'));
      end;
    except
      on e:EOauthErro do begin
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := 'Resposta inesperada. Recarregue a página e tente novamente';
        write(codifica(p.tojson(0,false)));
      end;
      on E:ECommunicationControlTrocaSenha do
      begin
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := E.message;
        p.addChild('codigo').AsString := 'E004';
        write(codifica(p.tojson(0,false)));
      end;
      on E:ECommunicationControlSenhaExpirada do
      begin
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := 'Senha expirada.'; //E.message; a mensagem contem tb o texto "É necessário trocar a senha", tirei para ficar como o plano da 73337
        p.addChild('codigo').AsString := 'E004';
        write(codifica(p.tojson(0,false)));
      end;      
      on E: ECommunicationControlNecessitaCaptcha do
      begin
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := E.message;
        p.addChild('codigo').AsString := 'E003';
        //p.addChild('captcha').AsString := EncodeBase64(geraCaptcha7Jpg('542275'));
        p.AddChild('captcha').AsString :=  pCCPClient.Params.Values['Captcha'];
        write(codifica(p.toJson(0,false,'')));
      end;
      on E:Exception do
      begin
        p.addChild('success').AsBoolean := false;
        if trim(E.message)>'' then
          p.AddChild('message').AsString := E.message
        else
          p.AddChild('message').AsString := 'Ocorreu um erro ao validar as credenciais. Por favor tente novamente.';  
        write(codifica(p.toJson(0,false,'')));
      end;
    end;
  finally
    p.free;
  end;
end;

procedure Password(Server,Port,Contexto:AnsiString;Params:TpXMl);
var
  p,q: tpXmlNode;
  pCCPClient: TpCCPClient;
  ServerPath,
  LServer,
  LPort: AnsiString;
begin
  LServer := '';
  LPort := '';
  ServerPath := '';
  p := TpXmlNode.Create(nil);
  pCCPClient := TpCCPCLient.Create(nil);
  writeln('Content-Type: application/json; charset=utf-8',#10#13);
  decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
  try
    try
      pCCPClient.Params.Values['User'] := Params['userName'].AsString;
      if LServer > '' then
        pCCPClient.Params.Values['Server'] := LServer
      else
        pCCPClient.Params.Values['Server'] := Server;
      if LPort > '' then
        pCCPClient.Params.Values['Socket'] := LPort
      else
        pCCPClient.Params.Values['Socket'] := Port;
      pCCPClient.Params.Values['Origin'] := 'ScciCorpWeb='+Params['REMOTE_ADDR'].AsString;
      pCCPClient.Params.Values['Serverpath'] := ServerPath;
      pCCPClient.Passwd(Params['userName'].AsString, 
        Params['senhaAtual'].AsString, Params['novaSenha'].AsString);
      writeln('{"success": "true",'+
              '"sessionKey": "' + copy(intstr2(getpid,5),1,5) + WebCrypt(Params['password'].AsString) + '",' +
              '"contexto": "' + contexto + '"' +
              '}');
    except
      on E:Exception do
      begin
        p.addChild('success').AsBoolean := false;
        p.AddChild('message').AsString := E.message;
        //p.addchild('entrada').AsString := Entrada;
        write(codifica(p.toJson(0,false,'')));
      end;
    end;
  finally
    p.free;
  end;
end;

procedure DoLogoff(Server,Port:AnsiString;Params:TpXMl);
var
  p,q: tpXmlNode;
  pCCPClient: TpCCPClient;
  ServerPath,
  LServer,
  LPort: AnsiString;
begin
  LServer := '';
  LPort := '';
  ServerPath := '';
  p := TpXmlNode.Create(nil);
  pCCPClient := TpCCPCLient.Create(nil);
  writeln('Content-Type: application/json; charset=utf-8',#10#13);
  decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
  try
    try
      pCCPClient.Params.Values['User'] := Params['userName'].AsString;
      q := Params['sessionKey'];
      if assigned(q) then
      begin
        pCCPClient.Params.Values['Password'] := webDeCrypt(copy(q.AsString,6,255));
      end;
      if LServer > '' then
        pCCPClient.Params.Values['Server'] := LServer
      else
        pCCPClient.Params.Values['Server'] := Server;
      if LPort > '' then
        pCCPClient.Params.Values['Socket'] := LPort
      else
        pCCPClient.Params.Values['Socket'] := Port;
      pCCPClient.Params.Values['Origin'] := 'ScciCorpWeb='+Params['REMOTE_ADDR'].AsString;
      pCCPClient.Params.Values['Serverpath'] := ServerPath;
      pCCPClient.Logoff;
      writeln('{"success": "true"}');
    except
      on E:Exception do
      begin
        p.addChild('success').AsBoolean := false;
        p.AddChild('message').AsString := E.message;
        //p.addchild('entrada').AsString := Entrada;
        write(codifica(p.toJson(0,false,'')));
      end;
    end;
  finally
    p.free;
  end;
end;



procedure RedefinirSenha(Server,Port,Contexto:AnsiString;Params:TpXml);
var
 p: tpXmlNode;
 pCCPClient: TpCCPClient;
 ServerPath,
 LServer,
 LPort,
 Aux: AnsiString;
begin
  if (Params['userEmail'].asString > '') then
    Aux := params['userEmail'].asString
  else if Params['userCpf'].asString > '' then
    Aux := params['userCpf'].asString
  else
    raise exception.create('Favor informar um número de CPF válido. (Sem pontos ou espaços)');

  if trim(Params['userName'].asString) = '' then
    raise exception.create('Usuário não informado. Favor preencher.');


  LServer := '';
  LPort := '';
  ServerPath := '';
  p := TpXmlNode.Create(nil);
  pCCPClient := TpCCPClient.Create(nil);
  writeln('Content-Type: application/json; charset=utf-8',#10#13);
  decodeServerPath(Params['ambienteOperacional'].AsString,Lserver,LPort,ServerPath);
  try
    try
      pCCPClient.Params.Values['User'] := Params['userName'].AsString;
      if LServer > '' then
        pCCPClient.Params.Values['Server'] := LServer
      else
        pCCPClient.Params.Values['Server'] := Server;
      if LPort > '' then
        pCCPClient.Params.Values['Socket'] := LPort
      else
        pCCPClient.Params.Values['Socket'] := Port;
      pCCPClient.Params.Values['Origin'] := 'ScciCorpWeb='+Params['REMOTE_ADDR'].AsString;
      pCCPClient.Params.Values['Serverpath'] := ServerPath;
      pCCPClient.EmailPwd(Params['userName'].AsString, '@@@!11k3kd4dEO', Aux);
      writeln('{"success":"true"}');
    except
      on E:Exception do
      begin
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := E.message;
        write(codifica(p.toJson(0,false,'')));
      end;
    end;
  finally
    p.free;
  end;
end;

procedure DoHup(Server,Port:AnsiString;Params:TpXMl);
var
  p,q: tpXmlNode;
  pCCPClient: TpCCPClient;
  ServerPath,
  LServer,
  LPort: AnsiString;
  Usuario : ansistring;
begin
  LServer := '';
  LPort := '';
  ServerPath := '';
  p := TpXmlNode.Create(nil);
  pCCPClient := TpCCPCLient.Create(nil);
  writeln('Content-Type: application/json; charset=utf-8',#10#13);
  decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
  try
    try
      pCCPClient.Params.Values['User'] := Params['userName'].AsString;
      q := Params['sessionKey'];
      if assigned(q) then
      begin
        pCCPClient.Params.Values['Password'] := webDeCrypt(copy(q.AsString,6,255));
      end;

      if LServer > '' then
        pCCPClient.Params.Values['Server'] := LServer
      else
        pCCPClient.Params.Values['Server'] := Server;
      if LPort > '' then
        pCCPClient.Params.Values['Socket'] := LPort
      else
        pCCPClient.Params.Values['Socket'] := Port;
      pCCPClient.Params.Values['Serverpath'] := ServerPath;
      Usuario := Params['Usuario'].AsString;
      pCCPClient.Hup(Usuario);
      writeln('{"success": "true"}');
    except
      on E:Exception do
      begin
        p.addChild('success').AsBoolean := false;
        p.AddChild('message').AsString := E.message;
        write(codifica(p.toJson(0,false,'')));
      end;
    end;
  finally
    p.free;
  end;
end;

constructor TDebug.Create;
begin
  inherited;
  FAberto := false;
end;

procedure TDebug.abre;
begin
  if not FAberto then
  begin
    try
      assign(FArquivo,FPath+PathDelim+'debug'+FPID+'.txt');
      if FileExists(FPath+PathDelim+'debug'+FPID+'.txt') then
        append(FArquivo)
      else
         rewrite(FArquivo);
      fAberto := true;
    except
      on Exception do ;
    end;
  end;
end;

procedure TDebug.fecha;
begin
  if fAberto then
    close(FArquivo);
end;

destructor TDebug.destroy;
begin
  fecha;
  inherited;
end;

procedure TDebug.write(Msg: AnsiString);
begin
  if not faberto then Abre;
  if faberto then
  begin
    writeln(FArquivo,Msg);
    flush(FArquivo);
  end;
end;

{$IFDEF LINUX}
function AssinaMensagem(Saida:AnsiString):AnsiString;
var
  strToHash: AnsiString;
  xml: TpXMl;
  jwk: TJwk;
  jwt: TJwt;
  hashCalculado: AnsiString;
begin
  result := '';
  xml := TpXml.Create;
  jwk := tjwk.create;
  jwt := tjwt.create;
  try
    //1. Obter a chave privada da aplicação servidora
    try
      xml.ParseFile('.keys/' + wini.ApiAppId);
    except
      raise exception.create('Chave da aplicação servidora não disponível');
    end;
    jwk.AsString := xml['keys'].tojson(0,false); // Pega a primeira chave no array

    //2. Formar a string para a assinatura
    strtohash := StringsReplace(Saida, [#10, #13,#9,' '], ['','','',''], [rfReplaceAll]);

    //3. Calcular um SHA-256
    hashCalculado := EncodeStringBase64(sha256(strtohash));

    //4. Gerar o JWT
    jwt.jose.typ := 'JWT';
    jwt.jose.alg := 'RS256';
    jwt.jose.kid := jwk.kid;
    xml.documentElement.clear;
    xml.add('payload').asString := hashCalculado;
    result := EncodeBase64url(jwt.JOSE.asString)+'.'+
           EncodeBase64url(xml.tojson);
    result := result + '.' + EncodeBase64URL(RsaSign(result,jwk.PrivateKey,'RS256'));

  finally
    xml.free;
    jwk.free;
    jwt.free;
  end;
end;
{$ENDIF}

function GetVariable(variavel : string; JsonStr : ansistring) : ansistring;
var
  p : integer;
begin
  // "statusConta": "INADIMPLENTE"

  result := '';

  p := pos(variavel,JsonStr);

  if p > 0 then begin

    while (p <= length(JsonStr)) and (JsonStr[p] <> '"') do
      inc(p);

    inc(p,4); // tira a aspas, os dois pontos, o espaço e a as aspas do valor
    
    while (p <= length(JsonStr)) and (JsonStr[p] <> '"') do begin
      result := result + JsonStr[p];
      inc(p);
    end;

  end;
end;

{$IFDEF LINUX}
procedure GetVersion();
var
  p: Tpxmlnode;
begin
  p := tpxmlnode.create(nil);
  try
    p.nodeName := '';
    try
      p.addChild('success').AsBoolean := true;
      p.addChild('versao').AsString := VersaoC;
      writeln('Content-Type: application/json; charset=utf-8',#10#13);
      write(codifica(p.tojson(0,false)));
    except
      on E: Exception do
      begin
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := 'Não foi possível obter a versão atual';
        writeln('Content-Type: application/json; charset=utf-8',#10#13);
        write(codifica(p.tojson(0,false)));
      end;
    end;
  finally
    p.free;
  end;
end;
{$ENDIF}

function TrataSaidaHUB(saidaStr : Ansistring): ansistring;
var
  Xml,
  XmlAux : TpXml;
  StrAux : AnsiString;
  i,
  count: integer;
begin
  result := saidaStr;
  Xml := TpXml.create;
  XmlAux := TpXml.create;
  try
    Xml.parsestring(saidaStr);
    count := 0;
    StrAux := '';
    for i := 0 to xml.documentelement.count - 1 do begin
      if (xml[i].nodeName = 'PMemory') and (xml[i].isArray) then begin
        inc(count);
        if count > 1 then
          StrAux := StrAux + ',';
        StrAux := StrAux + Copy(Xml[i].toJson(0), length('"PMemory": '), length(Xml[i].toJson(0)));
      end;
    end;
    if count > 0 then
      result := '[' + trim(StrAux) + ']';
  finally
    Xml.free;
    XmlAux.free;
  end;
end;

procedure DoRemoteCall(Server,Port,ServerPath,ProgramName,MethodName:AnsiString;Params: TpXml);
var
  pCCPClient : TpCCPClient;
  BufInOut : TStringStream;
  p: Tpxmlnode;
  Saida: TStringList;
  LServer,
  LPort: AnsiString;
  LPid : AnsiString;
  Usuario,
  Senha: AnsiString;
  SaidaStr: AnsiString;
  st,
  HttpStatus,
  HttpMessage : ansistring;
  HttpBody : boolean;
begin
  pCCPClient := TpCCpClient.create(nil);
  try
    try
      Usuario := Params['userName'].AsString;
      pCCPClient.Params.Values['User'] := Usuario;
      p := Params['sessionKey'];
      LPID := '';
      Senha := '';
      if assigned(p) then
      begin
        if (Usuario = 'loginpoupex') or (Usuario = 'loginintegracao') then
          Senha := p.AsString
        else begin
          Senha := webDeCrypt(copy(p.AsString,6,255));
          LPID := copy(p.AsString,1,5);
        end;
      end
      else
      begin
        if Usuario = wini.usuarioWeb then
          Senha :=  '[' + webDeCrypt(wini.tokenWeb) + ']'; //webDeCrypt(wini.tokenWeb);
      end;

      pCCPClient.Params.Values['Password'] := Senha;
      p := Params['ambienteOperacional'];
      if Params['ambienteOperacional'].AsString = '' then
        if Criptografa then
          raise Exception.Create('Requisição inválida')
        else
          raise Exception.Create('Parametro ambienteOperacional é obrigatório');
      if assigned(p) then
      begin
        decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
        if (LPort > '') then
          pCCPClient.Params.Values['Socket'] := LPort
        else
          pCCPClient.Params.Values['Socket'] := Port;
        if (LServer > '') then
          pCCPClient.Params.Values['Server'] := LServer
        else
          pCCPClient.Params.Values['Server'] := Server;
        pCCPClient.Params.Values['Serverpath'] := ServerPath;
      end;

      Debug.PID := LPID;
      pCCPClient.onDebug := {$IFDEF FPC}@{$ENDIF}Debug.write;
      Params.DocumentElement.NodeName := 'PMEMORY';
      BufInOut := TStringStream.Create('');
      if wini.HUBToken > '' then
        Params.saveJsonToStream(BufInOut)
      else
        Params.saveToStream(BufInOut);
      pCCPClient.exec(Programname+'.'+Methodname,BufInOut);
      // Se for o método PutUsuario, ele pode ter alterado a senha
      // Neste caso chama o hup para atualizar a senha do launcher
      if Methodname = 'PutUsuario' then 
        pCCPClient.Hup(Params['dados']['USUARIO'].AsString);
      saida := TStringList.Create;
      saida.loadFromStream(BufInOut);
      
      st := saida.text;
      HttpStatus := GetVariable('HTTPSTATUS',st);
      if HttpStatus = '' then
        HttpStatus := GetVariable('HUBHTTPSTATUS',st);
      if HttpStatus > '' then begin
        HttpMessage := GetVariable('HTTPMESSAGE',st);
        if HttpMessage = '' then
        HttpMessage := GetVariable('HUBHTTPMESSAGE',st);
      end;
      HttpBody := lib1.StrToBool(GetVariable('HTTPBODY',st));
      if not HttpBody then
        HttpBody := lib1.StrToBool(GetVariable('HUBHTTPBODY',st));
      {$IFDEF LINUX}
      // output legal http page
      if wini.HUBToken > '' then
        SaidaStr := codifica(TrataSaidaHUB(saida.text))
      else
        SaidaStr := codifica(saida.text);

      if wini.ApiAppId <> '' then
      begin
         writeln('x-itau-msg-sign: '+
           AssinaMensagem(SaidaStr));
         writeln('x-itau-correlationID: '+ 
           Params['HTTP_X_ITAU_CORRELATIONID'].AsString);
      end;

      if (saida.count >0) and (copy(saida[0],1,14) = '<!DOCTYPE HTML') then
        write('Content-Type: text/html; charset=utf-8')
      else
        write('Content-Type: application/json; charset=utf-8');

      if HttpStatus > '' then begin
        writeln;
        write('Status: '+HttpStatus+' '+httpMessage);
      end;

      writeln(#10#13);

      if (HttpStatus = '') or HttpBody then
        write(saidaStr);
      
      {$ELSE}
      
      // output legal http page
      if (saida.count >0) and (copy(saida[0],1,14) = '<!DOCTYPE HTML') then
        writeln('Content-Type: text/html; charset=utf-8',#10#13)
      else
        writeln('Content-Type: application/json; charset=utf-8',#10#13);
        
      write(codifica(saida.text));
      
      {$ENDIF}

    except
      on E:ECommunicationControlSessaoExpirada do
      begin
        p := tpxmlnode.create(nil);
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := 'Sua sessão expirou. Por favor, faça login novamente';
        p.addChild('codigo').AsString := 'E001';
        writeln('Content-Type: application/json; charset=utf-8',#10#13);
        write(codifica(p.tojson(0,false)));
        p.free;
      end;
      on E:ECommunicationControlSessaoInvalida do
      begin
        p := tpxmlnode.create(nil);
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := 'Este usuário está acessando o SCCI através de uma outra sessão. ' +   

                   'Será necessário efetuar nova validação da senha.';
        p.addChild('codigo').AsString := 'E002';
        writeln('Content-Type: application/json; charset=utf-8',#10#13);
        write(codifica(p.tojson(0,false)));
        p.free;
      end;
      on E:Exception do
      begin
        {scat102164 criei esse novo tratamento para o httpstatus porque a analise quer que devolva 
         o status E o json com success:false e message entao vou aproveitar o tratamento que já existe
         para o raise exception e só ajustar para escrever o status que veio concatenado no começo da mensagem}
        if (copy(E.message, 1, 4) = 'HTTP') and (copy(E.message, 8, 1) = ':') then begin
          HttpStatus := copy(E.message, 5, 3);
          case HttpStatus of
            '200': writeln('Status: 200 OK');
            '400': writeln('Status: 400 Bad Request');
            '401': writeln('Status: 401 Unauthorized');
            '403': writeln('Status: 403 Forbidden');
          end;
          E.message := lib1.palavra(E.message, 2, ':', #255, #255);
        end;
        p := tpxmlnode.create(nil);
        p.nodeName := '';
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := E.Message;
        writeln('Content-Type: application/json; charset=utf-8',#10#13);
        write(codifica(p.tojson(0,false)));
        p.free;
      end;
    end;
  finally
     pCCPClient.free;
  end;
end;

{$IFDEF LINUX}


procedure wlog(Dt: TDateTime; mensagem: AnsiString);
var
  f: text;
begin
  if not DirectoryExists('/var/log/wcorp') then
    mkDir('/var/log/wcorp');                        
  assign(f,'/var/log/wcorp/accesslog.'+formatdateTime('yyyymm',dt));
  append(f);
  writeln(f,mensagem);
  close(f);
end;


procedure VerificaIntegridadeDaMensagem(Entrada,sign,apikey,authorization,authorization_itau,CorrelationId,RemoteAddress,PathInfo:AnsiString);
var
  f: text;
  jwt: TJwt;
  jwk: TJwk;
  header: AnsiString;
  xml: tpXml;
  i : integer;
  strToHash,
  hashCalculado: AnsiString;
begin
  jwt := tjwt.create;
  xml := TpXml.create;
  jwk := tjwk.create;
  try
    if sign = '' then
      raise exception.create('Header x-itau-msg-sign é obrigatório.');
    //1. Recuperar o kid da chave recebida dentro de x-itau-msg-sign
    header :=  ExtractWord(1,sign,['.']);
    jwt.jose.asString := DecodeBase64Url(header);
    //2. Recuperar o x-itau-apikey
    try
      xml.ParseFile('.keys/' + apikey);
    except
      wlog(now, formatDateTime('dd hh:nn:ss',now)+ 
                ' ' + RemoteAddress + ' ' + getCurrentDir + ' ' + PathInfo + 
                ' ' + apikey + ' ' +CorrelationId + ' ' +
                ' Cliente não autorizado');
      raise exception.create('Cliente não autorizado');
    end;
    //3. Obter a chave pública utilizada para assinar a mensagem com os valores de x-itau-apikey e kid
    for i := 0 to xml.documentElement.count-1 do // Procura o kid nas chaves r
    begin
      if xml[i]['kid'].AsString = jwt.jose.kid then
      begin
        jwk.AsString := xml[i].tojson(0,false);
      end;
    end;

    if jwk.AsString = '{}' then
    begin
      wlog(now, formatDateTime('dd hh:nn:ss',now)+ 
                ' ' + RemoteAddress + ' ' + getCurrentDir + ' ' + PathInfo + 
                ' ' + apikey + ' ' +CorrelationId + ' ' +
                ' Chave ' + jwt.jose.kid + ' não encontrada ');
      raise exception.create('Chave não encontrada');
    end;

    //4. Verificar a integridade do JWT
    if not RsaVerify(sign,jwk) then
    begin
      wlog(now, formatDateTime('dd hh:nn:ss',now)+ 
                ' ' + RemoteAddress + ' ' + getCurrentDir + ' ' + PathInfo + 
                ' ' + apikey + ' ' +CorrelationId + ' ' +
                ' Assinatura da mensagem não verifica');
      raise exception.create('Assinatura da mensagem não verificada');
    end;

    //5. Recuprar o hash enviado
    xml.documentElement.clear;
    xml.parseString(DecodeBase64Url(ExtractWord(2,sign,['.'])));

    //6. Formar a string para assinatura
    if authorization_itau > '' then
      strtohash := StringsReplace(Entrada+authorization_itau, [#10, #13,#9,' '], ['','','',''], [rfReplaceAll])
    else
      strtohash := StringsReplace(Entrada+Authorization, [#10, #13,#9,' '], ['','','',''], [rfReplaceAll]);

    //7. Calcular um novo sha-256
    hashCalculado := EncodeStringBase64(sha256(strtohash));
                 
    //8. Validar a integridade da mensagem
    if HashCalculado <> xml.documentElement.AsString then
    begin
      wlog(now, formatDateTime('dd hh:nn:ss',now)+ 
                ' ' + RemoteAddress + ' ' + getCurrentDir + ' ' + PathInfo + 
                ' ' + apikey + ' ' +CorrelationId + ' ' +
                ' Erro na verificação do hash da mensagem');

      raise exception.create('Erro na verificação do hash da mensagem');
    end;
    wlog(now, formatDateTime('dd hh:nn:ss',now)+ ' ' +
                ' ' + RemoteAddress + ' ' + getCurrentDir + ' ' + PathInfo + 
                ' ' + apikey + ' ' +CorrelationId + ' ' +
                ' Acesso concedido');

  finally
   jwt.free;
   jwk.free;
   xml.free;
  end;
end;
{$ENDIF}

function ValidaMetodo(ProgramName, MethodName : AnsiString):boolean;
var
  i: integer;
  permite : boolean;
  st, 
  metodo,
  programa : ansistring;
begin
  permite := false;
  if wini.metodosPermitidos > '' then begin
    for i := 1 to NumPalavras(wini.metodosPermitidos, ';', #255, #255) do begin
      st := palavra(wini.metodosPermitidos, i, ';', #255, #255);
      if pos('/', st) > 0 then begin
        programa := palavra(st, 1, '/', #255, #255);
        metodo := palavra(st, 2, '/', #255, #255);
        if (programa = ProgramName) and (metodo = MethodName) then
          permite := true;
      end
      else if (MethodName = st) and ((st = 'PostLogin') or //esses metodos nao tem ProgramName
                                     (st = 'PostPassword') or 
                                     (st = 'PostLogoff') or 
                                     (st = 'GetHup') or 
                                     (st = 'GetParamsOauth') or 
                                     (st = 'PostRedefinirSenha') or 
                                     (st = 'GetVersion')) then
        permite := true;
    end;
    if permite then 
      result := true
    else begin
      result := false;
      writeln('Content-Type: text/html; charset=utf-8');
      writeln('Status: 403 Forbidden');
      writeln(#10#13);
      writeln('<h1>Forbidden</h1>');
    end;
  end else
    result := true;
end;



procedure DecodeParamsToNode(Entrada: AnsiString; Node: TpXmlNode);
var
  params: TpXml;
begin
  params := TpXml.create;
  try
    DecodeParams(Entrada, Params);
    if (assigned(Params['PMemory'])) and (Params['PMemory'].isArray) then begin
//    quando a raiz do jsonIn é um array, o decodeParams cria um PMemory adicional no topo.
//    ex:     PMemory:{ PMemory: [{ ... }] }      
//    não quero alterar a DecodeParams então fiz esse tratamento para pegar o PMemory interno, que é o array
      Node.assignAttributesAndChildren(Params['PMemory']);
      Node.isArray := true;
    end else
      Node.assignAttributesAndChildren(Params.DocumentElement);
  finally
    params.free;
  end;
end;

procedure IncluiHeaders(Node : TpXmlNode);
var
  i : integer;
  nome,
  valor: AnsiString;
begin
  for i := 0 to EnvVars.count - 1 do begin
    if pos('HTTP_', EnvVars[i]) = 1 then begin
      nome := palavra(EnvVars[i], 1, '=', #255, #255);
      valor := EnvVars.values[nome];
      nome := copy(Nome, 6, length(Nome)); //remover o HTTP_
      nome := StringReplace(Nome,'_','-',[rfReplaceAll]); //substitui todos os _ por -
      Node.add(nome).asString := valor;
    end;
  end;
end;

var
  PathInfo : AnsiString;
  RequestMethod,
  MethodName,
  ProgramName,
  Server,
  ServerPath,
  Contexto,
  Port: AnsiString;
  P: TpXmlNode;
  Params: TpXml;
  f: file;
  Tamanho,
  TamanhoLido,
  TamanhoFaltando,
  Posicao: Integer;
  EstaCripto:Boolean;
  linha: AnsiString;
begin
  randomize;
  linha := '';
  //writeln('Content-Type: application/json; charset=utf-8',#10#13);
  Criptografa := false;
  Debug := TDebug.Create;
  {$IFDEF MSWINDOWS}
   Debug.Path := 'c:\Corpweb\debug';
  {$ELSE}
   Debug.Path := '.';
  {$ENDIF}
  LeConfig(Server,Port,Contexto,wini);

  tamanhoLido := 0;
  // set a cookie (must come before content-type line below)
  // don't forget to change the expires date
  //writeln('Set-cookie:widget=value; path=/; expires= Mon, 21-Mar-2005  18:37:00 GMT');
 
 
  {
  // demonstrate get cookies
  a:= GetEnv('HTTP_COOKIE');
  //  writeln('cookies:',a);
 
}
{  // demonstrate GET result
  a:='';
  a:= GetEnv('QUERY_STRING');
  writeln('GET: ',a);
}  
  try
    // Variáveis de ambiente
    //debug.write('Environment');
    //for I := 0 to GetEnvironmentVariableCount-1 do 
    //begin
    //  debug.write(GetEnvironmentString(I));
    //end;
    
    PathInfo := GetEnv('Path_Info');
    DecodeProgramNameAndMethod(PathInfo,ProgramName,MethodName);
    ServerPath := GetServerPath(PathInfo);
      
    RequestMethod := GetEnv('REQUEST_METHOD');
    if criptografa and (RequestMethod <> 'POST') then
       raise Exception.Create('Requisição inválida');

    Entrada := '';
    if  GEtEnv('CONTENT_LENGTH') > '' then
    begin
      Tamanho := strtoint( GEtEnv('CONTENT_LENGTH'));
      if Tamanho > 0 then
      begin
        FileMode := fmOpenRead;
        assignfile(f,'');
        reset(f,1);
        setlength(Entrada,tamanho);
        posicao := 1;
        tamanhoFaltando := tamanho;
        repeat 
          blockread(f,Entrada[posicao],tamanhofaltando,tamanhoLido);
          posicao := posicao + tamanhoLido;
          tamanhofaltando := tamanhofaltando - tamanhoLido;
        until tamanhoFaltando=0;
        close(f);
      end;
    end
    else if (GetEnv('HTTP_TRANSFER_ENCODING') = 'chunked') then
    begin
      readln(linha);
      while (linha <> '') and not eof(input) do
      begin
        entrada := entrada + linha;
        readln(linha);
      end;
      entrada := entrada + linha;
    end;
    {$IFDEF LINUX}
    if wini.ApiAppId <> '' then
      VerificaIntegridadeDaMensagem(Entrada,GetEnv('HTTP_X_ITAU_MSG_SIGN'),
                                    GetEnv('HTTP_X_ITAU_APIKEY'),
                                    GetEnv('HTTP_AUTHORIZATION'),
                                    GetEnv('HTTP_AUTHORIZATION_ITAU'),
                                    GetEnv('HTTP_X_ITAU_CORRELATIONID'),
                                    GetEnv('REMOTE_ADDR'),
                                    PathInfo
                      );
    {$ENDIF}

    if (wini.HUBToken > '') and (wini.HUBToken <> GetEnv('http_prognum_hub_token')) then begin
      writeln('Content-Type: text/html; charset=utf-8');
      writeln('Status: 401 Unauthorized');
      writeln(#10#13);
      writeln('<h1>Unauthorized</h1>');
      exit;
    end;
    
    EstaCripto := false;
    if (copy(entrada,1,4) = '____') then
    begin
      Entrada := utf8toansi(DescriptografaAES(convBarraU(Entrada)));
      EstaCripto := true;
    end
    else
    begin // Só é permitido em modo de desenvolvimento sem criptografia
      if criptografa then
          raise Exception.Create('Requisição inválida');
      Entrada := utf8toansi(convBarraU(Entrada));
    end;


    Params := TpXml.Create;
    DecodeParams(GetEnv('QUERY_STRING'),Params);
    if GetEnv('HTTP_X_ITAU_APIKEY') > '' then
      Params.add('HTTP_AUTHORIZATION').AsString := GetEnv('HTTP_X_ITAU_APIKEY')
    else
      Params.add('HTTP_AUTHORIZATION').AsString := GetEnv('HTTP_AUTHORIZATION');
    Params.add('HTTP_X_ITAU_CORRELATIONID').AsString :=  GetEnv('HTTP_X_ITAU_CORRELATIONID');
    Params.Add('REMOTE_ADDR').AsString := GetEnv('REMOTE_ADDR');
    if trim(GetEnv('HTTP_userName')) > '' then
      Params.addOrGet('USERNAME').asstring := GetEnv('HTTP_userName');
    if trim(GetEnv('HTTP_sessionKey')) > '' then
      Params.addorGet('SESSIONKEY').asstring := GetEnv('HTTP_sessionKey');
    if trim(GetEnv('HTTP_ambienteOperacional')) > '' then
      Params.addOrGet('AMBIENTEOPERACIONAL').asstring := GetEnv('HTTP_ambienteOperacional');
    if RequestMethod <> 'GET' then
      if wini.HUBToken > '' then
        DecodeParamsToNode(Entrada, Params.add('corpo_req'))
      else
        DecodeParams(Entrada,Params);
    if EstaCripto then // Se não vier o RequestMethod assume get se está criptografado
    begin
      if assigned(Params['requestMethod']) then 
        RequestMethod := Params['requestMethod'].AsString;
      if RequestMethod = '' then
        RequestMethod := 'GET';
    end;
    if assigned(Params['programName']) then
      ProgramName := params['programName'].AsString;
    if assigned(Params['methodName']) then
    begin
      MethodName := params['methodName'].AsString;
    end;

    if (wini.HUBToken > '') then begin
      Params.add('query_string').asString := GetEnv('QUERY_STRING');
      Params.addorget('USERNAME').asString := 'loginintegracao';
      Params.addorget('SESSIONKEY').asString := wini.HUBSessionKey;
      Params.add('url_whub').asString := GetEnv('SERVER_NAME')+GetEnv('REQUEST_URI');
      if GetEnv('http_prognum_hub_integration') > '' then
        Params.add('NU_INTEGRACAO').asInteger := StrToInt(GetEnv('http_prognum_hub_integration'))
      else
        raise exception.create('Necessário informar o código da integração.');
      IncluiHeaders(Params.add('headers'));
    end;

    if (length(MethodName)>0) then MethodName[1] := UpCase(MethodName[1]);
    if      (RequestMethod = 'GET')    then MethodName := 'Get' + MethodName
    else if (RequestMethod = 'POST')   then MethodName := 'Post' + MethodName
    else if (RequestMethod = 'PUT')    then MethodName := 'Put' + MethodName
    else if (RequestMethod = 'DELETE') then MethodName := 'Delete' + MethodName
    else if (RequestMethod = 'HEAD')   then MethodName := 'Head' + MethodName
    else if (RequestMethod = 'OPTIONS')then MethodName := 'Options' + MethodName;

    //validar o ambiente informado contra a definição no w.ini
    if wini.ambienteOperacional > '' then begin
      if (length(params['AMBIENTEOPERACIONAL'].asString)>0) and 
         (copy(params['AMBIENTEOPERACIONAL'].asString,length(params['AMBIENTEOPERACIONAL'].asString),length(params['AMBIENTEOPERACIONAL'].asString))='/') then
        params['AMBIENTEOPERACIONAL'].asString := copy(params['AMBIENTEOPERACIONAL'].asString,1,length(params['AMBIENTEOPERACIONAL'].asString)-1);
      if (length(wini.ambienteOperacional)>0) and 
         (copy(wini.ambienteOperacional,length(wini.ambienteOperacional),length(wini.ambienteOperacional))='/') then
        wini.ambienteOperacional := copy(wini.ambienteOperacional,1,length(wini.ambienteOperacional)-1);
      if params['AMBIENTEOPERACIONAL'].asString = '' then
        params.AddOrGet('AMBIENTEOPERACIONAL').asString := wini.ambienteOperacional
      else if params['AMBIENTEOPERACIONAL'].asString <> wini.ambienteOperacional then
       raise Exception.Create('Ambiente operacional inválido.');
    end;
    if Params['userName'].asString = '' then
      Params.addorget('userName').asString := wini.usuarioWeb;

    if ValidaMetodo(ProgramName, MethodName) then
    try
      if MethodName = 'PostLogin' then
        DoLogin(Server,Port,Contexto,Params)
      else if MethodName = 'PostPassword' then
        Password(Server,Port,Contexto,Params)
      else if MethodName = 'PostLogoff' then
        DoLogoff(Server,Port,Params)
      else if MethodName = 'GetHup' then
        DoHup(Server,Port,Params)
      else if MethodName = 'GetParamsOauth' then
        GetParamsOauth()
      else if MethodName = 'PostRedefinirSenha' then
        RedefinirSenha(Server,Port,Contexto,Params)
      {$IFDEF LINUX}
      else if MethodName = 'GetVersion' then
        GetVersion()
      {$ENDIF}
      else 
        DoRemoteCall(Server,Port,ServerPath,ProgramName,MethodName,Params);
    finally
      Params.free;
    end;
  except
    on E:Exception do
    begin
      p := tpxmlnode.create(nil);
      p.nodeName := '';
      p.addChild('success').AsBoolean := false;
      p.addChild('message').AsString := E.Message;
      writeln('Content-Type: application/json; charset=utf-8',#10#13);
      write(codifica(p.tojson(0,false)));
      p.free;
    end;
  end;
  Debug.free;
end.
