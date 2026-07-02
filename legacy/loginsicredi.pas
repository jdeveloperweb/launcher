program loginsicredi;

uses
  SysUtils, Classes, HTTPSend, pxmllib, synautil, punix, smv,bdlib,
  ssl_openssl, ssl_openssl11, ssl_openssl3, lib1, datalib, scciio, sccidef, pdb, xdb, ctrlib, sccilib,
  uloglib, ucontrato,complib,unix,pcrypt;
  
const
  cPrefixoGrupo = 'prgscci_';
  cSenha_SiteMinder = '!_____';

var
  NomeArq : ansistring;

debug : text;

procedure RegistraSaida(st : ansistring);
var
  txt : text;
begin
  if NomeArq <> '' then begin
    assign(txt,NomeArq);
    append(txt);
    writeln(txt,st);
    close(txt);
  end;
end;

function DiretorioWebService : ansistring;
var
  Diretorio : ansistring;
begin
  Diretorio := GetEnv('SCCIDIRARQS')+PathDelim+'webservice';
  if not DirectoryExists(Diretorio) then begin
    punix.Shell('mkdir '+Diretorio);
    punix.Shell('chmod o+w '+Diretorio);
  end;
  Result := Diretorio;
end;

function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

function RetornaSequencial : integer;
var
  Arq         : ansistring;
  StSeq       : TStringList;
  Seq         : integer;
begin
  Arq := DiretorioWebService()+PathDelim+'sequencia.txt';
  StSeq := TStringList.create;
  try
    if FileExists(Arq) then begin
      StSeq.LoadFromFile(Arq);
      Seq := ValInt(StSeq[0]);
    end
    else Seq := 0;
    inc(Seq);
    StSeq.clear;
    StSeq.add(IntStr(Seq));
    StSeq.SaveToFile(Arq);
  finally
    StSeq.free;
  end;
  Result := Seq;
end;

function HttpPostURLXML(const URL, URLData: AnsiString; const Data: TStream): Boolean; overload;
var
  HTTP: THTTPSend;
begin
  HTTP := THTTPSend.Create;
  try
    RegistraSaida('comunicação - Url       : '+URL);
    RegistraSaida('comunicação - Dados     : '+URLData);
    WriteStrToStream(HTTP.Document, URLData);
    HTTP.MimeType := 'text/xml';
    Result := HTTP.HTTPMethod('POST', URL);
    if Result then
      Data.CopyFrom(HTTP.Document, 0);
    if Result then
      RegistraSaida('comunicação - Resposta  : Comunicação OK')
    else
      RegistraSaida('comunicação - Resposta  : Sem conexão');
  finally
    HTTP.Free;
  end;
end;

function ValidaEntidade(entidade : string; Var EntidadeUsuario : integer) : boolean;
var
  Query : TSqlQuery;
begin
  Query := TSqlQuery.create(nil);
  try
    Query.sqlconnection := GetSqlConnection(pegaDirTab);
    Query.sql.add('SELECT COD_ENT FROM ENTIDADES WHERE COD_ENT='+inttostr(valint(entidade)));
    Query.open;
    result := not Query.isempty;
    if result then
      EntidadeUsuario := Query.fields[0].asinteger
    else
      EntidadeUsuario := -1;
  finally
    Query.free;
  end;
end;

function ValidaPerfil(perfil : string; var PerfilUsuario : integer) : boolean;
var
  Query : TSqlQuery;
begin
  Query := TSqlQuery.create(nil);
  try
    Query.sqlconnection := GetSqlConnection(pegaDirTab);
    Query.sql.add('SELECT COD_PERFIL FROM PERFIL WHERE NOME_PERFIL='+quotedstr(perfil));
    Query.open;
    result := not Query.isempty;
    if result then
      PerfilUsuario := Query.fields[0].asinteger
    else
      PerfilUsuario := -1;
  finally
    Query.free;
  end;
end;

function buscarPerfilUsuario(    usuario:AnsiString;
                                 URL: AnsiString;
                             var EntidadeUsuario : integer;
                             var PerfilUsuario : integer;
                             var NomeUsuario : string;
                                 GeraArq, SimulaRet : boolean) : boolean;
