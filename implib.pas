{------------------------------------------------------------------------}
                             unit implib;

{         Rotinas de configuracao de impressoras para aplicacoes         }
{------------------------------------------------------------------------}

{$V-}

{------------------------------------------------------------------------}
                               interface
{------------------------------------------------------------------------}

{$V+}
{$H-}

{$IFDEF FPC}
{$P+}
{$ENDIF}

uses punix,lib1,xdb,SysUtils,pdb,dbreglib;

type TpImpressora = record
                      Codigo            : SmallInt;
                      Nome, NomeSis     : string[31];
                      FFeed, Comp,
                      Norm, Expa        : string[255];
                      NColComp,NColNorm,
                      NColExpa          : SmallInt;
                      NormLPI,
                      Char6LPI,
                      Char8LPI          : string[11];
                      NLinhas           : SmallInt;
                      CPS               : Smallint;
                      CharSet           : byte;
                      B1                : byte;
                      Fill              : string[9];
                    end;

     TpTexto = record
                 Codigo: string[15];
                 Nome  : string[31];
                 CodImp: SmallInt;
                 tamanhodafonte : smallint;
                 autoajuste : boolean;
                 Retrato : boolean;
                 MargemSuperior : smallint;
                 MargemEsquerda : smallint;
                 TipoPapel : string[19];
                 QtdeLinhas : smallint;
                 Fill  : string[21];
               end;

     TpParmImp = record
                   NCopias      : SmallInt;
                   CodImp       : Smallint;
                   LocalImp     : string[15];
                 end;

  TBrowseTabImp = class(TBrowseTabela)
  protected
    function GetTipoDBRegistro : TDBRegistroClass; override;
    function AbriuConnectionSql : boolean; override;
    function GetSqlConnection : TSqlConnection; override;
    function AbriuXdb : boolean; override;
    procedure ProcuraRegXdb; override;
    procedure PosicionaRegProximoXdb; override;
    procedure LeRegXdb(Var reg); override;
    procedure PosicionaRegLimboXdb; override;
    function DBEofXdb : boolean; override;
    function EofXdb : boolean; override;
    function MontaWhere : ansistring; override;
    function MontaOrderBy : ansistring; override;
  public
    Codigo : smallint;
    constructor create; override;
  end;

  TDBRegistroTabImp = class(TDBRegistro)
  protected
    procedure CreateCampos(ACampos : TDBCampos); override;
    procedure CreateChaves(ACampos : TDBCampos); override;
    function GetSizeOfReg : integer; override;
    function GetNomeTabela : ansistring; override;
  public
  end;

  TBrowseTabTxt = class(TBrowseTabela)
  protected
    function GetTipoDBRegistro : TDBRegistroClass; override;
    function AbriuConnectionSql : boolean; override;
    function GetSqlConnection : TSqlConnection; override;
    function AbriuXdb : boolean; override;
    procedure ProcuraRegXdb; override;
    procedure PosicionaRegProximoXdb; override;
    procedure LeRegXdb(Var reg); override;
    procedure PosicionaRegLimboXdb; override;
    function DBEofXdb : boolean; override;
    function EofXdb : boolean; override;
    function MontaWhere : ansistring; override;
    function MontaOrderBy : ansistring; override;
  public
    Codigo : string;
    Nome : string;
    CodImp : smallint;
    constructor create; override;
  end;

  TDBRegistroTabTxt = class(TDBRegistro)
  protected
    procedure CreateCampos(ACampos : TDBCampos); override;
    procedure CreateChaves(ACampos : TDBCampos); override;
    function GetSizeOfReg : integer; override;
    function GetNomeTabela : ansistring; override;
  public
  end;

const XDoc = 10;  YDoc = 10;
      NLin = 03;  NCol = 40;
      TxtCodIdx = 1;
      TxtNomIdx = 2;
      ImpCodIdx = 1;
      ImpNomIdx = 2;
      ImpSisIdx = 3;

