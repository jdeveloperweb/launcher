program loginpoupex;

uses
{$IFDEF LINUX}
{$IFDEF FPC}
  unix,
{$ELSE}
  Libc,
{$ENDIF}
{$ENDIF}
  punix, SysUtils, Classes, xdb, scciio, aelib;

(*
procedure debug(st:string);
var f : text;
begin
assign (f,'/u11/poupex/dados/ambiente_bd/teste.txt');
if fileexists('/u11/poupex/dados/ambiente_bd/teste.txt') then
  append(f)
else
  rewrite(f);
writeln(f,st);
close (f);
end;
*)

function ExecutaLoginSFixa(Servico, Identificacao, IP,Usuario : AnsiString;
                           var Senha : AnsiString ): boolean;
begin
//debug('ExecutaLoginSFixa');
  if trim(Identificacao) = '' then
    raise exception.create('Identificação não preenchida');
//debug('usuario='+usuario+' Identificacao='+Identificacao);
  result := usuario = 'loginpoupex';
  Senha := Identificacao;
end;

function ExecutaValidaBD(Servico, Identificacao, Usuario : AnsiString; var Senha : AnsiString ): boolean;
//Verificar se um token é valido
begin
//debug('ExecutaValidaBD usuario='+usuario+' senha='+senha+' identificacao='+identificacao);
  result := (usuario = 'loginpoupex') and (Senha = Identificacao);
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
  buf[1] := ' ';
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
begin
  Expirada := false;
  NovaSenha := '';
  OpStr := '';
  MsgErro := '';
  ChaveSecao := '';
  URL := '';
  CanalLeitura := 0;
  CanalEscrita := 1;
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

    // Simular tratamento do LoginAD, mas aceitar apenas o usuário
    // configurado e devolver sempre a chave de sessão configurada
    if (trim(Usuario) <> '') then
    begin
      if OpStr = 'LOGIN' then
      begin
//debug('opstr=login usuario='+usuario+' senha='+senha);
        if ExecutaLoginSFixa(Servico,IdStr,IP,usuario,Senha) then
        begin
//debug('senha='+senha);
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
        end else writelv(CanalEscrita,'F'+'erro'+Senha);
      end
      else if OpStr = 'VALIDA' then
      begin
//debug('opstr=valida');
        if ExecutaValidaBD(Servico,IdStr,Usuario,Senha) then
          writelv(CanalEscrita,'T'+Senha)
        else writelv(CanalEscrita,'F'+Senha);
      end
      else if OpStr = 'PASSWD' then
      begin
        writelv(CanalEscrita,'F'+Senha); // não implementei
      end;
    end
    else writelv(CanalEscrita,'FUsuario não informado');
       // Envia false e mensagem de erro
    except
      on e : exception do begin
//    writelv(CanalEscrita,'FErro de execução no loginad: '+E.message+char(13)+' OPSTR '+OpStr+' SERV '+Servico+' USR '+Usuario);
//debug(e.message);
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
