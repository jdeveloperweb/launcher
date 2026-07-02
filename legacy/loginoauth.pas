program loginoauth;

uses
  SysUtils, Classes, synautil, punix, smv, md5lib,
  ssl_openssl, ssl_openssl11, ssl_openssl3, lib1, datalib, scciio, sccidef, pdb, xdb, ctrlib, sccilib,
  uloglib, ucontrato,complib,unix,  aelib;

  
var
  NomeArq : ansistring;

//	debug : text;

function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

{
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
}

function ExecutaLoginoauth(    Usuario : ansistring;
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
  if senha = md5crypt(usuario,'$1$'+usuario) then
  begin
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
      Query.Sql.Add('SELECT usuario FROM USUARIO');
      Query.Sql.Add('WHERE USUARIO = ' + QuotedStr(Usuario) +' OR NO_E_MAIL_EMISSAO = '+QuotedStr(Usuario));
      Query.Open;
      if not Query.Eof then begin
        Senha := GeraToken(usuario,Senha);
        result := true;
      end;
    finally
      FreeAndNil(Query);
    end;
  end;
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

begin

{ usar o debug para depurar

assign(debug,'/tmp/debug.txt');
if fileexists('/tmp/debug.txt') then
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
            if ExecutaLoginOauth(usuario,Senha,Servico,Expirada) then
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
              GravaSection(Senha,Usuario,IP);
            end else writelv(CanalEscrita,'F'+'erro'+Senha);
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

{

finally
close(debug);
end;

}
end.