var TabTxt,TabImp    : DBArq;
    ImprDefault,
    Impressora       : TpImpressora;
    AbriuTxt,AbriuImp,
    AbriuImpXdb,
    AbriuImpSql,
    AbriuTxtXdb,
    AbriuTxtSql : boolean;
    SqlConnectionTabImp : TSqlConnection;
    TabImpDsk : TTabelaDsk;
    SqlConnectionTabTxt : TSqlConnection;
    TabTxtDsk : TTabelaDsk;

procedure InitImp(Path,CodTexto: string);
procedure InitImp2 (Path : string; CodImp : Smallint);
procedure Print_File ( FileName         : String;
                       CodImp           : Smallint;
                       NumCopias        : Smallint;
                       Destino          : String        );
procedure AbreTabTxt (Path: string);
procedure FechaTabTxt;
procedure AbreTabTxtSql(SqlConnection : TSqlConnection);
procedure FechaTabTxtSql;
procedure LeTexto(CodTexto: string;  var Texto: TpTexto);
procedure AbreTabImp (Path: string);
procedure FechaTabImp;
procedure AbreTabImpSql(SqlConnection : TSqlConnection);
procedure FechaTabImpSql;

var
  ComandoDeImpressao : String;

    
{------------------------------------------------------------------------}
                               implementation
{------------------------------------------------------------------------}

{TBrowseTabImp}
function TBrowseTabImp.GetTipoDBRegistro : TDBRegistroClass;
begin
  result := TDBRegistroTabImp;
end;

function TBrowseTabImp.AbriuConnectionSql : boolean;
begin
  result := AbriuImpSql;
end;

function TBrowseTabImp.GetSqlConnection : TSqlConnection;
begin
  result := SqlConnectionTabImp;
end;

function TBrowseTabImp.AbriuXdb : boolean;
begin
  result := AbriuImpXdb;
end;

procedure TBrowseTabImp.ProcuraRegXdb;
begin
  ProcuraReg(TabImp,Codigo);
end;

procedure TBrowseTabImp.PosicionaRegProximoXdb;
begin
 PosicionaReg(TabImp,xdb.proximo);
end;

procedure TBrowseTabImp.LeRegXdb(Var reg);
begin
  xdb.LeReg(TabImp,Reg);
end;

procedure TBrowseTabImp.PosicionaRegLimboXdb;
begin
  PosicionaReg(TabImp,Limbo);
end;

function TBrowseTabImp.DBEofXdb : boolean;
begin
  result := DBEof(TabImp);
end;

function TBrowseTabImp.EofXdb : boolean;
var
  Reg : TpImpressora;
begin
  Reg.codigo := 0;
  fillchar(Reg,sizeof(Reg),0);
  if ok then begin
    LeReg(TabImp,Reg);
    if Codigo > 0 then
      result := Reg.Codigo > Codigo
    else
      result := false;
  end
  else
    result := false;
end;

function TBrowseTabImp.MontaWhere : ansistring;
begin
  if Codigo > 0 then
    result := 'CODIGO ='+QuotedStr(inttostr(Codigo))
  else
    result := '';
end;

function TBrowseTabImp.MontaOrderBy : ansistring;
begin
  result := 'CODIGO';
end;

constructor TBrowseTabImp.create;
begin
  inherited;
  Codigo := 0;
end;

{TDBRegistroTabImp}
procedure TDBRegistroTabImp.CreateCampos(ACampos : TDBCampos);
var
  Reg : TpImpressora;
  UmCampo : TDBCamposItem;