var
  response: TMemoryStream;
  xml: TpXml;
  p : TpXmlNode;
  i : integer;
  Seq : integer;
  Processa : boolean;
  St : ansistring;
  Prefixo : string;
  oidGrupo : string;
  entidade : string;
  UsuarioNode,
  perfilUsuarioNode : tpxmlnode;
  Node : TpXmlnode;
  Nodename : string;
  posFimNameSpace : integer;
begin
  result := false;
  EntidadeUsuario := -1;
  PerfilUsuario := -1;

  response := TMemoryStream.Create;
  xml := TpXml.Create;
  if GeraArq or SimulaRet then Seq := RetornaSequencial();
  try
    p := xml.DocumentElement;
    p.NodeName := 'soapenv:Envelope';
    p.Attributes['xmlns:soapenv'] := 'http://schemas.xmlsoap.org/soap/envelope/';
    p.Attributes['xmlns:org'] := 'http://organizacional.estrutura.servicos.sicredi.com.br/';
    p.add('soapenv:Header');
    p := p.add('soapenv:Body');
    p := p.add('org:buscarPerfilUsuario');
    p := p.add('inBuscarPerfilUsuario');
    p.add('uidUsuario').asstring := usuario;
    if GeraArq or SimulaRet then
       xml.SaveToFile(DiretorioWebService()+PathDelim+'envio_buscarPerfilUsuario_'+intstr(Seq)+'.xml');
    Processa := true;
    if SimulaRet then Response.LoadFromFile(DiretorioWebService()+PathDelim+Url)
    else Processa := HttpPostUrlXML(url,xml.DocumentElement.code,Response);
    if Processa then begin
      if GeraArq or SimulaRet then
        response.saveTofile(DiretorioWebService()+PathDelim+'retorno_buscarPerfilUsuario_'+intstr(Seq)+'.xml');
      SetString(St,response.Memory,response.size);
      RegistraSaida('comunicação - retorno   : '+St);
      response.position := 0;
      try
        xml.parseStream(Response);
        Node := nil;
        p := xml['S:Body'];
