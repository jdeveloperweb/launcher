program loginParceiro;

uses
  SysUtils, Classes, 
  punix,{$IFDEF FPC} unix,{$ELSE} libc, {$ENDIF} pdb,md5lib,
  scciio,xdb,aelib, lib1,umailer, wsistarqlib, sccilib,
  pxmllib, uloglib, datalib, originacaolib,pcrypt;
  
type
  ESenhaUsadaException = Class(Exception);
  ESenhaIncorretaException = Class(Exception);


function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

function TestaUsuario(Conn : TSQLConnection; DiasExpira : integer; var usuario: AnsiString; var CodErro, wcomplemento : char): string;
var
  Qry : TSqlQuery;
  wdias : double;
  ulttroca : TDateTime;
  Funcao: AnsiString;
  ListaFuncoes: TStringList;
begin
    result := '';
    wcomplemento := #0;
    wdias := 0;
    CodErro := 'F';
    QRY := TSQLQuery.Create(nil);
    ListaFuncoes := TStringList.create;
    try
      Qry.SqlConnection := Conn;
      Qry.SQL.Add('select senha, dt_validade_usuario,E.FUNCAO,DT_ULTIMA_TROCA_SENHA,NU_MAX_DIAS_TROCA_SENHA,');
      Qry.SQL.Add('IN_TROCA_SENHA_PROXIMO_LOGIN,NU_MIN_DIAS_TROCA_SENHA,usuario');
      Qry.SQL.Add('from usuario U');
      Qry.SQL.Add('LEFT JOIN ENTIDADES E ON E.COD_ENT = U.ENT_PRIMARIA');
      Qry.SQL.Add('where usuario = '+QuotedStr(usuario));
      Qry.Open;
      ulttroca := Qry.FieldByName('DT_ULTIMA_TROCA_SENHA').AsDateTime;
      if not Qry.Eof and (Qry.FieldByName('usuario').AsString = usuario) then
      begin
        ListaFuncoes.delimiter := ',';
        ListaFuncoes.delimitedText := GetEnv('ENTIDADE_FUNCAO');
        Funcao := Qry.fieldByName('FUNCAO').asString;
        if ListaFuncoes.IndexOf(Funcao) < 0 then
          CodErro := 'A'
        else if not Qry.FieldByName('dt_validade_usuario').isnull and (Qry.FieldByName('dt_validade_usuario').AsDateTime < now) then 
        begin
          CodErro := 'E';
        end
        else if (Qry.FieldByName('NU_MAX_DIAS_TROCA_SENHA').AsInteger <> 0) and (int(now) >  (Qry.FieldByName('NU_MAX_DIAS_TROCA_SENHA').AsInteger
                 + ulttroca)) then
        begin
          CodErro := 'M';
        end
        else if (DiasExpira > 0) and (int(now) >  (DiasExpira + ulttroca)) then
        begin
          CodErro := 'M';
        end
        else if (Qry.FieldByName('NU_MIN_DIAS_TROCA_SENHA').AsInteger <> 0) and
                 (int(now) >  (Qry.FieldByName('NU_MIN_DIAS_TROCA_SENHA').AsInteger 
                 + ulttroca)) then
        begin
          wdias := int((Qry.FieldByName('NU_MAX_DIAS_TROCA_SENHA').AsInteger+ulttroca)-now);
          CodErro := 'C';
        end
        else if (Uppercase(Qry.FieldByName('IN_TROCA_SENHA_PROXIMO_LOGIN').AsString) = 'T') or 
                (Uppercase(Qry.FieldByName('IN_TROCA_SENHA_PROXIMO_LOGIN').AsString) = 'V') then
        begin
          CodErro := 'M';
        end
        else if not Qry.FieldByName('senha').IsNull and (Qry.FieldByName('senha').AsString = '') then
        begin
          CodErro := 'B';
        end
        else
        begin
          CodErro := 'T';
        end;
        result := Qry.FieldByName('senha').AsString;
        if CodErro = 'C' then 
          wcomplemento := char( byte(trunc(wdias))+30); 
      end;
      Qry.Close;
    finally
      Qry.Free;
    end;