begin
  Reg.codigo := 0;
  fillchar(Reg,sizeof(Reg),0);
  with ACampos do begin
    UmCampo := adicionaCampoSmallint('CODIGO',Reg.Codigo,Reg);
    UmCampo.OmiteNulo := false;
    adicionaCampoString('NOME',Reg.Nome,Reg,31);
    adicionaCampoString('NOMESIS',Reg.NomeSis,Reg,31);
    adicionaCampoString('FFEED',Reg.FFeed,Reg,255);
    adicionaCampoString('COMP',Reg.Comp,Reg,255);
    adicionaCampoString('NORM',Reg.Norm,Reg,255);
    adicionaCampoString('EXPA',Reg.Expa,Reg,255);
    adicionaCampoSmallint('NCOLCOMP',Reg.NColComp,Reg);
    adicionaCampoSmallint('NCOLNORM',Reg.NColNorm,Reg);
    adicionaCampoSmallint('NCOLEXPA',Reg.NColExpa,Reg);
    adicionaCampoString('NORMLPI',Reg.NormLPI,Reg,11);
    adicionaCampoString('CHAR6LPI',Reg.Char6LPI,Reg,11);
    adicionaCampoString('CHAR8LPI',Reg.Char8LPI,Reg,11);
    adicionaCampoSmallint('NLINHAS',Reg.NLinhas,Reg);
    adicionaCampoSmallint('CPS',Reg.CPS,Reg);
    adicionaCampoByte('CHARSET',Reg.CharSet,Reg);
  end;
end;

procedure TDBRegistroTabImp.CreateChaves(ACampos : TDBCampos);
var
  Codigo : smallint;
  UmCampo : TDBCamposItem;
begin
  Codigo := 0;
  Umcampo := ACampos.adicionaCampoSmallint('CODIGO',Codigo,Codigo);
  Umcampo.OmiteNulo := false;
end;

function TDBRegistroTabImp.GetSizeOfReg : integer;
begin
  result := sizeof(TpImpressora);
end;

function TDBRegistroTabImp.GetNomeTabela : ansistring;
begin
  result := 'tabimp2';
end;

{TBrowseTabTxt}
function TBrowseTabTxt.GetTipoDBRegistro : TDBRegistroClass;
begin
  result := TDBRegistroTabTxt;
end;

function TBrowseTabTxt.AbriuConnectionSql : boolean;
begin
  result := AbriuTxtSql;
end;

function TBrowseTabTxt.GetSqlConnection : TSqlConnection;
begin
  result := SqlConnectionTabTxt;
end;

function TBrowseTabTxt.AbriuXdb : boolean;
begin
  result := AbriuTxtXdb;
end;

procedure TBrowseTabTxt.ProcuraRegXdb;
begin
  ProcuraReg(TabTxt,Codigo);
end;

procedure TBrowseTabTxt.PosicionaRegProximoXdb;
begin
 PosicionaReg(TabTxt,xdb.proximo);
end;

procedure TBrowseTabTXt.LeRegXdb(Var reg);
begin
  xdb.LeReg(TabTxt,Reg);
end;

procedure TBrowseTabTxt.PosicionaRegLimboXdb;
begin
  PosicionaReg(TabTxt,Limbo);
end;

function TBrowseTabTxt.DBEofXdb : boolean;
begin
  result := DBEof(TabTxt);
end;

function TBrowseTabTxt.EofXdb : boolean;
var
  Reg : TpTexto;
begin
  Reg.codigo := '';
  fillchar(Reg,sizeof(Reg),0);
  if ok then begin
    LeReg(TabTxt,Reg);
    if Codigo > '' then
      result := Reg.Codigo > Codigo
    else
      result := false;
  end
  else
    result := false;
end;

function TBrowseTabTxt.MontaWhere : ansistring;
begin
  if Codigo > '' then
    result := 'CODIGO ='+QuotedStr(Codigo)
  else if Nome > '' then
    result := 'NOME ='+QuotedStr(Nome)
  else if CodImp > 0 then
    result := 'CODIMP ='+QuotedStr(inttostr(CodImp))
  else
    result := '';
end;

