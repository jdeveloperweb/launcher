program loginBD;

uses
  SysUtils, Classes, 
  punix,{$IFDEF FPC} unix,{$ELSE} libc, {$ENDIF} pdb,md5lib,
  scciio,xdb,aelib, lib1,umailer, wsistarqlib, sccilib,
  pxmllib, uloglib, datalib, originacaolib,pcrypt;
  
type
  ESenhaUsadaException = Class(Exception);
  ESenhaIncorretaException = Class(Exception);


{
procedure mydebug(st:string);
var f : text;
begin
assign (f,'/tmp/t.txt');
append(f);
writeln(f,st);
close (f);
end;


procedure WriteLog(st:string);
var f : text;
begin
    assign (f,'/var/log/launcher.log');
    try
      if not FileExists('/var/log/launcher.log') then rewrite(f)
      else  append(f);
      writeln(f,st);
    finally
      close(f);
    end;
end;
}

function GeraToken(usuario,senha : string ) : string;
begin
  result := HexStr(length(usuario)+ord('0'),2) + floattostr( int(10000*frac(now)) ) + HexStr(length(senha)+ord('0'),2)+ inttostr(getpid());
end;

function TestaUsuario(Conn : TSQLConnection; DiasExpira : integer; var usuario: AnsiString; var CodErro, wcomplemento : char): string;
var
  Qry : TSqlQuery;
  wdias : double;
  ulttroca : TDateTime;
begin
    result := '';
    wcomplemento := #0;
    wdias := 0;
    CodErro := 'F';
    QRY := TSQLQuery.Create(nil);
    try
      Qry.SqlConnection := Conn;
      Qry.SQL.Add('select senha, dt_validade_usuario,DT_ULTIMA_TROCA_SENHA,NU_MAX_DIAS_TROCA_SENHA,IN_TROCA_SENHA_PROXIMO_LOGIN,NU_MIN_DIAS_TROCA_SENHA,usuario from usuario where usuario = '+QuotedStr(usuario));
      Qry.Open;
      ulttroca := Qry.FieldByName('DT_ULTIMA_TROCA_SENHA').AsDateTime;
//raise exception.create('DiasExpira='+inttostr(DiasExpira)+' ulttroca='+formatdatetime('dd/mm/yyyy',ulttroca));
      if not Qry.Eof and (Qry.FieldByName('usuario').AsString = usuario) then
      begin
        if not Qry.FieldByName('dt_validade_usuario').isnull and (Qry.FieldByName('dt_validade_usuario').AsDateTime < now) then 
        begin
          CodErro := 'E';
//          result := 'Conta Expirada'
        end
        else if (Qry.FieldByName('NU_MAX_DIAS_TROCA_SENHA').AsInteger <> 0) and (int(now) >  (Qry.FieldByName('NU_MAX_DIAS_TROCA_SENHA').AsInteger
                 + ulttroca)) then
        begin
          CodErro := 'M';
//          result := 'Sua senha deve ser trocada pois o numero maximo de dias para troca foi atingido ';
        end
        else if (DiasExpira > 0) and (int(now) >  (DiasExpira + ulttroca)) then
        begin
          CodErro := 'M';
//          result := 'Sua senha deve ser trocada pois o numero maximo de dias para troca foi atingido ';
        end
        else if (Qry.FieldByName('NU_MIN_DIAS_TROCA_SENHA').AsInteger <> 0) and
                 (int(now) >  (Qry.FieldByName('NU_MIN_DIAS_TROCA_SENHA').AsInteger 
                 + ulttroca)) then
        begin
          wdias := int((Qry.FieldByName('NU_MAX_DIAS_TROCA_SENHA').AsInteger+ulttroca)-now);
          CodErro := 'C';
//          result := 'Sua senha deve ser trocada pois exirará em alguns dias';
        end
        else if (Uppercase(Qry.FieldByName('IN_TROCA_SENHA_PROXIMO_LOGIN').AsString) = 'T') or 
                (Uppercase(Qry.FieldByName('IN_TROCA_SENHA_PROXIMO_LOGIN').AsString) = 'V') then
        begin
          CodErro := 'M';
//          result := 'Sua senha deve ser trocada no proximo login';
        end
        else if not Qry.FieldByName('senha').IsNull and (Qry.FieldByName('senha').AsString = '') then
        begin
          CodErro := 'B';
//          result := 'Senha em branco';
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

