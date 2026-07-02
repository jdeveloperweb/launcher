program loginunicred; // sol. 87285

uses
  SysUtils, Classes, synautil, punix, smv,
  ssl_openssl, ssl_openssl11, ssl_openssl3, lib1, datalib, scciio, sccidef, pdb, xdb, ctrlib, sccilib,
  uloglib, ucontrato,complib,unix,  aelib, pcrypt, pIniFiles;


var
  NomeArq : ansistring;

(*
procedure depura(st : ansistring);
var
  txt : text;
  filename : ansistring;
begin
  filename := pegadirtab+pathdelim+'depuracao.log';
  assign(txt,filename);
  if fileExists(filename) then
    append(txt)
  else
    rewrite(txt);
  try
    writeln(txt,st);
  finally
    close(txt);
  end;      
end;    
*)

function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

procedure ParseParametros(Var Usuario,
                              senha,
                              Entidade,
                              Nome,
                              Token : ansistring);
var
  Parametros : THashedStringlist;
  i : integer;
  Entrada : ansistring;
begin
  Entidade := '';
  Nome := '';

  Parametros := THashedStringlist.create;
  try
    Parametros.commatext := copy(senha,6,length(senha)); // '!#___'senha
    
    // "jwt_id_identifier": "nome.sobrenome.0060" > Usuário: nome.sobrenome / Entidade:60 - sol. 90882
    Entrada := Parametros.values['jwt_id_identifier'];
    
    // ando da direita para esquerda até achar o primeiro "."
    // o primeiro bloco lido é a entidade
    i := length(entrada);
    while (i > 0) and (entrada[i] <> '.') do begin
      Entidade := entrada[i] + Entidade;
      dec(i);
    end;

    // todo o restante para esquerda será o nome, excluindo o "." divisor
//    if i > 0 then
//    Nome := copy(Entrada,1,i-1);
    Nome := Entrada;

    Token := Parametros.values['token_tag'];
    Usuario := nome;
  finally
    Parametros.free;
  end;
end;

function UsuarioSubordinadoAEntidade(usuario : string; entidadeInformada : string) : boolean;
var
  Query : TSqlQuery;
  EntidadePrimaria,
  EntidadeSecundaria : integer;
begin
  if EntidadeInformada > '' then begin
    
    result := false; // não usuario não tem entidades configuradas, não tem como ser subordinado
    
    EntidadePrimaria := EntidadePrimariaUser(Usuario);
    EntidadeSecundaria := EntidadeSecundariaUser(Usuario);
    
    if (EntidadePrimaria > -1) and
       ((EntidadePrimaria=valint(EntidadeInformada)) or
        (EntidadeSubordinadaAEntidade(EntidadePrimaria,valint(EntidadeInformada)))) then // se tem Ent. Primaria, tenta ver se é subordinada a informada
      result := true
    else if (EntidadeSecundaria > -1) and
            ((EntidadeSecundaria=valint(EntidadeInformada)) or
             (EntidadeSubordinadaAEntidade(EntidadeSecundaria,valint(EntidadeInformada)))) then // se tem Ent. Secundaria, tenta ver se é subordinada a informada
      result := true;
  end
  else begin
    result := true; // se não informou entidade, não faz qualquer critica
  end;
end;

function ExecutaLoginUnicred  (    Usuario : ansistring;
                               Var Senha : ansistring;
                               Var Expirada : boolean;
                               Var Token : ansistring) : boolean;
var
  Query : TSqlQuery;
  st : string;
  parmEntidade,
  parmNome : ansistring;
begin
  result := false;
  ParmEntidade := '';
  parmNome := '';
  get_hora(horaH);
  st := WebDecrypt(senha);
  if copy(st,1,5) = '!#___' then begin
    ParseParametros(Usuario,st,ParmEntidade,ParmNome,Token);
    if trim(ParmNome) = '' then
      ParmNome := usuario;
    if length(Usuario) > 20 then
      raise exception.create('Nome do usuário('+Quotedstr(usuario)+') maior que o máximo permitido');
    if UsuarioSubordinadoAEntidade(Usuario,ParmEntidade) then begin
      Query := TSqlQuery.Create(nil);
      try
        Senha := GeraToken(usuario,Senha); // igual ao loginailos. Não entendi pq não gravou no banco.
        Query.SqlConnection := GetSqlConnection(PegaDirTab);
        Query.Sql.Add('SELECT usuario,ENT_PRIMARIA FROM USUARIO');
        Query.Sql.Add('WHERE USUARIO = ' + QuotedStr(Usuario) +' OR NO_E_MAIL_EMISSAO = '+QuotedStr(Usuario));
        Query.Open;
        if Query.Eof then
          raise exception.create('Usuário não cadastrado no SCCI. Por favor entre em contato com o suporte para verificar o seu cadastro.');
        result := true;
      finally
        FreeAndNil(Query);
      end;
    end
    else
      raise exception.create('Usuário não subordinado a entidade informada');
  end
  else
    raise exception.create('Senha incorreta');
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

procedure GravaSection(ID,Usuario,IP,Token : string);
var
  QRY : TSQLQuery;
  Stream : TStringStream;
begin
  QRY := TSQLQuery.Create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.SQL.Add('insert into SCCI_SESSION (SESSION_KEY,NO_USUARIO,NU_IP_ACESSO,DT_HORA_SOLICITACAO,TOKEN) values ('+QuotedStr(ID)+','+QuotedStr(usuario)+','+QuotedStr(ip)+',:wdt,:TOKEN)');
    Qry.ParamByName('wdt').Datatype := ftDateTime;
    Qry.ParamByName('wdt').asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);

    Stream := TStringStream.create(Token);
    try
      Stream.position := 0;
      Qry.ParamByName('TOKEN').loadfromstream(stream,ftblob);
    finally
      Stream.free;
    end;
    Qry.ExecSQL;
    Qry.close;
  finally
    Qry.Free;
  end;
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
  QTDMAXLOGIN : integer;
  Token : ansistring;

begin
  Token := '';
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
  QTDMAXLOGIN := 0;
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
          if usuario = 'usuarioweb' then begin
            if ExecutaLoginScci(Usuario,Senha,Expirada) then
              writelv(CanalEscrita,'T'+Senha)
            else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
          else begin
            try if NovaSenha <> '' then QTDMAXLOGIN := strtoint(NovaSenha); except QTDMAXLOGIN := 0; end;
            try
              if ExecutaLoginUnicred(usuario,Senha,Expirada,Token) then
              begin
                writelv(CanalEscrita,'T'+Senha);
                if QTDMAXLOGIN > 1 then ValidaQtdLogin(QTDMAXLOGIN,usuario);
                GravaSection(Senha,Usuario,IP,Token);
              end else raise exception.create('Erro pedindo credenciais');
            except
              on e : exception do begin
                writelv(CanalEscrita,'F'+e.message);
              end;  
            end;  
          end;
// Para implementar Senha expirada enviar 'E' no lugar do F
        end
        else if OpStr = 'PASSWD' then
        begin
          writelv(CanalEscrita,'F'+Senha);
        end
        else if OpStr = 'VALIDA' then
        begin
          if usuario = 'usuarioweb' then begin
            if ExecutaLoginScci(Usuario,Senha,Expirada) then
              writelv(CanalEscrita,'T'+Senha)
            else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
          else begin
            if ExecutaValidaBD(Servico,IdStr,Usuario,Senha,Expirada) then
              writelv(CanalEscrita,'T'+Senha)
            else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
        end
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
  else system.writeln( 'Parametros Incorretos');
end.