//        p := xml['S:Body']['ns2:buscarPerfilUsuarioResponse']['outBuscarPerfilUsuario'];
        if assigned(p) then
          for i := 0 to p.count-1 do begin
            nodename := p[i].nodename;
            posFimNameSpace := pos(':',Nodename);
            if posFimNameSpace > 0 then
              nodename := copy(Nodename,posFimNameSpace+1,length(NodeName));
            if comparetext(Nodename,'buscarPerfilUsuarioResponse') = 0 then begin
              Node := p[i];
              break;
            end;
          end;
        p := Node;
        if assigned(p) then
          p := p['outBuscarPerfilUsuario'];
        if assigned(p) then begin
          for i := 0 to p.count-1 do begin
            perfilUsuarioNode := p[i];
            if assigned(perfilUsuarioNode['oidGrupo']) then begin
              oidGrupo := perfilUsuarioNode['oidGrupo'].asstring;
              if compareText(copy(oidGrupo,1,length(cPrefixoGrupo)),cPrefixoGrupo) = 0 then begin
                if assigned(perfilUsuarioNode['entidade']) then begin
                  entidade := perfilUsuarioNode['entidade']['oidEntidade'].asstring;
                  if ValidaEntidade(entidade,EntidadeUsuario) and
                     ValidaPerfil(oidGrupo,PerfilUsuario) then begin
                    result := true;
                    break;
                  end;
                end;
              end;
            end;
          end;
        end
        else
          raise exception.create('Erro na resposta do perfil');
      except
        on e : exception do begin
          raise exception.create('Falha ao obter dados de perfil do usuário');
        end;
      end;
    end
    else begin
      RegistraSaida('Não foi possível contactar o serviço Carregar Pessoa Produto.');
      raise exception.create('Não foi possível contactar o serviço Buscar Perfil Usuario.');
    end;
  finally
    Xml.free;
    response.free;
  end;

  response := TMemoryStream.Create;
  xml := TpXml.Create;
  if GeraArq or SimulaRet then Seq := RetornaSequencial();
  try
    p := xml.DocumentElement;
    p.NodeName := 'soapenv:Envelope';
    p.Attributes['xmlns:soapenv'] := 'http://schemas.xmlsoap.org/soap/envelope/';
    p.Attributes['xmlns:org'] := 'http://organizacional.estrutura.servicos.sicredi.com.br/';
    p.add('soapenv:Header');
    p := p.add('soapenv:Body');
    p := p.add('org:buscarUsuario');
    p := p.add('inBuscarUsuario');
    p.add('uidUsuario').asstring := usuario;
    if GeraArq or SimulaRet then
       xml.SaveToFile(DiretorioWebService()+PathDelim+'envio_buscarUsuario_'+intstr(Seq)+'.xml');
    Processa := true;
    if SimulaRet then Response.LoadFromFile(DiretorioWebService()+PathDelim+Url)
    else Processa := HttpPostUrlXML(url,xml.DocumentElement.code,Response);
    if Processa then begin
      if GeraArq or SimulaRet then
        response.saveTofile(DiretorioWebService()+PathDelim+'retorno_buscarUsuario_'+intstr(Seq)+'.xml');
      SetString(St,response.Memory,response.size);
      RegistraSaida('comunicação - retorno   : '+St);
      response.position := 0;
      try
        xml.parseStream(Response);
        if assigned(xml['S:Body']) and
           assigned(xml['S:Body']['ns2:buscarUsuarioResponse']) and
           assigned(xml['S:Body']['ns2:buscarUsuarioResponse']['outBuscarUsuario']) then begin
          p := xml['S:Body']['ns2:buscarUsuarioResponse']['outBuscarUsuario'];
          for i := 0 to p.count-1 do begin
            UsuarioNode := p[i];
            if assigned(UsuarioNode['nome']) then begin
              NomeUsuario := copy(UsuarioNode['nome'].asstring,1,50);
              break;
            end;
          end;
        end
        else
          raise exception.create('Erro na resposta do usuario');
      except
        on e : exception do begin
          raise exception.create('Falha ao obter dados do usuário');
        end;
      end;
    end
    else begin
      RegistraSaida('Não foi possível contactar o serviço buscarUsuario.');
      raise exception.create('Não foi possível contactar o serviço Buscar Usuario.');
    end;
  finally
    Xml.free;
    response.free;
  end;
end;

function ObtemSetor(SqlConnection : TSqlConnection; perfil : integer; entidadeUsuario : integer):string;
var
  Query : TSqlQuery;

begin
  result := '';
  Query := TSqlQuery.create(nil);
  try
    Query.SqlConnection := SqlConnection;
    Query.sql.add('SELECT CO_SETOR FROM PERFIL_SETOR WHERE CO_PERFIL='+intstr(perfil)+' AND CO_ENT='+inttostr(entidadeUsuario));
    Query.open;
    if not Query.isEmpty then
      result := Query.fields[0].asstring;
    Query.close;
  finally
    Query.free;
  end;
end;

function ExecutaLoginSicredi(    Usuario : ansistring;
                             Var Senha : ansistring;
                                 Servico : ansistring;
                             Var Expirada : boolean) : boolean;
var
  Query : TSqlQuery;
  EntidadeUsuario : integer;
  PerfilUsuario : integer;
  GeraArq : boolean;
  SimulaRet : boolean;
  NomeUsuario : string;