function TBrowseTabTxt.MontaOrderBy : ansistring;
begin
  if Codigo > '' then
    result := 'CODIGO'
  else if Nome > '' then
    result := 'NOME'
  else if CodImp > 0 then
    result := 'CODIMP';
end;

constructor TBrowseTabTxt.create;
begin
  inherited;
  Codigo := '';
  Nome := '';
  CodImp := 0;
end;

{TDBRegistroTabTxt}
procedure TDBRegistroTabTxt.CreateCampos(ACampos : TDBCampos);
var
  Reg : TpTexto;
  UmCampo : TDBCamposItem;
begin
  Reg.codigo := '';
  fillchar(Reg,sizeof(Reg),0);
  with Acampos do begin
    UmCampo := adicionaCampoString('CODIGO',Reg.Codigo,Reg,15);
    UmCampo.OmiteNulo := false;
    UmCampo := adicionaCampoString('NOME',Reg.Nome,Reg,31);
    UmCampo.OmiteNulo := false;
    adicionaCampoSmallint('CODIMP',Reg.CodImp,Reg);
    adicionaCampoSmallint('TAMANHODAFONTE',Reg.TamanhoDaFonte,Reg);
    adicionaCampoBoolean('AUTOAJUSTE',Reg.AutoAjuste,Reg);
    adicionaCampoBoolean('RETRATO',Reg.Retrato,Reg);
    adicionaCampoSmallint('MARGEMSUPERIOR',Reg.MargemSuperior,Reg);
    adicionaCampoSmallint('MARGEMESQUERDA',Reg.MargemEsquerda,Reg);
    adicionaCampoString('TIPOPAPEL',Reg.TipoPapel,Reg,19);
    adicionaCampoSmallint('QTDELINHAS',Reg.QtdeLinhas,Reg);
  end;
end;

procedure TDBRegistroTabTxt.CreateChaves(ACampos : TDBCampos);
var
  Codigo : string;
  UmCampo : TDBCamposItem;
begin
  Codigo := '';
  Umcampo := ACampos.adicionaCampoString('CODIGO',Codigo,Codigo,15);
  Umcampo.OmiteNulo := false;
end;

function TDBRegistroTabTxt.GetSizeOfReg : integer;
begin
  result := sizeof(TpTexto);
end;

function TDBRegistroTabTxt.GetNomeTabela : ansistring;
begin
  result := 'tabtxt';
end;

procedure AbreTabImpSql(SqlConnection : TSqlConnection);
begin
  AbriuImpSql := true;
  if not assigned(TabImpDsk) then
    TabImpDsk := TTabelaDsk.create(SqlConnection,TDBRegistroTabImp)
  else
    TabImpDsk.SqlConnection := SqlConnection;
end;

procedure FechaTabImpSql;
begin
  AbriuImpSql := false;
end;

procedure AbreTabTxtSql(SqlConnection : TSqlConnection);
begin
  AbriuTxtSql := true;
  if not assigned(TabTxtDsk) then
    TabTxtDsk := TTabelaDsk.create(SqlConnection,TDBRegistroTabTxt)
  else
  begin
    TabTxtDsk.SqlConnection := SqlConnection;
  end;
end;

procedure FechaTabTxtSql;
begin
  AbriuTxtSql := false;
  FreeAndNil(TabTxtDsk);
end;


procedure AbreTabTxtXdb (Path: string);
var Arq: text;
    st : string{Str40};
begin
  assign(Arq,Path+'/def/tabtxt.def');
  {$I-}  reset(Arq);
  if ioresult = 0 then begin
    st := '';
    while not eof(Arq) and (st <= Space(length(st))) do readln(Arq,st);
    close(Arq);
    assign(Arq,Path+'/'+st);
    reset(Arq);
    AbriuTxtXdb := (ioresult = 0);
    {$I+}
    if AbriuTxtXdb then begin
      close(Arq);
      AbreDBArqPorDef (TabTxt,Path,'tabtxt');
    end
  end
  else AbriuTxtXdb := false;