end;

function TestaSenhaRepetida(SenhaBD,Senha : ansistring) : boolean;
var
  SenhaEnc : Ansistring;
begin
    result := false;
    SenhaEnc := md5crypt(pchar(trim(senha)),pchar('$1$'+copy(SenhaBd,4,6)+'$'));
    if SenhaBd = SenhaEnc then  result := true;
end;

function ExecutaPasswdBD(Servico,Identificacao,Usuario,Senha,
                             NovaSenha : AnsiString ): boolean;
var
  PasswordOK: boolean;
  Conn :TSQLConnection;
  Qry : TSqlQuery;
  i : integer;
begin
  PasswordOK := false;
  try
    if UpperCase(copy(Servico,1,2)) = 'BD://' then 
      Servico := copy(Servico,6,length(Servico));
    try
      if Servico <> '' then Conn := GetSqlConnection(Servico)
      else Conn := GetSqlConnection(PegaDirAtv);
      QRY := TSQLQuery.Create(nil);
      try
        Qry.SqlConnection := Conn;
        
        Qry.Sql.add('select NO_SENHA1,NO_SENHA2,NO_SENHA3,NO_SENHA4,NO_SENHA5,senha');
        Qry.Sql.add('from usuario where usuario = :wusuario');
        Qry.Params[0].Datatype := ftstring;
{$IFDEF FPC}
        Qry.ParamByName('wusuario').Asstring := Envvars.Values['USER'];  // por conta do banese usuario nao vem preenchido correto
{$ELSE}
        Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
{$ENDIF}
        Qry.Open;

        if Qry.FieldByname('senha').asstring <> md5crypt(pchar(trim(senha)),pchar('$1$'+copy(Qry.FieldByname('senha').asstring,4,6)+'$'))then
          raise ESenhaIncorretaException.create('Senha incorreta');

        if TestaSenhaRepetida(Qry.FieldByname('senha').asstring,NovaSenha) or
           TestaSenhaRepetida(Qry.FieldByname('NO_SENHA1').asstring,NovaSenha) or
           TestaSenhaRepetida(Qry.FieldByname('NO_SENHA2').asstring,NovaSenha) or
           TestaSenhaRepetida(Qry.FieldByname('NO_SENHA3').asstring,NovaSenha) or
           TestaSenhaRepetida(Qry.FieldByname('NO_SENHA4').asstring,NovaSenha) or
           TestaSenhaRepetida(Qry.FieldByname('NO_SENHA5').asstring,NovaSenha) then
          raise ESenhaUsadaException.create('Esta senha já foi usada anteriormente');

        Qry.close;
        Qry.sql.clear;

        Qry.SQL.Add('update usuario set  IN_TROCA_SENHA_PROXIMO_LOGIN = :wtroca, DT_ULTIMA_TROCA_SENHA = :wdtulttroca ,');
        Qry.SQL.Add(' NO_SENHA1 = NO_SENHA2, NO_SENHA2 = NO_SENHA3 , NO_SENHA3 = NO_SENHA4, NO_SENHA4 = NO_SENHA5 , ');
        Qry.Sql.Add('NO_SENHA5 = senha, senha = :wnovasenha where usuario = :wusuario');
        Qry.Params[0].Datatype := ftstring;
        Qry.Params[1].Datatype := ftDateTime;
        Qry.Params[2].Datatype := ftstring;
        Qry.Params[3].Datatype := ftstring;
        Qry.ParamByName('wnovasenha').AsString := Md5Crypt(NovaSenha,'$1$'+formatdatetime('mmsshh',now)+'$');
        Qry.ParamByName('wdtulttroca').asDateTime := now;
{$IFDEF FPC}
        Qry.ParamByName('wusuario').Asstring := Envvars.Values['USER'];  // por conta do banese usuario nao vem preenchido correto
{$ELSE}
        Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
{$ENDIF}
        Qry.ParamByName('wtroca').Asstring := 'f';
        Qry.ExecSql;
        PasswordOK := true;
        Senha := GeraToken(usuario,Senha);
      except 
        on e : ESenhaIncorretaException do
          raise;
        on e : ESenhaUsadaException do
          raise;
        on e : exception do
            begin
              raise exception.Create('Erro ao trocar a Senha : '+e.message);
            end
      end;
    except
      on e : ESenhaIncorretaException do
        raise;
      on e : ESenhaUsadaException do
        raise;
      on e : exception do
        raise exception.Create('Erro ao trocar a Senha :'+e.message);
    end;
  finally 
  end;
  result :=  PasswordOk ;
