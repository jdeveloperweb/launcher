program huplauncher;

uses
{$IFDEF FPC}
  baseunix,
{$ENDIF}
{$IFDEF KYLIX}
  Libc,
{$ENDIF}
 SysUtils;

{$IFDEF LINUX}
 var
	i : integer;
	wpid : string;
	f : text;

procedure mykill(stpid : string);
var pid : integer;
begin
	try
		pid := strtoint(stpid);
{$IFDEF FPC}
		if fpkill(pid,SIGHUP) = 0 then
{$ELSE}
		if kill(pid,SIGHUP) = 0 then
{$ENDIF}
			writeln(pid,': sinalizado COM sucesso')
		else
			writeln(pid,': sinalizado SEM  sucesso');
	except
		writeln(stpid,': PID inválido');
	end;
end;
{$ELSE}

var
  pCCPClient : TpCCPClient;
  porta, usuario, senha , amb : string;
{$ENDIF}

begin
{$IFDEF LINUX}

	if paramcount = 0 then
	begin
		assign(f,'/var/run/launcher.pid');
		try
	          system.reset(f);
                  while not eof(f) do
                  begin
		    system.readln(f,wpid);
		    mykill(wpid);
                  end;
		finally
	          close(f);
		end;
	end
	else for i := 1 to paramcount do mykill(paramstr(i));
{$ELSE}
	if paramcount = 0 then
	begin
	  write('Porta : '); readln(porta);
	  write('Ambiente : '); readln(amb);
	  write('Usuario : '); readln(usuario);
	  write('Senha : '); readln(senha);
	end
	else if paramcount = 4 then
	begin
	  Porta := paramstr(1);
	  Amb := paramstr(2);
	  Usuario := paramstr(3);
	  Senha := Paramstr(4);
	end
	else begin
	  writeln('Parametros incorretos');
	  writeln('huplauncher  porta host usuario senha ');
	  halt(1);
	end;
    pCCPClient := TpCCpClient.create(nil);
    with pCCpClient.Params do 
	begin
      Values['Password'] := senha;
      Values['User'] := usuario;
      Values['Server'] := '127.0.0.1';
      Values['Socket'] := porta;
	  Values['ServerPath'] := amb;
	  try
        pCCPClient.Hup;
	  except 
	    raise exception.create('Erro de conexão com o launcher. Verifique os parametros.');
	  end;
    end;
{$ENDIF}
end.