end; (* AbreTabTxt *)

procedure AbreTabTxt(Path : string);
begin
  if not AbriuTxt then begin
    SqlConnectionTabTxt := GetSqlConnectionSql(Path,'tabtxt');
    if assigned(SqlConnectionTabTxt) then
      AbreTabTxtSql(SqlConnectionTabTxt);
    if not AbriuTxtSql then
      AbreTabTxtXdb(Path);
    AbriuTxt := AbriuTxtXdb or AbriuTxtSql;
  end;
end;

procedure FechaTabTxt;
begin
  if AbriuTxtSql then begin
    FechaTabTxtSql;
    SqlConnectionTabTxt := nil;
    AbriuTxt := false;
  end
  else
    if AbriuTxt then begin
      FechaDBArq(TabTxt);
      AbriuTxtXdb := false;
      AbriuTxt := false;
    end; (* if *)
end; (* FechaTabTxt *)


procedure LeTexto(CodTexto: string;  var Texto: TpTexto);
begin
  if AbriuTxtSql then begin
    if assigned(TabTxtDsk) then
      TabTxtDsk.le(CodTexto,Texto);
  end
  else
    if AbriuTxtXdb then begin
      fillchar(Texto,sizeof(TpTexto),0);
      if AbriuTxt then begin
        ProcuraReg(TabTxt,CodTexto);
        if Ok and ExisteChave then LeReg(TabTxt,Texto);
        PosicionaReg(TabTxt,Limbo);
      end;
    end;
end; (* LeTexto *)

procedure AbreTabImp (Path: string);
begin
  if not AbriuImp then begin
    SqlConnectionTabImp := GetSqlConnectionSql(Path,'tabimp2');
    if assigned(SqlConnectionTabImp) then
      AbreTabImpSql(SqlConnectionTabImp);
    if not AbriuImpSql then
      AbreDbArqSemErro (TabImp, Path, 'tabimp2', AbriuImpXdb);
    AbriuImp := AbriuImpXdb or AbriuImpSql;
  end;
end; (* AbreTabImp *)


procedure FechaTabImp;
begin
  if AbriuImpSql then begin
    FechaTabImpSql;
    SqlConnectionTabImp := nil;
    AbriuImp := false;
  end
  else
    if AbriuImpXdb then begin
      FechaDBArq(TabImp);
      AbriuImpXdb := false;
      AbriuImp := false;
    end; (* if *)
end; (* FechaTabImp *)


procedure LeImpressora(CodImp: SmallInt;  var Impr: TpImpressora);
begin
  Impr := ImprDefault;
  if AbriuImpSql then begin
    if assigned(TabImpDsk) then
      TabImpDsk.le(CodImp,Impr);
  end
  else
    if AbriuImpXdb then begin
      ProcuraReg(TabImp,CodImp);
      if Ok and ExisteChave then LeReg(TabImp,Impr);
      PosicionaReg(TabImp,Limbo);
    end; (* if *)
end; (* LeImpressora *)


procedure InitImp(Path,CodTexto: string);
var
  Texto  : TpTexto;
  ImpAux : TpImpressora;
begin
  ImpAux.Nlinhas := 0;
  fillchar(ImpAux,sizeof(ImpAux),0);
  Texto.Codigo := '';
  fillchar(Texto,sizeof(Texto),0);
  Impressora := ImprDefault;
  AbreTabTxt(Path);
  LeTexto(CodTexto,Texto);
  FechaTabTxt;
  if Texto.Codigo > '' then begin
    AbreTabImp(Path);
    LeImpressora(Texto.CodImp,ImpAux);
(*----------- Scat 28.368 ------------------------ *)
    if (Texto.QtdeLinhas > 0)and(Texto.QtdeLinhas<>ImpAux.Nlinhas) 
    then Impressora.Nlinhas := Texto.QtdeLinhas
    else Impressora.NLinhas := ImpAux.NLinhas;