end;

function EnviaEmail(Email,SMTP,usuarioEmail,senhaEmail,Assunto,CorpoEmail,novasenha:string):boolean;
var
  mail : TMailer;
  CorpoEmailStList : Tstringlist;
  SenhaTemporaria : string;
begin
  mail := Tmailer.create(email,''); 
  result := false;
  try
    with mail do
    begin
      try
        if trim(Assunto) > '' then
          Subject := Assunto
        else
          Subject := 'Redefinição de senha SCCI';
        Remetente := 'no-reply@prognum.com.br';
        SMTP_Host := SMTP;
        Senha := DescriptografaSenhaEmail(SenhaEmail);
        Usuario := UsuarioEmail;
        CorpoEmailStList := TStringlist.Create;
        SenhaTemporaria := copy(novasenha,6,length(novasenha));
        if trim(CorpoEmail) = '' then
          CorpoEmail := 'Conforme solicitado, redefinimos sua senha de acesso ao SCCI. Sua nova senha é formada pelos 5 primeiros digitos do seu CPF + @SENHA_TEMPORARIA@.  A mesma deverá ser trocada no próximo acesso!';
        CorpoEmailStList.text := stringreplace(CorpoEmail,'@SENHA_TEMPORARIA@',SenhaTemporaria,[rfreplaceall,rfignorecase]);
        SendMail(CorpoEmailStList);
      except
        raise exception.Create('Erro ao enviar email');
        result := false;
      end;
    end;
  finally
    CorpoEmailStList.Free;
    mail.Free;
    result := true;
  end;
end;

function ObtemDocumentoNaPasta(NomeModelo,NomeTemp,Pasta : String): boolean;
var idmodelo,idpai : integer;
begin
  result := false;
  idpai := EncontraPastaPeloNome(GetSqlConnection(PegaDirTab),Pasta);
  if idpai > 0 then begin
    idmodelo := IDDoDocumento(GetSqlConnection(PegaDirTab), NomeModelo, IDPai);
    if idModelo > 0 then begin
      SaveDocumentoToFile(GetSqlConnection(PegaDirTab),idModelo,NomeTemp);
      result := true;
    end;
  end;
end;

procedure ObtemDetalhesEmailEntidade(    wEntidade : integer;
                                     var wAssunto,
                                         wCorpoEmail : ansistring);
var
  Qry : TSqlQuery;
  NomeTemp : ansistring;
  StList : TStringlist;
