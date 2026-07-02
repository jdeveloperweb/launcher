program loginAD;

uses
{$IFDEF LINUX}
{$IFDEF FPC}
  unix,
{$ELSE}
  Libc, 
{$ENDIF}
{$ENDIF}
  punix,
  ssl_openssl, ssl_openssl11, ssl_openssl3,
  SysUtils, ldapsend, Classes, 
  xdb,pdb,uloglib,
  scciio, aelib;

{
procedure debug(st:string);
var f : text;
begin
assign (f,'/tmp/t.txt');
append(f);
writeln(f,st);
close (f);
end;
}

function GeraDC ( domain : ansistring) : ansistring;
begin
  domain := trim (domain);
  result := '';
  repeat
    if pos('.',domain)>0 then
    begin
      Result := Result + 'dc='+copy(domain,1,pos('.',domain)-1)+',';
      delete( domain,1,pos('.',domain));
    end
    else
    begin
      Result := Result + 'dc=' + domain;
      domain := '';
    end;
  until length(domain) = 0;
end;


function unicode(st:string) :string;
var wst : string; i :integer;
begin
  wst := '';
  for i := 1 to length(st) do
    wst := wst + st[i] + char(0);
  unicode := wst;
end;

function GeraToken(usuario,senha : string ) : string;
begin
  result := char(length(usuario) mod 10 +ord('0')) + floattostr( now + ord(usuario[1]) shr 20 + ord(senha[1]) shr 12) + char(length(senha) mod 10 + ord('0'));
end;

function UsuarioExisteNoScci(usuario : string) : boolean;
var
  Qry : TSqlQuery;
  UserField : AnsiString;
begin
  Qry := TSQLQuery.Create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Userfield := '';
    GetCEnv ('USERFIELD', UserField);
    if UserField <> 'CO_USUARIO' then // igual ao wcadastro
      Qry.SQL.Add('select usuario from USUARIO where usuario=:usuario')
    else
      Qry.SQL.Add('select co_usuario from USUARIO where co_usuario=:usuario');
    Qry.ParamByName('usuario').Datatype := ftstring;
    Qry.ParamByName('usuario').asstring := usuario;
    Qry.Open;
    result := not Qry.IsEmpty and (Qry.Fields[0].asstring=usuario); // No MSSQL a busca de strings é CASE-INSENSITIVE por default, então eu preciso testar se o usuario encontrado está igual de fato ao usuário informado
  finally
    Qry.free;
  end;
end;

function ExecutaPasswdAD(Servico,Identificacao,Usuario,Senha,
                             NovaSenha : AnsiString ): boolean;
var
  PasswordOK: boolean;
  Lattribs: TLDapAttribute;
  FLdap : tldapsend;
begin
  lAttribs := Tldapattribute.Create;
  fldap := TLDAPSend.Create;
  PasswordOK := false;
  try
    if UpperCase(copy(Servico,1,7)) = 'LDAP://' then 
      Servico := copy(Servico,8,length(Servico))
    else if UpperCase(copy(Servico,1,8)) = 'LDAPS://' then 
           Servico := copy(Servico,9,length(Servico));
    FLdap.TargetHost := Servico;
    FLdap.UserName := Usuario+'@'+Identificacao;
    fldap.TargetPort:= '636';
    fldap.FullSSL := true;
    fldap.Password := Senha;
    if fldap.Login then
    begin
      if fldap.Bind then 
      begin
        lattribs.AttributeName := ('unicodePwd');
        lAttribs.Add(unicode('"'+NovaSenha+'"'));
        try
          if not fldap.Modify('CN='+Usuario+',CN=Users,'+GeraDC(Identificacao),MO_Replace,lattribs) then
            raise exception.Create('Erro ao trocar a Senha '+fldap.ResultString)
          else PasswordOK := true;
        except
           raise exception.Create('Erro ao trocar a Senha '+fldap.ResultString);
        end;
      end
      else raise exception.Create('Usuário ou senha incorreto. Por favor tente novamente.');
    end
    else raise exception.create('Nao conseguiu estabelecer conexao com : '+Servico +' '+FLDap.ResultString);
  finally 
    FreeAndNil(FLdap);
    FreeAndNil(LAttribs);
  end;
  result :=  PasswordOk ;
end;


function ExecutaLoginAD(Servico, Identificacao, IP,Usuario : AnsiString;
                        var Senha : AnsiString ): boolean;
var
  FLdap   :tldapsend;
begin
  result := false;
  FLdap := TLDAPSend.Create;
  try
    FLdap.UserName := Usuario+'@'+Identificacao;
    FLdap.Password := Senha;
    if UpperCase(copy(Servico,1,7)) = 'LDAP://' then Servico := copy(Servico,8,length(Servico))
    else if UpperCase(copy(Servico,1,8)) = 'LDAPS://' then
    begin
      Servico := copy(Servico,9,length(Servico));
      fldap.TargetPort:= '636';
      fldap.FullSSL := true;
    end;
    FLdap.TargetHost := Servico;
    if fldap.Login then
    begin
      if fldap.Bind then result := true
      else raise exception.create('Usuário ou senha incorreto. Por favor tente novamente.');
    end
    else raise exception.create('Nao conseguiu estabelecer conexao com : '+Servico);
    Senha := GeraToken(usuario,Senha);
//    Conn := GetSqlConnection(PegaDirTab);  TestaUsuario(Conn,Usuario); //  a definir
  finally
    FLdap.logout;
    FLdap.Free;
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
  Expirada := false;
  NovaSenha := '';
  OpStr := '';
  MsgErro := '';
  ChaveSecao := '';
  URL := '';
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
      else 
      begin
        readlv(CanalLeitura,Servico);
        readlv(CanalLeitura,IdStr);
        readlv(CanalLeitura,OpStr);
        readlv(CanalLeitura,Usuario);
        readlv(CanalLeitura,Senha);
        readlv(CanalLeitura,NovaSenha);
      end;

    // Ir no AD
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
          if ExecutaLoginAD(Servico,IdStr,IP,usuario,Senha) and UsuarioExisteNoScci(usuario) then
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
      else if OpStr = 'VALIDA' then
      begin
        if usuario = 'usuarioweb' then begin
            writelv(CanalEscrita,'T'+Senha)
        end
        else begin
          if ExecutaValidaBD(Servico,IdStr,Usuario,Senha,Expirada) then
            writelv(CanalEscrita,'T'+Senha)
          else if Expirada then writelv(CanalEscrita,'E'+Senha)
          else writelv(CanalEscrita,'F'+Senha);
        end
      end      
      else if OpStr = 'PASSWD' then
      begin
       if ExecutaPasswdAD(Servico,IdStr,getenv('USER'),Senha,NovaSenha) then
          writelv(CanalEscrita,'T'+Senha)
        else writelv(CanalEscrita,'F'+Senha);
      end;
    end
    else writelv(CanalEscrita,'FUsuario não informado');
       // Envia false e mensagem de erro
    except 
      on e : exception do
//    writelv(CanalEscrita,'FErro de execução no loginad: '+E.message+char(13)+' OPSTR '+OpStr+' SERV '+Servico+' USR '+Usuario);
        writelv(CanalEscrita,'F'+E.message+char(13));
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

