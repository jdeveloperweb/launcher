program loginDireto;

uses SysUtils, lib1, pdb, scciio, xdb, parmlib, uloglib, punix, fpjwt, fpjwasha256,
     Classes, synautil, DateUtils, unix, aelib, pcrypt, pxmllib;


function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

procedure GravaSection(ID,
                       Usuario,
                       IP : string;
                       Login : String = '';
                       SegundosExp: Integer = 0;
                       Token: AnsiString = '');
var
  QRY : TSQLQuery;
begin
  QRY := TSQLQuery.Create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.SQL.Add('insert into SCCI_SESSION (');
    Qry.SQL.Add('SESSION_KEY,NO_USUARIO,NU_IP_ACESSO,DT_HORA_SOLICITACAO');
    if Login > '' then Qry.SQL.Add(','+'LOGIN');
    if SegundosExp > 0 then Qry.SQL.Add(', NU_SEGUNDOS_EXPIRACAO');
    if Token > '' then Qry.SQL.Add(', TOKEN');
    Qry.SQL.Add(') values (');
    Qry.SQL.Add(QuotedStr(ID)+','+QuotedStr(usuario)+','+QuotedStr(ip)+',:wdt');
    if Login > '' then Qry.SQL.Add(','+QuotedStr(Login));
    if SegundosExp > 0 then begin 
      Qry.SQL.Add(',:exp');
      Qry.paramByName('exp').asInteger := SegundosExp;
    end;
    if Token > '' then begin
      Qry.SQL.Add(',:token');
      Qry.paramByName('token').asBlob := BytesOf(Token);
    end;
    Qry.SQL.Add(')');
    Qry.Params[0].Datatype := ftDateTime;
    Qry.Params[0].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
    Qry.execSql;
    Qry.Close;
  finally
    Qry.Free;
  end;
end;

function ExecutaLoginDireto(var Usuario, Senha, Login : AnsiString): Boolean;
var
  Qry : TSQLQuery;
begin
  result := false;
  Qry := TSqlQuery.create(nil);
  try
    //já passou pela autenticação OpenID, e o USUARIO pode ser um CPF ou EMAIL
    Qry.sqlConnection := GetSqlConnection(PegaDirTab);
    if pos('@', Usuario) > 0 then begin
      //EMAIL
      Usuario := copy(Usuario, 1, pos('@',Usuario) - 1);
      Qry.sql.add('SELECT USUARIO FROM USUARIO WHERE UPPER(USUARIO)=:usuario');
      Qry.paramByName('usuario').asString := UpStr(Usuario);
      Qry.open;
      if Qry.eof then
        raise Exception.Create('Usuário não cadastrado no SCCI.')
      else begin
        Usuario := Qry.fieldByName('USUARIO').asString;
      end;
      Qry.close;
      Senha := geraToken(usuario, senha);
      Login := Usuario;
      result := true;
    end;
  finally
    Qry.free;
  end;
end;

function ValidaUsuario(var usuario,Senha: AnsiString): string;
var 
  Qry : TSqlQuery;
  UltTroca : tdatetime;
begin
    result := 'F';
    QRY := TSQLQuery.Create(nil);
    try
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.SQL.Add('select NO_USUARIO, SESSION_KEY, DT_HORA_SOLICITACAO from SCCI_SESSION where NO_USUARIO = '+QuotedStr(usuario)+' and session_key = '+QuotedStr(senha));
      Qry.Open;
      ulttroca := Qry.FieldByName('DT_HORA_SOLICITACAO').AsDateTime;
      if not Qry.Eof and (Qry.FieldByName('NO_USUARIO').AsString = usuario) and 
         (Qry.FieldByName('SESSION_KEY').AsString = senha)  then
        result := 'T'+FloattoStr(ulttroca);
      Qry.Close;
    finally
      Qry.Free;
    end;
end;

function ExecutaValidaBD(var Senha : AnsiString; Usuario : AnsiString): boolean;
//Verificar se um token é valido
var
  wsenha : string;
begin
  result := false;
  try
    wsenha := ValidaUsuario(Usuario, Senha);
    if  copy(wsenha,1,1) = 'T' then
    begin
      Senha := copy(wsenha,2,length(wsenha));
      result := true;
    end
    else begin
      Senha := 'Token Informado para revalidacao e Invalido';
    end;
  finally
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

procedure TrataParamsEntrada(var paramStr, IP, Token : AnsiString;
                             var TempoExp: integer);
var
  params : TpXml;
begin
  Params := TpXml.create;
  try
    paramStr := WebDecrypt(paramStr);
    paramStr := copy(paramStr, 6, length(paramStr));
    Params.parseString(paramStr);

    IP := params['ipAddr'].asString;
    TempoExp := params['expiresIn'].asInteger;
    token := params['token'].asString;

    if length(IP) > 30 then //a coluna NU_IP_ACESSO é char(30)
      IP := copy(IP,1,30);
  finally
    Params.free;
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
  Login,
  Token : AnsiString;
  QTDMAXLOGIN,
  TempoExpiracao : integer;
begin
  NovaSenha := '';
  OpStr := '';
  Servico := '';
  OpStr := '';
  CanalLeitura := 0;
  CanalEscrita := 1;
  QTDMAXLOGIN := 0;
  TempoExpiracao := 0;
  Login := '';
  Token := '';
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
          if pos('@', Usuario) > 0 then
            TrataParamsEntrada(Senha, IP, Token, TempoExpiracao); //a senha na verdade é um xml montado no wcorp
          if ExecutaLoginDireto(Usuario,Senha,Login) then begin
            //esse login é case-INsensitive então temos q retornar o nome de usuário correto para o wcorp...
            //como só existe tratamento p a senha vou devolver junto mas separado por : e separar de novo no wcorp p devolver para o front
            writelv(CanalEscrita,'T'+Senha+':'+Usuario);
            GravaSection(Senha,Usuario,IP,Login,TempoExpiracao,Token);
          end else writelv(CanalEscrita,'F'+Senha);
// Para implementar Senha expirada enviar 'E' no lugar do F
        end
        else if OpStr = 'VALIDA' then begin
          if usuario = 'usuarioweb' then
            writelv(CanalEscrita,'T'+Senha)
          else begin
            if ExecutaValidaBD(Senha,Usuario) then
              writelv(CanalEscrita,'T'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end;
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