begin
  wAssunto := '';
  wCorpoEmail := '';
  
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);

    if wEntidade >= 0 then begin
      Qry.Sql.clear;
      Qry.Sql.add('SELECT CO_VARIAVEL,NO_VALOR FROM VARIAVEL_ENTIDADE');
      Qry.Sql.add('WHERE COD_ENT='+ InttoStr(wEntidade));
      Qry.Sql.add(' AND (CO_VARIAVEL='+QuotedStr('SENHA_ASSUNTO')+' OR');
      Qry.Sql.add('     (CO_VARIAVEL='+QuotedStr('SENHA_MENSAGEM')+'))');
      Qry.open;
      while not Qry.eof do begin
        if Qry.FieldByName('CO_VARIAVEL').asString = 'SENHA_ASSUNTO' then
          wAssunto := Qry.FieldByName('NO_VALOR').asString
        else if Qry.FieldByName('CO_VARIAVEL').asString = 'SENHA_MENSAGEM' then
          wCorpoEmail := Qry.FieldByName('NO_VALOR').asString;
        Qry.next;
      end;
      Qry.close;
    end;
  finally
    Qry.free;
  end;
  
  if wCorpoemail > '' then begin
    // em SENHA_MENSAGEM vai ficar o nome do arquivo, e não o conteúdo de fato
    // procurar primeiro no módulo de documentos, em ARQS_HTML e depois no SCCIDIRARQS
    NomeTemp := MakeTempFileName;
    if ObtemDocumentoNaPasta(wCorpoEmail{NomeModelo},NomeTemp, 'ARQS_HTML') then begin
      StList := TStringlist.create;
      try
        StList.loadfromfile(NomeTemp);
        wCorpoEmail := StList.text;
      finally
        StList.free;
        deletefile(NomeTemp);
      end;
    end
    else if FileExists(PegaDirArqs+Pathdelim+wCorpoEmail) then begin
      StList := TStringlist.create;
      try
        StList.loadfromfile(PegaDirArqs+Pathdelim+wCorpoEmail);
        wCorpoEmail := StList.text;
      finally
        StList.free;
      end;
    end
    else
      wCorpoEmail := ''; // não achou o arquivo
  end;
end;

procedure GeraLogEmailPwd(Sucesso : boolean; MsgErro,Usuario,cpf,Email : ansistring);
var
  Xml : TpXml;
  Node : TpXmlNode;
  severidade : TLogSeveridade;