begin
  if senha <> cSenha_SiteMinder then
    raise exception.create('Senha inválida');

  result := false;
  EntidadeUsuario := -1;
  PerfilUsuario := -1;
  NomeUsuario := '';
  get_hora(horaH);

  GeraArq := false;
  SimulaRet := false;
  if pos(';',servico) > 0 then begin
    if UpStr(copy(servico,1,pos(';',servico)-1)) = 'GERAARQUIVOS' then
      GeraArq := true
    else if UpStr(copy(servico,1,pos(';',servico)-1)) = 'SIMULARETORNO' then
      SimulaRet := true;
    servico := copy(servico,pos(';',servico)+1,Length(servico));
  end;

  if buscarPerfilUsuario(usuario,servico,EntidadeUsuario,
                         PerfilUsuario,NomeUsuario,GeraArq,SimulaRet) then begin
    Query := TSqlQuery.Create(nil);
    try
      Query.SqlConnection := GetSqlConnection(PegaDirTab);
      Query.Sql.Add('SELECT * FROM USUARIO');
      Query.Sql.Add('WHERE USUARIO = ' + QuotedStr(Usuario));
      Query.Open;
      if not Query.Eof then begin
        // já existe, setar perfil e grupo
        Query.close;
        Query.sql.clear;
        Query.sql.add('UPDATE USUARIO');
        Query.sql.add('SET PERF_PRIMARIO=:PERF_PRIMARIO,');
        Query.sql.add('ENT_PRIMARIA=:ENT_PRIMARIA,');
        Query.sql.add('ALT_USUARIO=:ALT_USUARIO,');
        Query.sql.add('ALT_DATA=:ALT_DATA,');
        Query.sql.add('CO_SETOR=:CO_SETOR,');
        Query.sql.add('NOME=:NOME');
        Query.sql.add('WHERE');
        Query.sql.add('USUARIO=:USUARIO');
      end
      else begin
        // não existe, incluir
        Query.close;
        Query.sql.clear;
        Query.sql.add('INSERT INTO USUARIO');
        Query.sql.add('(USUARIO,PERF_PRIMARIO,ENT_PRIMARIA,ALT_USUARIO,ALT_DATA,SENHA,CO_SETOR,NOME,UIDUSUARIO)');
        Query.sql.add('VALUES');
        Query.sql.add('(:USUARIO,:PERF_PRIMARIO,:ENT_PRIMARIA,:ALT_USUARIO,:ALT_DATA,:SENHA,:CO_SETOR,:NOME,:UIDUSUARIO)');

        Query.parambyname('SENHA').datatype := ftstring;
        Query.parambyname('SENHA').asstring := WebCrypt(cSenha_SiteMinder);
        Query.parambyname('UIDUSUARIO').datatype := ftinteger;
        Query.parambyname('UIDUSUARIO').asinteger := LeGenerator(Query.SqlConnection,'GEN_UID_USUARIO');;
      end;
      Query.parambyname('USUARIO').datatype := ftstring;
      Query.parambyname('PERF_PRIMARIO').datatype := ftinteger;
      Query.parambyname('ENT_PRIMARIA').datatype := ftinteger;
      Query.parambyname('ALT_USUARIO').datatype := ftstring;
      Query.parambyname('ALT_DATA').datatype := ftdatetime;
      Query.parambyname('CO_SETOR').datatype := ftstring;
      Query.parambyname('NOME').datatype := ftstring;

      Query.parambyname('USUARIO').asstring := Usuario;
      Query.parambyname('PERF_PRIMARIO').asinteger := perfilUsuario;
      Query.parambyname('ENT_PRIMARIA').asinteger := entidadeUsuario;
      Query.parambyname('ALT_USUARIO').asstring := 'automatico';
      Query.parambyname('ALT_DATA').asdatetime := datatodatetime(DataH)+horaTodatetime(horaH);
      Query.parambyname('CO_SETOR').asstring := ObtemSetor(Query.SqlConnection,perfilusuario,entidadeUsuario);
      Query.parambyname('NOME').asstring := NomeUsuario;

      Query.execsql;

    finally
      FreeAndNil(Query);
    end;
    // Senha := WebCrypt(cSenha_SiteMinder);
    Senha := GeraToken(Usuario, Senha);
    result := true;
  end
  else
    raise exception.create('Não foi possível localizar perfil e entidade do usuário');
