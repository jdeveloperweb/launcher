unit scislib;

{$V+}
{$H-}

interface

uses
  SysUtils, pdb , lib1, xdb, aelib;

procedure AbreConexao;
procedure FechaConexao;
var
  SCISConnection : TSqlConnection;

implementation

uses
  punix, Classes;

procedure AbreConexao;
var
  DirAtv        : AnsiString;
begin
  DirAtv := '';
  if not assigned(SCISConnection) then begin
    GetCEnv ('SCCIDIRATV', DirAtv);
    SCISConnection := GetSqlConnection(DirAtv);
  end;
end;

procedure FechaConexao;
begin
  SCISConnection := nil; // Connexao Global geranciada pela XDB
end;

initialization
  SCISConnection := nil;
finalization
end.