begin
  Xml := TpXml.create;
  try
    Xml.documentElement.nodename := 'Redefinicao de senha';
    (*  Sol. 74694
        No log deve-se registrar alem de data e hora do evento o usuario
        (userName) para o qual solicitou-se a alteração, o email ( userMail ) e
        um campo  "Resultado da Operação" comnforme os criteriosa seguir
        (em italico o comentario
    *)
    
    Node := Xml.documentElement;
    Node.add('Usuário').asstring := Usuario;
    Node.add('Data').asstring := Data_str2(DataH);
    Get_Hora(HoraH);
    Node.add('Hora').asstring := Hora_Str(HoraH);
    Node.add('Email').asstring := Email;

    if sucesso then begin
      severidade := logseveridade_Aviso;
      Node.add('Resultado').asstring := 'Sucesso';
    end
    else begin
      severidade := logseveridade_Erro;
      Node.add('Resultado').asstring := 'Erro - '+MsgErro;
    end;

    GeraLog(logAplic_RedefinirSenha{CO_APLIC},severidade{CO_SEVERIDADE},
            usuario{NO_USUARIO},MsgErro{NO_MENSAGEM},0{CO_DETALHE},XML);
  finally
    Xml.free;
  end;
end;

function ExecutaEmailPwd(Servico,Identificacao,Usuario:ansistring;var Senha:ansistring;
                             CPF : AnsiString ): boolean;
var
  wEmail,
  wSMTP,
  wUsuario,
  wSenhaEmail,
  novasenha : string;
  Conn :TSQLConnection;
  Qry : TSqlQuery;
  i : integer;
  EmailOK : boolean;
  wEntidade : integer;
  wAssunto,
  wCorpoEmail : ansistring;
begin
  result := false;
  EmailOK := false;
  wEmail := '';
  novasenha := '';
  wSMTP := '';
  wSenhaEmail := '';
  wEntidade := -1;
  wAssunto := '';
  wCorpoEmail := '';
(* sol.74694
   Após deverá verificar se o usuário inofmrado em userName e o CPF informado
   em userCPF está gravado na tabela de Usuários e se tem e-mail associado à ele.
   Se não tiver usuário ou e-mail cadastrado ou se usuário for igual supervisor,
   ou se o CPF cadastrado para o usuario for igual a '111.111.111-11', devolver a
   mensagem de erro: "Usuário inválido ou sem e-mail cadastrado. Procure o
   administrador do sistema!"  Não dê sequência ao processo.
*)
  if (Usuario = 'supervisor') or (cpf = stringofchar('1',11)) then begin
    Senha := 'Usuário inválido ou sem e-mail cadastrado. Procure o administrador do sistema!';
    GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,cpf,''{email});
  end
  else if (Senha = '@@@!11k3kd4dEO') and (length(CPF) = 11) then
  try
    if UpperCase(copy(Servico,1,2)) = 'BD://' then 
      Servico := copy(Servico,6,length(Servico));
    if Servico <> '' then Conn := GetSqlConnection(Servico)
    else Conn := GetSqlConnection(PegaDirAtv);
    QRY := TSQLQuery.Create(nil);
    Qry.SqlConnection := Conn;
    Qry.Sql.add('select CPF,entidades.NO_SMTP_EMISSAO_E_MAIL SMTP,usuario.NO_E_MAIL_EMISSAO Email,');
    Qry.Sql.add('entidades.NO_SENHA_E_MAIL_EMISSAO SenhaSMTP,entidades.NO_USUARIO_LOGIN_SMTP UsuarioSMTP,');
    Qry.sql.add('usuario.ENT_PRIMARIA');
    Qry.Sql.add(' from usuario left join entidades on (entidades.cod_ent = usuario.ENT_PRIMARIA)');
    Qry.sql.add(' where usuario = :wusuario');
    Qry.Params[0].Datatype := ftstring;
{$IFDEF FPC}
    Qry.ParamByName('wusuario').Asstring := Usuario;
{$ELSE}
    Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
{$ENDIF}
    Qry.Open;
    if not Qry.IsEmpty and (Cpfnum(cpf)=cpfnum(Qry.FieldByName('CPF').Asstring))then
    begin
       wEmail := Qry.Fieldbyname('Email').AsString;
       wsmtp := Qry.Fieldbyname('SMTP').AsString;
       if (wEmail = '') or (wSMTP = '') then begin
          Senha := 'Email ou SMTP nao cadastrados';
          GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,cpf,wEmail);
       end;
       wUsuario := Qry.Fieldbyname('UsuarioSMTP').AsString;
       wSenhaEmail := Qry.Fieldbyname('SenhaSMTP').AsString;
       wEntidade := Qry.Fieldbyname('ENT_PRIMARIA').asinteger;
    end
    else begin
      Senha := 'CPF ou usuário incorreto';
      GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,cpf,wEmail);
    end;
    Qry.close;
    Qry.sql.clear;
    randomize;
    novasenha := copy(CPF,1,5)+inttostr(trunc(random(10000)));
    if (wEmail <> '') and (wSMTP <> '') then 
    begin
        Qry.SQL.Add('update usuario set  IN_TROCA_SENHA_PROXIMO_LOGIN = :wtroca, DT_ULTIMA_TROCA_SENHA = :wdtulttroca ,');
        Qry.Sql.Add(' senha = :wnovasenha where usuario = :wusuario');
        Qry.Params[0].Datatype := ftstring;
        Qry.Params[1].Datatype := ftDateTime;
        Qry.Params[2].Datatype := ftstring;
        Qry.Params[3].Datatype := ftstring;
        Qry.ParamByName('wnovasenha').AsString := Md5Crypt(novasenha,'$1$'+formatdatetime('mmsshh',now)+'$');
        Qry.ParamByName('wdtulttroca').asDateTime := now;
{$IFDEF FPC}
        Qry.ParamByName('wusuario').Asstring := usuario;
{$ELSE}
        Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
{$ENDIF}
        Qry.ParamByName('wtroca').Asstring := 'T';
        Qry.ExecSql;
        ObtemDetalhesEmailEntidade(wEntidade,wAssunto,wCorpoEmail);
        EnviaEmail(wEmail,wSMTP,wUsuario,wSenhaEmail,wAssunto,wCorpoEmail,novasenha);
        EmailOK := true;
        Senha := '';
        GeraLogEmailPwd(true{Sucesso},Senha{mensagem de erro},Usuario,cpf,wemail);
    end;
  finally 
    Qry.Free;
  end
  else begin 
    Senha := 'CPF ou usuário incorreto';
    GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,cpf,''{email});
  end;
  result :=  EmailOk ;
end;