end;
(*

function ExecutaLoginSicredi(    Usuario : ansistring;
                             Var Senha : ansistring;
                                 Servico : ansistring;
                             Var Expirada : boolean) : boolean;
var
  Query : TSqlQuery;
  EntidadeUsuario : integer;
  PerfilUsuario : integer;
  GeraArq : boolean;
  SimulaRet : boolean;
begin
  result := false;
  EntidadeUsuario := -1;
  PerfilUsuario := -1;
  get_hora(horaH);

  GeraArq := false;
  SimulaRet := false;
  if pos(';',servico) > 0 then begin
    if UpStr(copy(servico,1,pos(';',servico)-1)) = 'GERAARQUIVOS' then
      GeraArq := true
    else if UpStr(copy(servico,1,pos(';',servico)-1)) = 'SIMULARETORNO' then
      SimulaRet := true;
    servico := copy(servico,pos(';',servico)+1,Length(servico));
  end;

  Query := TSqlQuery.Create(nil);
  try
    Query.SqlConnection := GetSqlConnection(PegaDirTab);
    Query.Sql.Add('SELECT * FROM USUARIO');
    Query.Sql.Add('WHERE USUARIO = ' + QuotedStr(Usuario));
    Query.Open;
    if not Query.Eof then begin
      // já existe, setar perfil e grupo
      if Senha <> cSenha_SiteMinder then
        raise exception.create('Senha inválida');
      Senha := WebCrypt(cSenha_SiteMinder);
    end;
  finally
    FreeAndNil(Query);
  end;
  result := true;
end;
*)

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

var
  CanalLeitura,
  CanalEscrita : Integer; 
  OpStr,
  Novasenha,
  URL,
  ChaveSecao,
  MsgErro,
  Servico,
  IdStr: AnsiString;
  Usuario,
  Senha,
  IP : AnsiString;
  Expirada : boolean;
  QtdMaxLogin : Integer;
begin

{ usar o debug para depurar

assign(debug,'/u10/sicredi/suporte/scat60866/debug.txt');
if fileexists('/u10/sicredi/suporte/scat60866/debug.txt') then
  append(debug)
else
  rewrite(debug);

try
}

  NomeArq := '';
  Expirada := false;
  NovaSenha := '';
  OpStr := '';
  MsgErro := '';
  ChaveSecao := '';
  URL := '';
  OpStr := '';
  NovaSenha := '';
  CanalLeitura := 0;
  CanalEscrita := 1;
  QtdMaxLogin := 0;
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
      else begin
        readlv(CanalLeitura,Servico);
        readlv(CanalLeitura,IdStr);
        readlv(CanalLeitura,OpStr);
        readlv(CanalLeitura,Usuario);
        readlv(CanalLeitura,Senha);
        readlv(CanalLeitura,NovaSenha);
      end;

      if (trim(Usuario) <> '') then
      begin
        if OpStr = 'LOGIN' then
        begin
          try if NovaSenha <> '' then QtdMaxLogin := StrToInt(NovaSenha); except QtdMaxLogin := 0; end;
          if ExecutaLoginSicredi(Usuario,Senha,Servico,Expirada) then begin
            writelv(CanalEscrita,'T'+Senha);
            if QtdMaxLogin > 1 then ValidaQtdLogin(QtdMaxLogin, usuario);
            GravaSection(Senha,Usuario,IP,Usuario);
          end
          else if Expirada then
            writelv(CanalEscrita,'E'+Senha)
          else
            writelv(CanalEscrita,'F'+Senha);
        end
        else if OpStr = 'PASSWD' then
        begin
          writelv(CanalEscrita,'F'+Senha);
        end
        else if OpStr = 'VALIDA' then
        begin
          if ExecutaValidaBD(Servico,IdStr,Usuario,Senha, Expirada) then
            writelv(CanalEscrita,'T'+Senha)
          // nao pode devolver o 'E' porque nao existe tratamento para revalidar a seção
          // else if Expirada then writelv(CanalEscrita, 'E'+Senha) 
          else writelv(CanalEscrita,'F'+Senha);
        end
      end
      else writelv(CanalEscrita,'FUsuario não informado');
    // Envia false e mensagem de erro
    except
      on e : exception do begin
//    writelv(CanalEscrita,'FErro de execução no loginsicredi: '+E.message+char(13)+' OPSTR '+OpStr+' SERV '+Servico+' USR '+Usuario);
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
  else system.writeln( 'Parametros Incorretos');
{
finally
close(debug);
end;
}
end.