procedure QuebraByte(var ch, ch1,ch2 : byte);
const
  ByteOffset = 65;
begin
     ch1 := (ch shr 4) + ByteOffset;
     ch2 := (ch and $F) + ByteOffset;
end;

function WebCrypt(st : string) : string;
Var
   st2  : string;
   i    : SmallInt;
   ch,
   ch1,
   ch2  : byte;
begin
     ch1 := 0;
     ch2 := 0;
     st2 := '';
     for i := 1 to length(st) do begin
         ch := (ord(st[i]) + (i*5)) xor $96;
         QuebraByte(ch,ch1,ch2);
         st2 := st2 + chr(ch1) + chr(ch2);
     end;
     WebCrypt := st2;
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

function ExecutaPasswdScatInternet(Servico,Identificacao,Usuario,Senha,
                                   NovaSenha : AnsiString ): boolean;
var
  PasswordOK: boolean;
  Conn :TSQLConnection;
  Qry : TSqlQuery;
  i : integer;
  Contexto : AnsiString;
begin
  PasswordOK := false;
  Contexto := Palavra(NovaSenha, 1, ':', #255, #255);
  NovaSenha := Palavra(NovaSenha, 2, ':', #255, #255);
  try
    if UpperCase(copy(Servico,1,2)) = 'BD://' then 
      Servico := copy(Servico,6,length(Servico));
    try
      if Servico <> '' then Conn := GetSqlConnection(Servico)
      else Conn := GetSqlConnection(PegaDirAtv);
      QRY := TSQLQuery.Create(nil);
      try
        Qry.SqlConnection := Conn;

        if Contexto = 'EVP' then begin
          Qry.Sql.add('select NO_SENHA1,NO_SENHA2,NO_SENHA3,NO_SENHA4,NO_SENHA5, CO_SENHA_USUARIO');
          Qry.Sql.add('from usuario where co_usuario = :wusuario');
          Qry.Params[0].Datatype := ftstring;
  {$IFDEF FPC}
          Qry.ParamByName('wusuario').Asstring := Envvars.Values['USER'];  // por conta do banese usuario nao vem preenchido correto
  {$ELSE}
          Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
  {$ENDIF}
          Qry.Open;

          if Qry.FieldByname('CO_SENHA_USUARIO').asstring <> md5crypt(pchar(trim(senha)),pchar('$1$'+copy(Qry.FieldByname('CO_SENHA_USUARIO').asstring,4,6)+'$'))then
            raise ESenhaIncorretaException.create('Senha incorreta');

          if TestaSenhaRepetida(Qry.FieldByname('CO_SENHA_USUARIO').asstring,NovaSenha) or
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
          Qry.Sql.Add('NO_SENHA5 = CO_SENHA_USUARIO, CO_SENHA_USUARIO = :wnovasenha where CO_USUARIO = :wusuario');
          Qry.Params[0].Datatype := ftstring;
          Qry.Params[1].Datatype := ftDateTime;
          Qry.Params[2].Datatype := ftstring;
          Qry.Params[3].Datatype := ftstring;
          Qry.ParamByName('wnovasenha').AsString := Md5Crypt(NovaSenha,'$1$'+formatdatetime('mmsshh',now)+'$');
          Qry.ParamByName('wdtulttroca').asDateTime := now;
          Qry.ParamByName('wtroca').Asstring := 'f';
          //FIM CONTEXTO EVP
        end
        else if Contexto = 'SCAT_INTERNET' then begin
          Qry.sql.add('SELECT CO_SENHA_USUARIO');
          Qry.sql.add('FROM USUARIO_SCAT_INTERNET');
          Qry.sql.add('WHERE CO_USUARIO=:wusuario');
  {$IFDEF FPC}
          Qry.ParamByName('wusuario').Asstring := Envvars.Values['USER'];  // por conta do banese usuario nao vem preenchido correto
  {$ELSE}
          Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
  {$ENDIF}
          Qry.Open;
          if Qry.FieldByname('CO_SENHA_USUARIO').asstring <> WebCrypt(senha) then
            raise ESenhaIncorretaException.create('Senha incorreta');
          Qry.close;
          Qry.sql.clear;

          Qry.sql.add('UPDATE USUARIO_SCAT_INTERNET SET');
          Qry.sql.add('CO_SENHA_USUARIO=:wnovasenha');
          Qry.sql.add(', IN_TROCA_SENHA_PROXIMO_LOGIN=:wtroca');
          Qry.sql.add('WHERE CO_USUARIO=:wusuario');
          Qry.paramByName('wnovasenha').asString := WebCrypt(NovaSenha);
          Qry.ParamByName('wtroca').AsInteger := 0;
        end;
{$IFDEF FPC}
        Qry.ParamByName('wusuario').Asstring := Envvars.Values['USER'];  // por conta do banese usuario nao vem preenchido correto
{$ELSE}
        Qry.ParamByName('wusuario').Asstring := getenv('USER');  // por conta do banese usuario nao vem preenchido correto
{$ENDIF}
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

function TestaEntrada(Input: string): boolean;
var
  i: Integer;
  c: Char;
begin
  Result := True;
  for i := 1 to Length(Input) do
  begin
    c := Input[i];
    if not (c in ['a'..'z', 'A'..'Z', '0'..'9', '.', '_', '%', '+', '-', '@']) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function ExecutaEmailPwdScatInternet(Servico,Identificacao,Usuario:ansistring;var Senha:ansistring;
                                     Email : AnsiString ): boolean;
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
  EntidadeEVP,
  wEntidade : integer;
  Contexto,
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

  Contexto := Palavra(Usuario, 1, ':',#255,#255);
  Usuario := Palavra(Usuario, 2, ':',#255,#255);
  if (not TestaEntrada(Usuario)) or (not TestaEntrada(Email)) or (Length(Usuario) > 15 ) then begin
    Senha:= 'O usuário ou o e-mail informados não são válidos.';
    GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,'',Email);
  end; 
  Qry := TSqlQuery.create(nil);
  if (Senha = '@@@!11k3kd4dEO') then
  try
    if UpperCase(copy(Servico,1,2)) = 'BD://' then 
      Servico := copy(Servico,6,length(Servico));
    if Servico <> '' then Conn := GetSqlConnection(Servico)
    else Conn := GetSqlConnection(PegaDirAtv);
    Qry.sqlConnection := Conn;
    Qry.sql.add('SELECT NU_ENTIDADE_EVP FROM CONFIGURACAO_SCAT');
    Qry.open;
    if Qry.eof then 
      raise exception.create('Falta configurar a entidade que utiliza o EVP.')
    else
      EntidadeEVP := Qry.fieldByName('NU_ENTIDADE_EVP').asInteger;
    Qry.close;
    Qry.sql.clear;
    if Contexto = 'EVP' then begin
      Qry.sql.add('SELECT NO_EMAIL_USUARIO AS NO_EMAIL');
      Qry.sql.add(',E.COD_ENT, E.NO_SMTP_EMISSAO_E_MAIL, E.NO_SENHA_E_MAIL_EMISSAO, E.NO_USUARIO_LOGIN_SMTP');
      Qry.sql.add('FROM USUARIO U');
      Qry.sql.add('LEFT JOIN ENTIDADES E ON E.COD_ENT=:entEvp');
    end
    else if Contexto = 'SCAT_INTERNET' then begin
      Qry.sql.add('SELECT C.NO_EMAIL');
      Qry.sql.add(',E.COD_ENT, E.NO_SMTP_EMISSAO_E_MAIL, E.NO_SENHA_E_MAIL_EMISSAO, E.NO_USUARIO_LOGIN_SMTP');
      Qry.sql.add('FROM USUARIO_SCAT_INTERNET U');
      Qry.sql.add('LEFT JOIN CONTATO C ON C.NU_CONTATO = U.NU_CONTATO');
      Qry.sql.add('LEFT JOIN ENTIDADES E ON E.COD_ENT=:entEvp');
    end;
    Qry.sql.add('WHERE U.CO_USUARIO=:usuario');
    Qry.paramByName('usuario').asString := usuario;
    Qry.paramByName('entEvp').asInteger := EntidadeEVP;
    Qry.open;
    if Qry.eof or (Qry.fieldByName('NO_EMAIL').asString <> Email) then begin
      Senha := 'O usuário ou o e-mail informados não são válidos.';
      GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,'',Email);
    end
    else begin
      wEmail := Email;
      wSmtp := Qry.fieldByName('NO_SMTP_EMISSAO_E_MAIL').asString;
      if (wEmail = '') or (wSMTP = '') then begin
        Senha := 'Usuário e/ou e-mail não cadastrados.  Favor entrar em contato com a equipe de suporte da Prognum';
        GeraLogEmailPwd(false{Sucesso},Senha{mensagem de erro},Usuario,'',wEmail);
      end;
      wUsuario := Qry.Fieldbyname('NO_USUARIO_LOGIN_SMTP').AsString;
      wSenhaEmail := Qry.Fieldbyname('NO_SENHA_E_MAIL_EMISSAO').AsString;
      wEntidade := Qry.Fieldbyname('COD_ENT').asinteger;
    end;
    Qry.close;
    Qry.sql.clear;

    Randomize;
    novasenha := copy(Email, 1, 5) +inttostr(trunc(random(10000)));
    if (wEmail <> '') and (wSMTP <> '') then 
    begin
      if Contexto = 'EVP' then begin
        Qry.sql.add('UPDATE USUARIO SET');
        Qry.sql.add('IN_TROCA_SENHA_PROXIMO_LOGIN='+quotedStr('T'));
        Qry.sql.add(', DT_ULTIMA_TROCA_SENHA=:dt');
        Qry.sql.add(', CO_SENHA_USUARIO=:senha');
        Qry.paramByName('dt').asSqlTimeStamp := DateTimeToSqlTimeStamp(now);
        Qry.paramByName('senha').asString := Md5Crypt(novasenha,'$1$'+formatdatetime('mmsshh',now)+'$');
      end
      else if Contexto = 'SCAT_INTERNET' then begin
        Qry.sql.add('UPDATE USUARIO_SCAT_INTERNET SET');
        Qry.sql.add('IN_TROCA_SENHA_PROXIMO_LOGIN=:troca'); //essa coluna é integer na usuario_scat_internet
        Qry.sql.add(', CO_SENHA_USUARIO=:senha');
        Qry.paramByName('troca').asInteger := 1;
        Qry.paramByName('senha').asString := WebCrypt(novasenha);
      end;
      Qry.sql.add('WHERE CO_USUARIO =:usuario');
      Qry.paramByName('usuario').asString := usuario;
      Qry.ExecSql;
      // ObtemDetalhesEmailEntidade(wEntidade,wAssunto,wCorpoEmail);
      wAssunto := 'ScatInternet - Redefinição de Senha';
      wCorpoEmail := 'Foi solicitada a recuperação da senha de acesso ao Scat Internet.'+#10+
                     'Sua nova senha provisória é "xxxxx'+copy(novaSenha, 6, length(novasenha))+ 
                     '", em que xxxxx são os 5 primeiros caracteres do seu e-mail';
      EnviaEmail(wEmail,wSMTP,wUsuario,wSenhaEmail,wAssunto,wCorpoEmail,novasenha);
      EmailOK := true;
      Senha := '';
      GeraLogEmailPwd(true{Sucesso},Senha{mensagem de erro},Usuario,'',wemail);
    end;
    result :=  EmailOk ;
  finally
    Qry.free;
  end;
end;

function ExecutaLoginBD(Servico, Identificacao, IP,Usuario : AnsiString; DiasExpira : integer;
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

procedure CtrVelhoToCtr(var Valor : String; cpf : String = '');
var
  Qry   : TSqlQuery;
begin
  Qry   := TsqlQuery.create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.sql.Add('SELECT CO_CONTRATO FROM CADMUT');
    Qry.sql.Add('WHERE CAD_CTRVELHO LIKE '+QuotedStr('%'+Valor+'%'));
    if cpf > '' then
      Qry.sql.Add('AND CAD_CPF=' + QuotedStr(cpf));
    Qry.open;
    if not Qry.Eof then
      Valor := Qry.FieldByName('CO_CONTRATO').asString;
    Qry.Close;
  finally
    Qry.free;
  end;
end;

function ValidaWebSenha(Var_1,
                        Var_2,
                        Var_3,
                        Var_4,
                        Val_1,
                        Val_2,
                        Val_3,
                        Val_4 : String) : boolean;
var
  Qry   : TSqlQuery;
  ListaWhere : TStringList;
begin
  Result := false;
  Qry   := TsqlQuery.create(nil);
  ListaWhere := TStringList.create;
  try
    Var_1 := StringReplace(Var_1,'contrato','CO_CONTRATO',[rfReplaceAll]);
    Var_1 := StringReplace(Var_1,'login','CO_CONTRATO',[rfReplaceAll]);
    Var_1 := StringReplace(Var_1,'cnr','CO_CONTRATO',[rfReplaceAll]);
    Var_1 := StringReplace(Var_1,'codigoacesso','senha',[rfReplaceAll]);

    Var_2 := StringReplace(Var_2,'contrato','CO_CONTRATO',[rfReplaceAll]);
    Var_2 := StringReplace(Var_2,'login','CO_CONTRATO',[rfReplaceAll]);
    Var_2 := StringReplace(Var_2,'cnr','CO_CONTRATO',[rfReplaceAll]);
    Var_2 := StringReplace(Var_2,'codigoacesso','senha',[rfReplaceAll]);

    Var_3 := StringReplace(Var_3,'contrato','CO_CONTRATO',[rfReplaceAll]);
    Var_3 := StringReplace(Var_3,'login','CO_CONTRATO',[rfReplaceAll]);
    Var_3 := StringReplace(Var_3,'cnr','CO_CONTRATO',[rfReplaceAll]);
    Var_3 := StringReplace(Var_3,'codigoacesso','senha',[rfReplaceAll]);

    Var_4 := StringReplace(Var_4,'contrato','CO_CONTRATO',[rfReplaceAll]);
    Var_4 := StringReplace(Var_4,'login','CO_CONTRATO',[rfReplaceAll]);
    Var_4 := StringReplace(Var_4,'cnr','CO_CONTRATO',[rfReplaceAll]);
    Var_4 := StringReplace(Var_4,'codigoacesso','senha',[rfReplaceAll]); 
    if (Var_1='CO_CONTRATO') and (Var_2='cpf') then
      CtrVelhoToCtr(Val_1, Val_2)
    else if (Var_1='CO_CONTRATO') then
      CtrVelhoToCtr(Val_1)
    else if (Var_2='CO_CONTRATO') then
      CtrVelhoToCtr(Val_2)
    else if (Var_3='CO_CONTRATO') then
      CtrVelhoToCtr(Val_3)
    else if (Var_4='CO_CONTRATO') then
      CtrVelhoToCtr(Val_4);
                              
    if Var_1 > '' then begin
      if val_1 > '' then begin
        ListaWhere.add(Var_1+'='+QuotedStr(Val_1));
      end else
        Result := true;
    end else
      Result := true;

    if Var_2 > '' then begin
      if Val_2 > '' then
        ListaWhere.add('AND '+Var_2+'='+QuotedStr(Val_2))
      else
        Result := true;
    end;

    if Var_3 > '' then begin
      if Val_3 > '' then
        ListaWhere.add('AND '+Var_3+'='+QuotedStr(Val_3))
      else
        Result := true;
    end;

    if Var_4 > '' then begin
      if Val_4 > '' then
        ListaWhere.add('AND '+Var_4+'='+QuotedStr(Val_4))
      else
        Result := true;
    end;
    if not Result then begin
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.sql.Add('SELECT *');
      Qry.sql.Add('FROM WEBSENHA');
      Qry.sql.Add('WHERE '+ListaWhere.text);

      Qry.open;
      if Qry.eof then
        Result := true
      else
        Result := false;
      Qry.close;
    end;
  finally
    Qry.free;
    ListaWhere.free;
  end;
end;

function ValidaCpf(var Cpf: Ansistring; NuPret: AnsiString = ''; Var_2: Ansistring = '') : boolean;
var
  Qry   : TSqlQuery;
  Entidade,
  EntidadeUsu : Integer;
  CpfDigitado : String;
  Dados : TpXmlNode;
begin
  Result := false;
  Entidade := 0;
  EntidadeUsu := 0;
  CpfDigitado := '';
  Qry   := TsqlQuery.create(nil);
  try
    if Cpf = '' then result := true;

    if not Result then begin
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.sql.Add('SELECT PR.NU_PRETENDENTE,PP.NO_PESSOA,');
      Qry.sql.Add('OC.DT_CADASTRAMENTO_OPERACAO,PR.CO_SITUACAO');
      Qry.sql.Add(',OC.NU_OPERACAO, OC.NU_PROPOSTA_EXTERNO');

      if Entidade > 0 then
        Qry.Sql.Add(' FROM OPERACAO_CREDITO OC')
      else begin
        if aelib.usuariotemperm(Usuario,1882) then begin
          EntidadeUsu := PegaEntidadeUsuario(PegaUsuario,Qry.SqlConnection);
          Qry.Sql.Add(GeraSelectEntSubordinada(EntidadeUsu));
          if UpStr(GetSqlConnection(PegaDirTab).DriverName) = 'MSSQL' then
            Qry.Sql.insert(0,GeraSelectEntSubordinadaSqlServer(EntidadeUsu));
        end
        else Qry.Sql.Add('FROM OPERACAO_CREDITO OC');
      end;
      Qry.Sql.Add('INNER JOIN PESSOA_PRETENDENTE PP');
      Qry.Sql.Add('ON PP.NU_PRETENDENTE=OC.NU_PRETENDENTE ');
      Qry.Sql.Add(' AND (PP.NU_PESSOA=1)');
      Qry.Sql.Add('LEFT OUTER JOIN PRETENDENTE PR');
      Qry.Sql.Add('ON   OC.NU_PRETENDENTE = PR.NU_PRETENDENTE');
      Qry.Sql.Add('WHERE OC.NU_PRETENDENTE = PP.NU_PRETENDENTE');

      if  (CPF <> '00000000000000') AND (CPF > '') then begin
        CPFDigitado := cpf;
        if  Length(cpf) < 14 then
          cpf := StringOfChar ('0', 14-Length(cpf)) + cpf;
        if (copy(cpf,1,3)='000') then
          CPFDigitado := copy(cpf,4,Length(cpf));

        Qry.Sql.Add('AND (PP.NU_CPFCNPJ = ' + QuotedStr(CPF));
        Qry.Sql.Add('    OR PP.NU_CPFCNPJ = '+QuotedStr(CPFDigitado)+')');
      end;
      Qry.Sql.Add('ORDER BY OC.NU_OPERACAO DESC');
      Qry.open;
      if Qry.eof then
        Result := true
      else begin
//        Dados := JsonOut.addOrGet('dados');
//        bdlib.DataSetToXml(Qry,'',Dados);
        if ((Var_2 = '')            and (NuPret = '')) or 
           ((Var_2 = 'pretendente') and (NuPret = Qry.fieldByName('NU_PRETENDENTE').asString)) or
           ((Var_2 = 'operacao')    and (NuPret = Qry.fieldByName('NU_OPERACAO').asString)) or
           ((Var_2 = 'proposta')    and (NuPret = Qry.fieldByName('NU_PROPOSTA_EXTERNO').asString)) then
          Result := false
        else
          Result := true;
      end;
      Qry.close;
    end;
  finally
    Qry.free;
  end;
end;

function ValidaProtocolo(Protocolo: String) : boolean;
var
  Qry   : TSqlQuery;
  Dados : TpXmlNode;
begin
  Result := false;
  Qry   := TsqlQuery.create(nil);
  try
    if Protocolo = '' then result := true;

    if not Result then begin
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.sql.Add('SELECT NU_CONTRATO,NU_PROTOCOLO_SISAT');
      Qry.sql.Add('FROM OCORRENCIA_SISAT');
      Qry.Sql.Add('WHERE NU_PROTOCOLO_SISAT=:NU_PROTOCOLO_SISAT');
      Qry.ParamByName('NU_PROTOCOLO_SISAT').asInteger := strtoint(Protocolo);
      Qry.open;
      if Qry.eof then
        Result := true
      else begin
//        Dados := JsonOut.addOrGet('dados');
//        bdlib.DataSetToXml(Qry,'',Dados);
        Result := false;
      end;
      Qry.close;
    end;
  finally
    Qry.free;
  end;
end;

function ErroValidaLoginWeb(Val_1, Val_2, Val_3, Val_4, FORMATOLOGIN : AnsiString) : boolean;
var
  Var_1,
  Var_2,
  Var_3,
  Var_4: AnsiString;
  Erro,
  CONSULTACPFOUPROTOCOLO : Boolean;
  i : integer;
  split : TStringArray;
begin
  Var_1 := '';
  Var_2 := '';
  Var_3 := '';
  Var_4 := '';
  Erro := false;
  CONSULTACPFOUPROTOCOLO := false;
  if (FORMATOLOGIN = 'cpf') or (FORMATOLOGIN = 'protocolo') or (FORMATOLOGIN='cpf_pretendente') or
     (FORMATOLOGIN='cpf_operacao') or (FORMATOLOGIN='cpf_proposta') then
    CONSULTACPFOUPROTOCOLO := true;

  try
    if FORMATOLOGIN <> '' then begin
      if (pos('_',FORMATOLOGIN)>0) then begin
        split := FORMATOLOGIN.Split('_');
        for i:=0 to length(split)-1 do begin
          case i of
            0 : Var_1 := split[i];
            1 : Var_2 := split[i];
            2 : Var_3 := split[i];
            3 : Var_4 := split[i];
          end;
        end;
      end else
        Var_1 := FORMATOLOGIN;
    end else
      Erro  := true;
    if not CONSULTACPFOUPROTOCOLO then
      Erro := ValidaWebSenha(Var_1,Var_2,Var_3,Var_4,Val_1,Val_2, Val_3, Val_4)
    else begin
      if Var_1='cpf' then
        Erro := ValidaCpf(Val_1, Val_2, Var_2)
      else if Var_1='protocolo' then
        Erro := ValidaProtocolo(Val_1)
      else
        Erro  := true;
    end;
    result := Erro;
  finally
  end;
end;

function ExecutaLoginWebReact(var Usuario,
                                  Senha,
                                  Login : AnsiString): boolean;
var
  formatoLogin,
  valLoginWeb1,
  valLoginWeb2,
  valLoginWeb3,
  valLoginWeb4: AnsiString;
begin
  result := false;
  try
    formatoLogin := palavra(usuario, 2, ':', #255, #255);
    valLoginWeb1 := palavra(usuario, 3, ':', #255, #255);
    valLoginWeb2 := palavra(usuario, 4, ':', #255, #255);
    valLoginWeb3 := palavra(usuario, 5, ':', #255, #255);
    valLoginWeb4 := palavra(usuario, 6, ':', #255, #255);
    case formatoLogin of
        'cpf_senha',
        'usuario_senha',
        'contrato_senha' : valLoginWeb2 := senha;
        'contrato_cpf_senha' : valLoginWeb3 := senha;
    end;
    if not ErroValidaLoginWeb(valLoginWeb1,valLoginWeb2,valLoginWeb3,valLoginWeb4,formatoLogin) then 
    begin
      Senha := GeraToken(usuario,Senha);
      case formatoLogin of
        'cpf_senha',
        'cpf': Login := 'F'+valLoginWeb1;
        'usuario_senha',
        'cnr_cpf',
        'contrato_cpf',
        'codigoacesso_cpf',
        'contrato_cpf_senha',
        'contrato_senha',
        'contrato_cpf_quadra_lote',
        'contrato_cpf_protocolo':  Login := 'C'+valLoginWeb1;
        'protocolo': Login := 'P'+valLoginWeb1;
        'cpf_operacao',
        'cpf_proposta',
        'cpf_pretendente': Login := 'O'+valLoginWeb1;
      end;
      Usuario := 'usuarioweb:';
      result := true;
    end
    else begin
      Senha := 'Senha Incorreta';
    end;
  finally
  end;
end;

function ExecutaLoginScatInternet(var Usuario,
                                      Senha,
                                      Login : AnsiString;
                                  var Expirada: Boolean): boolean;
var
  NomeUsuario: AnsiString;
  Qry : TSqlQuery;
begin
  result := false;
  Qry := TSqlQuery.create(nil);
  try
    NomeUsuario := palavra(usuario, 2, ':', #255, #255);
    if (not TestaEntrada(NomeUsuario)) or (Length(NomeUsuario) > 15 ) then begin
      raise Exception.Create('O usuário ou o e-mail informados não são válidos.');
    end;
    Qry.sqlConnection := GetSqlConnection(PegaDirTab);
    Qry.Sql.add('SELECT CO_SENHA_USUARIO, IN_TROCA_SENHA_PROXIMO_LOGIN, NU_EMPRESA');
    Qry.Sql.add('FROM USUARIO_SCAT_INTERNET');
    Qry.Sql.add('WHERE CO_USUARIO=:usuario');
    Qry.Sql.add('AND IN_USUARIO_DESATIVADO='+quotedstr('N'));
    Qry.paramByName('usuario').asString := NomeUsuario;
    Qry.open;
    if not Qry.eof then begin
      if (Qry.fieldByName('CO_SENHA_USUARIO').asString = WebCrypt(Senha)) then begin
        result := true;
        Expirada := (Qry.fieldByName('IN_TROCA_SENHA_PROXIMO_LOGIN').asInteger = 1);
        Login := NomeUsuario;
        Senha := GeraToken(usuario,Senha);
        Usuario := NomeUsuario;
      end
      else begin
        Senha := 'Senha Incorreta';
      end;
    end 
    else
      Senha := 'Senha Incorreta';
  finally
  end;
end;

function ExecutaLoginEVP(var Usuario,
                             Senha,
                             Login : AnsiString;
                         var Expirada: Boolean): boolean;
var
  SenhaEnc,
  NomeUsuario: AnsiString;
  Qry : TSqlQuery;
  DtValidade : TDateTime;
begin
  result := false;
  Qry := TSqlQuery.create(nil);
  try
    NomeUsuario := palavra(usuario, 2, ':', #255, #255);
    if (not TestaEntrada(NomeUsuario)) or (Length(NomeUsuario) > 15 ) then begin
      raise Exception.Create('O usuário ou o e-mail informados não são válidos.');
    end;
    Qry.sqlConnection := GetSqlConnection(PegaDirTab);
    Qry.Sql.add('SELECT CO_SENHA_USUARIO, IN_TROCA_SENHA_PROXIMO_LOGIN, DT_VALIDADE_USUARIO');
    Qry.Sql.add('FROM USUARIO');
    Qry.Sql.add('WHERE CO_USUARIO=:usuario');
    Qry.Sql.add('AND IN_USUARIO_DESATIVADO='+quotedstr('N'));
    Qry.paramByName('usuario').asString := NomeUsuario;
    Qry.open;
    if not Qry.eof then begin
      SenhaEnc := trim(Qry.fieldByName('CO_SENHA_USUARIO').asString);
      if SenhaEnc = md5crypt(PChar(Senha), pchar(SenhaEnc)) then begin
        DtValidade := Qry.FieldByName('DT_VALIDADE_USUARIO').AsDateTime;
        // expirada := int(now) > DtValidade;
        Senha := GeraToken(Usuario, Senha);
        Usuario := NomeUsuario;
        result := int(now) > DtValidade;
        expirada := lib1.strtobool(Qry.fieldByName('IN_TROCA_SENHA_PROXIMO_LOGIN').asString);
      end
      else begin
        Senha := 'Senha Incorreta';
      end;
    end 
    else
      Senha := 'Senha Incorreta';
  finally
  end;
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
          if pos('usuarioweb:', usuario) > 0 then begin
            //o usuarioweb é usado como um prefixo para fazer o login via scci react.
            //nesse caso espera-se o padrao 'usuarioweb:formato_login:valor1:valor2'
            //e a senha do usuarioweb
            if ExecutaLoginWebReact(Usuario,Senha,Login) then begin
              writelv(CanalEscrita,'T'+Senha);
              GravaSection(Senha,Usuario,IP,Login);
            end else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
          else if pos('SCAT_INTERNET:', UpStr(usuario)) > 0 then begin
            if ExecutaLoginScatInternet(Usuario,Senha,Login, Expirada) then begin
              writelv(CanalEscrita,'T'+Senha);
              GravaSection(Senha,Usuario,IP,Login);
            end else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
          else if pos('EVP:', UpStr(usuario)) > 0 then begin
            if ExecutaLoginEVP(Usuario,Senha,Login, Expirada) then begin
              writelv(CanalEscrita,'T'+Senha);
              GravaSection(Senha,Usuario,IP,Login);
            end else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
          else if usuario = 'usuarioweb' then begin
            if ExecutaLoginScci(Usuario,Senha,Expirada) then begin
              writelv(CanalEscrita,'T'+Senha);
            end else if Expirada then  writelv(CanalEscrita,'E'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end
          else begin
            try if NovaSenha <> '' then QTDMAXLOGIN := strtoint(NovaSenha); except QTDMAXLOGIN := 0; end;
            if ExecutaLoginBD(Servico,IdStr,IP,usuario,DiasExpira,Senha,CodErro) then
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
          end;
        end
        else if OpStr = 'PASSWD' then
        begin
          if (pos('EVP:', NovaSenha) = 1) or
             (pos('SCAT_INTERNET:', NovaSenha) = 1) then begin
            if ExecutaPasswdScatInternet(Servico,IdStr,Usuario,Senha,NovaSenha) then
              writelv(CanalEscrita,'T'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end 
          else begin
            if ExecutaPasswdBD(Servico,IdStr,Usuario,Senha,NovaSenha) then
              writelv(CanalEscrita,'T'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end;
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
          else if (pos('SCAT_INTERNET:', UpStr(usuario)) > 0) or
                  (pos('EVP:', UpStr(usuario)) > 0) then begin
            if ExecutaEmailPwdScatInternet(Servico,IdStr,Usuario,Senha,NovaSenha) then
              writelv(CanalEscrita,'T'+Senha)
            else writelv(CanalEscrita,'F'+Senha);
          end 
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