function ExecutaLoginParceiro(Servico, Identificacao, IP,Usuario : AnsiString; DiasExpira : integer;
                        var Senha : AnsiString ; var CodErro : char): boolean;
var
  Conn :TSQLConnection;
  wsenha : string;
  wcomplemento : char;
begin
  wcomplemento := #0;
  result := false;
  try
    if UpperCase(copy(Servico,1,2)) = 'BD://' then 
      Servico := copy(Servico,6,length(Servico));
    if Servico <> '' then Conn := GetSqlConnection(Servico)
    else Conn := GetSqlConnection(PegaDirAtv);
    wsenha := TestaUsuario(Conn,DiasExpira,Usuario,CodErro,wcomplemento);
    if wsenha = md5crypt(senha,wsenha) then 
    begin
      Senha := GeraToken(usuario,Senha);
      if CodErro = 'C' then Senha := wcomplemento + Senha;
      result := true;
    end
    else begin
      Senha := 'Senha Incorreta';
      CodErro := 'F';
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

var
  CodErro : char;
  CanalLeitura,
  CanalEscrita : Integer; 
  OpStr,
  Novasenha,
  URL,
  ChaveSecao,
  MsgErro,
  Servico,
  IdStr,
  Usuario,
  Senha,
  IP : AnsiString;
  Expirada : boolean;
  QTDMAXLOGIN : integer;
  DiasExpira : integer;
  Login : Ansistring;
begin
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
  CodErro := 'F';
  QTDMAXLOGIN := 0;
  Login := '';
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
      DiasExpira := valint(GetEnv('USERDIASEXPIRA'));
      if (trim(Usuario) <> '') then
      begin
        if OpStr = 'LOGIN' then
        begin
          try if NovaSenha <> '' then QTDMAXLOGIN := strtoint(NovaSenha); except QTDMAXLOGIN := 0; end;
          if ExecutaLoginParceiro(Servico,IdStr,IP,usuario,DiasExpira,Senha,CodErro) then
          begin
            // Se resposta true então
            // Grava ou inclui usuário na tabela de usuáio as seguintes informações:
            //   Senha ( Chave de seção )
            //   Perfil primário e perfil segundário com 0.
            // Lê as permissões do usuário do web service
            //   Apagas as permissões que existirem e grava as novas permissões
            //   na tabela usuario_função
            // Envia a resposta e chave de seção  para o canal de escrita  
                writelv(CanalEscrita,CodErro+Senha);
            // Se a resposta for false
            // Para implementar Senha expirada enviar 'E' no lugar do F
            if QTDMAXLOGIN > 1 then ValidaQtdLogin(QTDMAXLOGIN,usuario);
            GravaSection(Senha,Usuario,IP);
          end 
          else writelv(CanalEscrita,CodErro+Senha);
        end
        else if OpStr = 'PASSWD' then
        begin
          if ExecutaPasswdBD(Servico,IdStr,Usuario,Senha,NovaSenha) then
            writelv(CanalEscrita,'T'+Senha)
          else writelv(CanalEscrita,'F'+Senha);
        end
        else if OpStr = 'VALIDA' then
        begin
          if usuario = 'usuarioweb' then
            writelv(CanalEscrita,'T'+Senha)
          else begin
            if ExecutaValidaBD(Servico,IdStr,Usuario,Senha, Expirada) then
              writelv(CanalEscrita,'T'+Senha)
            else if Expirada then writelv(CanalEscrita, 'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
        end
        else if OpStr = 'EMAILPWD' then
        begin
          if usuario = 'usuarioweb' then
            writelv(CanalEscrita,'E'+Senha)
          else begin
           if ExecutaEmailPwd(Servico,IdStr,Usuario,Senha,NovaSenha) then
              writelv(CanalEscrita,'T'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end;
        end
      end
      else writelv(CanalEscrita,'FUsuario não informado');
    // Envia false e mensagem de erro
    except
      on e : exception do
//    writelv(CanalEscrita,'FErro de execução no loginbd: '+E.message+char(13)+' OPSTR '+OpStr+' SERV '+Servico+' USR '+Usuario);
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

