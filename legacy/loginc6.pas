program loginc6;

uses SysUtils, lib1, pdb, scciio, xdb, parmlib, uloglib, punix, fpjwt, fpjwasha256,
     Classes, synautil, DateUtils, unix, aelib, pcrypt, pxmllib, bdlib,datalib;


function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
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

function ExecutaLoginC6(var Usuario, Senha, Login, NomePerfil : AnsiString): Boolean;
var
  Qry : TSQLQuery;
  CodEnt,
  CodPerfil : Integer;
  EmailAD,
  Entidade,
  NomePerfilVelho : AnsiString;
  XmlLog : TpXml;
begin
  result := false;
  Qry := TSqlQuery.create(nil);
  XmlLog := TpXml.create;
  try
    Qry.sqlConnection := GetSqlConnection(PegaDirTab);
    Qry.sql.add('SELECT COD_PERFIL FROM PERFIL WHERE UPPER(NOME_PERFIL)=:perfil');
    Qry.paramByName('perfil').asString := UpStr(NomePerfil);
    Qry.open;
    if Qry.eof then
      raise exception.create('Usuário não possui acesso ao SCCI.')
    else
      CodPerfil := Qry.fieldByName('COD_PERFIL').asInteger;

    Qry.close;
    Qry.sql.clear;
    Qry.sql.add('SELECT U.USUARIO, U.PERF_PRIMARIO, P.NOME_PERFIL, U.NO_AUTENTICACAO_AD');
    Qry.sql.add('FROM USUARIO U');
    Qry.sql.add('LEFT JOIN PERFIL P ON P.COD_PERFIL = U.PERF_PRIMARIO');
    Qry.sql.add('WHERE UPPER(U.USUARIO)=:usuario');
    EmailAD := Usuario;
    if pos('@', Usuario) > 0 then
       Usuario := copy(Usuario, 1, pos('@',Usuario) - 1);
    Qry.paramByName('usuario').asString := UpStr(Usuario);
    Qry.open;
    if not Qry.eof then begin
      Usuario := Qry.fieldByName('USUARIO').asString;
      NomePerfilVelho := Qry.fieldByName('NOME_PERFIL').asString;
      if CodPerfil <> Qry.fieldByName('PERF_PRIMARIO').asInteger then begin
        //usuario ja existe mas com outro perfil: atualiza o perfil
        Qry.close;
        Qry.sql.clear;
        Qry.sql.add('UPDATE USUARIO SET PERF_PRIMARIO=:perf WHERE USUARIO=:usuario');
        Qry.paramByName('usuario').asString := usuario;
        Qry.paramByName('perf').asInteger := CodPerfil;
        Qry.ExecSql;

        XmlLog.documentElement.nodename := 'Atualização de Perfil';
        XmlLog.documentElement.addchild('Usuario').nodeValue := usuario;
        XmlLog.documentElement.addchild('Perfil Anterior').nodeValue := NomePerfilVelho;
        XmlLog.documentElement.addchild('Novo Perfil').nodeValue := NomePerfil;
        uloglib.GeraLog(logaplic_ALT_TABELA, logseveridade_Aviso, 
                    '', usuario, 'Atualização de Perfil do Usuário', 
                    '', XmlLog, Qry.SqlConnection);
      end;
      if EmailAD <> Qry.fieldByName('NO_AUTENTICACAO_AD').asString then begin
        //usuario ja existe mas com outro email_ad: atualiza o email_ad
        Qry.close;
        Qry.sql.clear;
        Qry.sql.add('UPDATE USUARIO SET NO_AUTENTICACAO_AD=:NO_AUTENTICACAO_AD WHERE USUARIO=:USUARIO');
        Qry.paramByName('USUARIO').asString := usuario;
        Qry.paramByName('NO_AUTENTICACAO_AD').asString := EmailAD;
        Qry.ExecSql;

        XmlLog.free;
        XmlLog := TpXml.create;
        XmlLog.documentElement.nodename := 'Atualização de Perfil';
        XmlLog.documentElement.addchild('Usuario').nodeValue := usuario;
        XmlLog.documentElement.addchild('Email AD Anterior').nodeValue := NomePerfilVelho;
        XmlLog.documentElement.addchild('Novo Email AD').nodeValue := NomePerfil;
        uloglib.GeraLog(logaplic_ALT_TABELA, logseveridade_Aviso, 
                    '', usuario, 'Atualização de Email AD do Usuário', 
                    '', XmlLog, Qry.SqlConnection);
      end;

    end else begin
      //usuario nao existe: insere na tabela
      get_hora(horaH);
      Qry.close;
      //primeiro obter a entidade no launcherenv
      Entidade := GetEnv('ENTIDADEUSUARIODEFAULT');
      if trim(Entidade) = '' then raise Exception.Create('ENTIDADEUSUARIODEFAULT ausente no launcherenv.in');
      if isNumeric(Entidade) then
        CodEnt := StrToInt(Entidade)
      else begin
        Qry.sql.clear;
        Qry.sql.add('SELECT COD_ENT FROM ENTIDADES WHERE NOME=:nome');
        Qry.paramByName('nome').asInteger := strtoint(Entidade);
        Qry.open;
        if not Qry.eof then
          CodEnt := Qry.fieldByName('COD_ENT').asInteger
        else
          raise Exception.Create('Não foi possível obter o código da entidade.');
        Qry.close;
      end;
      Qry.sql.clear;
      Qry.sql.add('INSERT INTO USUARIO (');
      Qry.sql.add('USUARIO, PERF_PRIMARIO, ENT_PRIMARIA, ALT_USUARIO, UIDUSUARIO, ALT_DATA, CO_SETOR, NOME, NO_AUTENTICACAO_AD');
      Qry.sql.add(') VALUES (');
      Qry.sql.add(':usuario, :perfil, :entidade, :alt_user, :uid, :alt_data, :co_setor, :nome, :no_autenticacao_ad)');
      Qry.paramByName('usuario').asString := Usuario;
      Qry.paramByName('perfil').asInteger := CodPerfil;
      Qry.paramByName('entidade').asinteger := CodEnt;
      Qry.paramByName('alt_user').asString := PegaUsuario;
      Qry.paramByName('uid').asInteger := LeGenerator(Qry.sqlConnection, 'GEN_UID_USUARIO');
      Qry.parambyname('ALT_DATA').asdatetime := datatodatetime(DataH)+horaTodatetime(horaH);
      Qry.parambyname('CO_SETOR').asstring := ObtemSetor(Qry.SqlConnection,CodPerfil,CodEnt);
      Qry.parambyname('NOME').asstring := Usuario;
      Qry.parambyname('no_autenticacao_ad').asstring := EmailAD;
      Qry.ExecSql;

      XmlLog.documentElement.nodename := 'Cadastramento de Usuário';
      XmlLog.documentElement.addchild('Usuario').nodeValue := usuario;
      XmlLog.documentElement.addchild('Perfil').nodeValue := NomePerfil;
      XmlLog.documentElement.addchild('Entidade').nodeValue := Entidade;
      uloglib.GeraLog(logaplic_ALT_TABELA, logseveridade_Aviso, 
                  '', usuario, 'Cadastramento de Usuário', 
                  '', XmlLog, Qry.SqlConnection);
    end;
    Qry.close;

    Senha := geraToken(usuario, senha);
    Login := Usuario;
    result := true;
  finally
    Qry.free;
    XmlLog.free;
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

procedure TrataParamsEntrada(var paramStr, IP, Perfil, Token : AnsiString;
                             var TempoExp: integer);
var
  params : TpXml;
begin
  Params := TpXml.create;
  try
    paramStr := WebDecrypt(paramStr);
    paramStr := copy(paramStr, 6, length(paramStr));
    Params.parseString(paramStr);
    perfil := params['perfil'].asString;
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
  Token,
  Perfil: AnsiString;
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
  Perfil := '';
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
          TrataParamsEntrada(Senha, IP, Perfil, Token, TempoExpiracao); //a senha na verdade é um xml montado no wcorp
          if ExecutaLoginC6(Usuario,Senha,Login,Perfil) then begin
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