(*------------------------------------------------ *)
    Impressora.NColNorm     := ImpAux.NColNorm;
    FechaTabImp;
  end;
end; (* InitImp *)

procedure InitImp2 (Path : string; CodImp : Smallint);
begin
  Impressora := ImprDefault;
  if CodImp >= 0 then begin
    AbreTabImp (Path);
    LeImpressora (CodImp, Impressora);
    FechaTabImp;
  end;
end; (* InitImp *)

procedure Print_File ( FileName         : String;
                       CodImp           : Smallint;
                       NumCopias        : Smallint;
                       Destino          : String        );
var 
  tty      : string;
  EConsole : boolean;
  i        : Smallint;
  ProcFile : String;
  Comando  : String;
begin
  if ComandoDeImpressao > '' then begin
    Comando := ComandoDeImpressao;
    i := Pos ('$1', Comando);
    if i > 0 then
      Comando := Copy (Comando, 1, i-1) + FileName + Copy (Comando, i+2, 250);
    i := Pos ('$2', Comando);
    if i > 0 then
      Comando := Copy (Comando, 1, i-1) + IntStr(NumCopias) + Copy (Comando, i+2, 250);
    i := Pos ('$3', Comando);
    if i > 0 then
      Comando := Copy (Comando, 1, i-1) + Destino + Copy (Comando, i+2, 250);
    i := Pos ('$4', Comando);
    if i > 0 then
      Comando := Copy (Comando, 1, i-1) + IntStr(CodImp) + Copy (Comando, i+2, 250);
    punix.shell (Comando);
  end
  else begin
    if CodImp >= 0 then
      ProcFile := 'proctxt ' + IntStr (CodImp) + ' '
    else
      ProcFile := 'cat ';
    if (Destino = '') or (Destino = 'LOCAL') then begin
      tty := GetEnv('TTY');
      EConsole := (copy(tty,1,3) = 'tty') and ((copy(tty,4,1) >= '0') and (copy(tty,4,1) <= '9'));
      if EConsole then
        punix.shell (ProcFile + FileName + ' | lpr -#' + IntStr(NumCopias))
      else
        for i := 1 to NumCopias do
          if CodImp >= 0 then
            punix.shell (ProcFile + ' -imp ' + FileName)
          else
            punix.shell (ProcFile + FileName + ' | imp');
    end
    else
      punix.shell (ProcFile + FileName +
                  ' | lpr -P ' + Destino + ' -#' + IntStr(NumCopias));
  end;
end;

initialization
  ComandoDeImpressao := '';
  ImprDefault.Codigo   := 0; 
  ImprDefault.Nome     := 'Impressora Default'; 
  ImprDefault.NomeSis  := 'lp';
  ImprDefault.FFeed    := ^L;
  ImprDefault.Comp     := ^O; 
  ImprDefault.Norm     := ^R; 
  ImprDefault.Expa     := ^R;
  ImprDefault.NColComp := 230; 
  ImprDefault.NColNorm := 132; 
  ImprDefault.NColExpa := 230;
  ImprDefault.Char6LPI := #27#50;
  ImprDefault.Char8LPI := #27#48;
  ImprDefault.NormLPI  := #27#50;
  ImprDefault.NLinhas  := 60;
  ImprDefault.CPS      := 300;
  ImprDefault.CharSet  := 1;
  Impressora := ImprDefault;
  AbriuImpXdb := false;
  AbriuImpSql := false;
  AbriuTxtXdb := false;
  AbriuTxtSql := false;
  TabImpDsk := nil;
  TabTxtDsk := nil;

finalization
  if assigned(TabImpDsk) then
    FreeAndNil(TabImpDsk);
  if assigned(TabTxtDsk) then
    FreeAndNil(TabTxtDsk);
end.
