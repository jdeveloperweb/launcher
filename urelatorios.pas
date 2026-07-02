unit urelatorios;
{$V+}
{$H-}

{$IFDEF MSWINDOWS}
{$M 1638400,104857600}
{$ENDIF}

interface
uses
{$IFDEF LINUX}
{$IFDEF FPC} BaseUnix, {$ELSE} Libc, {$ENDIF}
{$ELSE}
  windows,
{$ENDIF}
  pxmllib, Classes, stringtransf, punix, SysUtils, datalib, lib1,xdb,smv,
  sccidef,  scciio, pdb,  bdlib, sccilib, domlib,wsistarqlib,
{$IFNDEF FPC} DB, {$ENDIF}
  sccisqldef;


type
  TStatusRelatorio=(stat_Executando,stat_Suspenso,stat_TerminoOk,stat_TerminoErro,stat_CanceladoPeloUsuario);
  TTipoRelat = (tiporelat_Texto);
  

  TRelatorioGenerico = class
  private
    FXml : TpXml;
    FTipoRelat : TTipoRelat;
    FSqlConnection : TSqlConnection;
    FCodTxt : string;
    procedure ParseCampoXDB(Dominio : string; 
                            Var NomeDB,
                                Chave,
                                Desc : string);
    procedure TrataCampoXdb(Campo : TpXmlNode;
                            valor : string;
                            Dominio : String;
                            QtdCampos : integer;
                            Metadados : TpMemory;
                            ValNaDesc : boolean);
    
    procedure TrataMunicipioPeloUFDaEmpresa(Campo : TpXmlNode;
                            valor : string;
                            Dominio : String;
                            QtdCampos : integer;
                            Metadados : TpMemory;
                            ValNaDesc : boolean);
    
    procedure ParseCampoSql(    Dominio : string; 
                            Var NomeDB,
                                Chave,
                                Desc : string;
                            var ChaveNaDesc : boolean;
                            var where,orderby : string);

    procedure TrataCampoSql(Campo : TpXmlNode;
                            valor : string;
                            Dominio : String;
                            QtdCampos : integer;
                            Metadados : TpMemory);
    procedure TrataCampoCombo(Campo : TpXmlNode;
                              valor : string;
                              QtdCampos : integer;
                              Metadados : TpMemory);
    procedure TrataCampoClasse(Campo : TpXmlNode;
                               valor : ansistring;
                               QtdCampos : integer;
                               MetaDados : TpMemory);
    procedure TrataCampoOpcaoPeloTipo(Campo : TpXmlNode;
                                      valor : ansistring;
                                      Dominio : string;
                                      QtdCampos : integer;
                                      MetaDados : TpMemory);
    procedure TrataCampoArqCtr(Campo : TpXmlNode;
                               valor : ansistring;
                               QtdCampos : integer;
                               MetaDados : TpMemory);
    procedure TrataCampoUF(Campo : TpXmlNode;
                           Valor : ansistring;
                           QtdCampos : integer;
                           MetaDados : TpMemory);
    procedure TrataComboTipoFCVS(Campo : TpXmlNode;
                                 valor : ansistring;
                                 QtdCampos : integer;
                                 MetaDados : TpMemory);
    procedure TrataComboTpCtr(Campo : TpXmlNode;
                                 valor : ansistring;
                                 QtdCampos : integer;
                                 MetaDados : TpMemory);    function GetNome : string;
    
    procedure TrataComboCarteira(Campo : TpXmlNode;
                                 valor : ansistring;
                                 QtdCampos : integer;
                                 MetaDados : TpMemory);

    procedure TrataComboClassificacaoSerie(Campo : TpXmlNode;
                                           valor : ansistring;
                                           QtdCampos : integer;
                                           MetaDados : TpMemory);
    
    function GetTitulo : string;
    procedure SubstituiVariaveis(Var Cmd : ansistring; Parms : TpMemory); overload;
    procedure SubstituiVariaveis(Var Cmd : ansistring; Parms : TpXmlNode); overload;
    function GetSaidasXml : TpXmlNode;
  public
    constructor create(Nome : string); reintroduce; virtual;
    destructor destroy; override;
    function PegaProximoDialogo(Dados : TpMemory; IdTela : Integer; MetaDados : TpMemory) : boolean;
    procedure ValidaParametros(Dados : TpMemory); overload;
    procedure ValidaParametros(Dados: TpXmlNode); overload;
    function TituloUsuario(Dados : TpMemory) : string; overload;
    function TituloUsuario(Dados : TpXmlNode) : string; overload;
    property TipoRelat : tTipoRelat read FTipoRelat;
    property Xml : TpXml read FXml;
    property Nome : string read GetNome;
    property Titulo : string read GetTitulo;
    property SaidasXml : TpXmlNode read GetSaidasXml;
    property SqlConnection : TSqlConnection read FSqlConnection write FSqlConnection;
    property CodTxt : string read FCodTxt;
  end;

  TRelatorioGenericoTexto = class
  private
    FSaidas  : TStringlist;
    FComando : ansistring;
    FSqlConnection : TSqlConnection;
    procedure MontaShell(Var Cmd : ansistring; Parms : TpMemory); overload;
    procedure MontaShell(Var Cmd : ansistring; Parms : TpXmlNode); overload;
    procedure GeraArquivos(RelatGen : TRelatorioGenerico; Dados : TpMemory); overload;
    procedure GeraArquivos(RelatGen : TRelatorioGenerico; Dados : TpXmlNode); overload;
    procedure ConverteNulos(RelatGen : TRelatorioGenerico; Dados : TpMemory); overload;
    procedure ConverteNulos(RelatGen : TRelatorioGenerico; Dados : TpXmlNode); overload;
  public
    constructor create;
    destructor destroy; override;
    function Execute(Usuario : string; RelatGen : TRelatorioGenerico; 
                     Dados : TpMemory; Var Spool : ansistring; 
                     Espera : boolean = true) : longint; overload;
    function Execute(Usuario : string; RelatGen : TRelatorioGenerico; 
                     Dados : TpXmlNode; Var Spool : ansistring; 
                     Espera : boolean = true) : longint; overload;
    property SqlConnection : TSqlConnection read FSqlConnection write FSqlConnection;
//    property Saidas : TStringlist read FSaidas;
  end;

    procedure ExecutaShell(RegistraExecucao : boolean;
                       Usuario : string;
                       ID : longint;
                       Inicio : tdatetime; 
                       Nome : String;
                       Cmd : ansistring;
                       titulo : string;
                       co_sistema : ansistring = 'R';
                       co_modulo : integer = 0);
    
    function InsereExecucaoRelatorio(Pid : integer;
                                     Nome,
                                     Diretorio : String;
                                     titulo : string;
                                     co_sistema : ansistring = 'R';
                                     co_modulo : integer = 0):integer;

    procedure AtualizaExecucaoRelatorio(Id,
                                        ErroCode : integer;
                                        Diretorio : String;
                                        titulo : string;
                                        Erro : Ansistring);
    procedure GetBuscaExecucaoRelatorio(JsonIn,JsonOut:TpXml);
    procedure VerificaExecAndamentoPorUsuario(CoSistema,Titulo,Erro : String; CoModulo : Integer);
  
implementation


constructor TRelatorioGenerico.create(Nome : string);
var  Stream : TMemoryStream;
begin
  try
  FSqlConnection := nil;
  FXml := TpXml.create;
  Stream := TMemoryStream.create;
  try
    if LeArqsXml(GetSqlConnection(getenv('SCCIDIRATV')),nome+'.xml','xmlrelatorios',Stream) then
      FXml.XMLParseStream(Stream)
    else  
      FXml.XMLParseFile(GetEnv('SCCIDIRARQS')+PathDelim+'xmlrelatorios'+PathDelim+nome+'.xml');

  except
    on e : exception do
      raise exception.create('Não foi possível abrir definição do relatório.'+
                              #13+e.message);
  end;
  if uppercase(FXml.DocumentElement.attributes['TIPO']) = 'TEXTO' then
    FTipoRelat := tiporelat_texto
  else
    raise exception.create('Tipo de relatório não suportado.');
  FCodTxt := FXml.DocumentElement.attributes['CODTXT'];
  finally
   Stream.free;
  end;
end;

destructor TRelatorioGenerico.destroy;
begin
  FXml.free;
  inherited;
end;

procedure TRelatorioGenerico.ParseCampoXDB(Dominio : string; 
                                           Var NomeDB,
                                               Chave,
                                               Desc : string);
begin
  Dominio := copy(Dominio,pos(':',Dominio)+1,length(Dominio));
  NomeDB := copy(Dominio,1,pos('/',Dominio)-1);
  Dominio := copy(Dominio,length(NomeDB)+2,length(Dominio));
  Chave := copy(Dominio,1,pos('/',Dominio)-1);
  Dominio := copy(Dominio,length(Chave)+2,length(Dominio));
  Desc := Dominio;
end;

procedure TRelatorioGenerico.TrataCampoXdb(Campo : TpXmlNode;
                                           valor : string;
                                           Dominio : String;
                                           QtdCampos : integer;
                                           Metadados : TpMemory;
                                           ValNaDesc : boolean);
var
  Lista, DescSt, ValSt  : TStringlist;
  Aux, NomeDB,
  Chave, Desc           : string;
  i                     : Integer;
  EditorDescricoes,
  EditorValores         : Tstringlist;
begin
  Desc := '';
  Chave := '';
  NomeDB := '';
  
  ParseCampoXDB(Dominio,NomeDB,Chave,Desc);
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  EditorDescricoes := Tstringlist.create;
  EditorValores := Tstringlist.create;
  try
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end;
    
    if Campo.attributes['dadoslista'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dadoslista'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dadoslista'],i,';',#255,#255);
        EditorDescricoes.Add  (Palavra(Aux, 2, '=', #255, #255));
        Editorvalores.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end;

    if Campo.Attributes['mestre'] > '' then begin
      MetaDados.AddcampoComboDetalhe(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                     Campo.Attributes['titulo'],
                                     QtdCampos,true,
                                     uppercase(Campo.Attributes['obrigatorio']) = 'T',
                                     Campo.Attributes['todosnacombomestre'],
                                     Dominio,
                                     palavra(Campo.Attributes['mestre'],1,':',#255,#255),
                                     palavra(Campo.Attributes['mestre'],2,':',#255,#255));
    end
    else begin
      MontaDominioXdb(Lista, NomeDB, Chave, Desc);
      for i := 0 to Lista.Count-1 do begin
        Aux := Lista[i];
        if ValNaDesc then begin
          DescSt.Add  (Palavra(Aux, 2, '=', #255, #255)+'-'+Palavra(Aux, 1, '=', #255, #255));
          EditorDescricoes.add(Palavra(Aux, 2, '=', #255, #255)+'-'+Palavra(Aux, 1, '=', #255, #255));
        end
        else begin
          DescSt.Add  (Palavra(Aux, 1, '=', #255, #255));
          EditorDescricoes.Add(Palavra(Aux, 1, '=', #255, #255));
        end;
        ValSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        EditorValores.Add(Palavra(Aux, 2, '=', #255, #255));
      end;

      if Campo.Attributes['UsaEditaLista'] = 'T' then
        MetaDados.AddCampoComboComLista(Campo.NodeName,
                                        '_Lista_'+Campo.NodeName,
                                        ValSt.indexof(valor),DescSt,ValSt,
                                        Nil,Campo.Attributes['titulo'],
                                        QtdCampos,true,
                                        EditorDescricoes,
                                        EditorValores,
                                        Campo.Attributes['Opcoes'],
                                        '',uppercase(Campo.Attributes['obrigatorio']) = 'T',
                                        dominio)
      else
        MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                Campo.Attributes['titulo'],
                                QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T',
                                dominio);
    end;
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
    EditorDescricoes.free;
    EditorValores.free;
  end;
end;

procedure TRelatorioGenerico.TrataMunicipioPeloUFDaEmpresa(Campo : TpXmlNode;
                                           valor : string;
                                           Dominio : String;
                                           QtdCampos : integer;
                                           Metadados : TpMemory;
                                           ValNaDesc : boolean);
var
  Lista, DescSt, ValSt  : TStringlist;
  Aux   : String;
  I     : Integer;
  Reg   : TpArqMun;
  Uf    : String;
  Browse: TBrowseMunic;
begin
  Reg.UFMun := '';
  fillchar(Reg,sizeof(Reg),0);
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  Le_arq_fis;
  AbreMunicipio;
  try
    Uf := ScciConf.UfEmp;
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end;

    Browse := TBrowseMunic.create;
    try
      Browse.SetPorNomeMun('');
      Browse.abre;
      try
        while not Browse.eof do begin
          Browse.le(Reg);
          if (copy(Reg.UFMun, 1, 2) = UF) and      
             (trim(stripstr(copy(Reg.NomeMun,1,23))) > '') then begin
             if ValNaDesc then  
                DescSt.Add  (Reg.ChaveMun+'-'+Reg.NomeMun)
             else  DescSt.Add  (Reg.NomeMun);
             ValSt.Add  (Reg.ChaveMun);
          end;
          Browse.proximo;
        end;
      finally
        Browse.fecha;
      end;
    finally
      Browse.free;
    end;

    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T',
                            dominio);
  finally
    FechaMunicipio;
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.ParseCampoSql(Dominio : string; 
                                           Var NomeDB,
                                               Chave,
                                               Desc : string;
                                           Var ChaveNaDesc : boolean;
                                           var where,orderby : string);
begin
  Dominio := copy(Dominio,pos(':',Dominio)+1,length(Dominio));
  NomeDB := copy(Dominio,1,pos('/',Dominio)-1);
  Dominio := copy(Dominio,length(NomeDB)+2,length(Dominio));
  Chave := copy(Dominio,1,pos('/',Dominio)-1);
  Dominio := copy(Dominio,length(Chave)+2,length(Dominio));
  if pos('/',Dominio) > 0 then begin
    Desc := copy(Dominio,1,pos('/',Dominio)-1);
    Dominio := copy(Dominio,length(Desc)+2,length(Dominio));
    ChaveNaDesc :=  upstr(lib1.Palavra(Dominio, 1, '/', #255, #255)) = upstr('ChaveNaDesc');
    where := lib1.Palavra(Dominio, 2, '/', #255, #255);
    orderby :=  lib1.Palavra(Dominio, 3, '/', #255, #255);
  end
  else begin
    Desc := Dominio;
    ChaveNaDesc := false;
  end;
end;

procedure TRelatorioGenerico.TrataCampoSql(Campo : TpXmlNode;
                                           valor : string;
                                           Dominio : String;
                                           QtdCampos : integer;
                                           Metadados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  Aux, NomeDB,
  Chave, Desc,
  where,orderby           : string;
  i                     : Integer;
  ChaveNaDesc           : boolean;
begin
  Chave := '';
  Desc := '';
  NomeDb := '';
  ChaveNaDesc := false;
  where := '';
  orderby := '';
  ParseCampoSql(Dominio,NomeDB,Chave,Desc,ChaveNaDesc,where,orderby);
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end;
    if Campo.Attributes['mestre'] > '' then begin
      MetaDados.AddcampoComboDetalhe(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                     Campo.Attributes['titulo'],
                                     QtdCampos,true,
                                     uppercase(Campo.Attributes['obrigatorio']) = 'T',
                                     Campo.Attributes['todosnacombomestre'],
                                     Dominio,
                                     palavra(Campo.Attributes['mestre'],1,':',#255,#255),
                                     palavra(Campo.Attributes['mestre'],2,':',#255,#255));
    end
    else begin
      if ChaveNaDesc then 
        MontaDominioSql(SqlConnection,Lista, NomeDB, Chave, Desc,nil,true,where,orderby)
      else MontaDominioSql(SqlConnection,Lista, NomeDB, Chave, Desc,nil,false,where,orderby);
      for i := 0 to Lista.Count-1 do begin
        Aux := Lista[i];
        DescSt.Add  (Palavra(Aux, 1, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 2, '=', #255, #255));
      end;
      MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                              Campo.Attributes['titulo'],
                              QtdCampos,true,'',
                              uppercase(Campo.Attributes['obrigatorio']) = 'T',
                              Dominio);
    end;
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataCampoCombo(Campo : TpXmlNode;
                                             valor : string;
                                             QtdCampos : integer;
                                             Metadados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  Aux : string;
  i   : Integer;
  indice : integer;
begin
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end;
    if Campo.attributes['default'] > '' then
      indice := strtoint(Campo.Attributes['default'])
    else indice := ValSt.indexof(valor);  
    MetaDados.AddcampoCombo(Campo.NodeName,indice,DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

function TRelatorioGenerico.GetNome : string;
begin
  result := FXml.DocumentElement.Nodename;
end;

function TRelatorioGenerico.GetTitulo : string;
begin
  result := FXml.DocumentElement.attributes['titulo'];
end;

procedure TRelatorioGenerico.SubstituiVariaveis(Var cmd: ansistring; Parms : TpMemory);
var
  token,
  valor : string;
begin
  while pos('#',cmd) > 0 do begin
    token := cmd;
    delete(token,1,pos('#',cmd));
    if pos(' ',token) > 0 then
      token := copy(token,1,pos(' ',token)-1);
    valor := stringreplace(Parms.readval(token),'#',' ',[rfReplaceAll]);
    cmd := stringreplace(cmd,'#'+token,valor,
                         [rfReplaceAll,rfIgnoreCase]);
  end;
end;

procedure TRelatorioGenerico.SubstituiVariaveis(Var cmd: ansistring; Parms : TpXmlNode);
var
  token,
  valor : string;
begin
  while pos('#',cmd) > 0 do begin
    token := cmd;
    delete(token,1,pos('#',cmd));
    if pos(' ',token) > 0 then
      token := copy(token,1,pos(' ',token)-1);
    valor := stringreplace(Parms[token].AsString,'#',' ',[rfReplaceAll]);
    cmd := stringreplace(cmd,'#'+token,valor,
                         [rfReplaceAll,rfIgnoreCase]);
  end;
end;

function TRelatorioGenerico.TituloUsuario(Dados : TpMemory) : string;
var
  ansi : ansistring;
begin
  result := '';
  if assigned(FXml.DocumentElement['TituloUsuario']) then begin
    ansi := FXml.DocumentElement['TituloUsuario'].attributes['mascara'];
    SubStituiVariaveis(ansi,Dados);
    result := ansi;
  end;
  result := copy(result,1,255);
  if trim(result) = '' then
    result := GetTitulo;
end;

function TRelatorioGenerico.TituloUsuario(Dados : TpXmlNode) : string;
var
  ansi : ansistring;
begin
  result := '';
  if assigned(Dados['TituloUsuario']) then begin
    ansi := Dados['TituloUsuario'].attributes['mascara'];
    SubStituiVariaveis(ansi,Dados);
    result := ansi;
  end;
  result := copy(result,1,255);
  if trim(result) = '' then
    result := GetTitulo;
end;


function TRelatorioGenerico.GetSaidasXml : TpXmlNode;
begin
  result := FXml.DocumentElement['Saidas'];
end;

procedure TRelatorioGenerico.TrataCampoClasse(Campo : TpXmlNode;
                                              Valor : ansistring;
                                              QtdCampos : integer;
                                              MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
begin
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
//    DescSt.Sorted := true;
    MontaDominioClasseOrdenada(DescSt,ValSt,true);
//    DescSt.Sorted := true;
//    ValSt.sorted := true;
    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataCampoOpcaoPeloTipo(Campo : TpXmlNode;
                                                     Valor : ansistring;
                                                     Dominio : string;
                                                     QtdCampos : integer;
                                                     MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  Aux, NomeDB,
  Chave, Desc,
  where,orderby           : string;
  i                     : Integer;
  ChaveNaDesc           : boolean;
  EditorDescricoes,
  EditorValores         : Tstringlist;
  Items,
  ItemsVal : TStringlist;
begin
  Chave := '';
  Desc := '';
  where := '';
  orderby := '';
  NomeDb := '';
  ChaveNaDesc := false;
  ParseCampoSql(Dominio,NomeDB,Chave,Desc,ChaveNaDesc,where,orderby);
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  EditorDescricoes := Tstringlist.create;
  EditorValores := Tstringlist.create;
  Items := TStringlist.create;
  ItemsVal := TStringlist.create;
  try
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end;

    for i := 0 to DescSt.count -1 do
      EditorDescricoes.add(DescSt[i]);

    for i := 0 to ValSt.count -1 do
      EditorValores.add(ValSt[i]);

    if Campo.Attributes['UsaEditaLista'] = 'T' then begin
      MetaDados.AddCampoComboComListaDetalhe(Campo.NodeName,
                                      '_Lista_'+Campo.NodeName,
                                      ValSt.indexof(valor),DescSt,ValSt,
                                      Nil,Campo.Attributes['titulo'],
                                      QtdCampos,true,
                                      EditorDescricoes,
                                      EditorValores,
                                      Campo.Attributes['Opcoes'],
                                      '',
                                      uppercase(Campo.Attributes['obrigatorio']) = 'T',
                                      dominio,
                                     palavra(Campo.Attributes['mestre'],1,':',#255,#255),
                                     palavra(Campo.Attributes['mestre'],2,':',#255,#255),
                                     Campo.Attributes['todosnacombomestre']);
    end;
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
    EditorDescricoes.free;
    EditorValores.free;
    Items.free;
    ItemsVal.free;
  end;
end;

procedure TRelatorioGenerico.TrataCampoArqCtr(Campo : TpXmlNode;
                                              Valor : ansistring;
                                              QtdCampos : integer;
                                              MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  i, Indice             : integer;
begin
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
    Lista.Sorted := true;
    MontaDominioArqCtr(Lista);
    DescSt.Sorted := false;
    ValSt.Sorted  := false;
    for i := 0 to Lista.Count-1 do begin
      Indice := DescSt.add(copy(Lista[i],1,pos('=',Lista[i])-1));
      ValSt.insert(indice,copy(Lista[i],pos('=',Lista[i])+1,255));
    end;
    DescSt.insert(0,'');
    ValSt.insert(0,'');
    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataCampoUF(Campo : TpXmlNode;
                                          Valor : ansistring;
                                          QtdCampos : integer;
                                          MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  i,
  indice : integer;
  aux : string;
begin
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
    MontaUF(Lista);
    DescSt.sorted := true;
    for i := 0 to lista.count-1 do begin
      indice := DescSt.add(palavra(Lista[i],1,'=',#255,#255));
      Valst.insert(indice,palavra(Lista[i],2,'=',#255,#255));
    end;
    DescSt.sorted := false;
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.insert  (i-1,Palavra(Aux, 2, '=', #255, #255));
        ValSt.insert  (i-1,Palavra(Aux, 1, '=', #255, #255));
      end;
    end;
    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataComboTpCtr(Campo : TpXmlNode;
                                          Valor : ansistring;
                                          QtdCampos : integer;
                                          MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  i,
  indice : integer;
  aux : string;
begin
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
    MontaTipoCtr(Lista);
    Lista.Sorted := true;
    DescSt.sorted := false;
    indice := DescSt.add('Todos');
    Valst.insert(indice,'');

    for i := 0 to lista.count-1 do begin
      indice := DescSt.add(palavra(Lista[i],1,'=',#255,#255));
      Valst.insert(indice,palavra(Lista[i],2,'=',#255,#255));
    end;
    DescSt.sorted := false;
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.insert  (i-1,Palavra(Aux, 2, '=', #255, #255));
        ValSt.insert  (i-1,Palavra(Aux, 1, '=', #255, #255));
      end;
    end;
    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataComboTipoFCVS(Campo : TpXmlNode;
                                                Valor : ansistring;
                                                QtdCampos : integer;
                                                MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
begin

  Valor := '0';
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  try
    DescSt.add('0 -Todos');
    ValSt.add('00');
    DescSt.add('01-Relatório de Contratos não Homologados(TR01)');
    ValSt.add('01');
    DescSt.add('02-Relatório de Contratos Homologados(TR02)');
    ValSt.add('02');
    DescSt.add('03-Relatório de Contratos Encerrados não Novados(TR03)');
    ValSt.add('03');
    DescSt.add('04-Relatório de Contratos Encerrados Novados(TR04)');
    ValSt.add('04');
    DescSt.add('05-Relatório de Contratos Homologados com Negativa de Cobertura(TR05)');
    ValSt.add('05');
    DescSt.add('21-Relatório de Contratos com Erro de Crítica');
    ValSt.add('21');
    DescSt.add('22-Relatório de Contratos com Erro de Crítica - RNV');
    ValSt.add('22');
    DescSt.add('23-Relatório de Contratos em Crítica');
    ValSt.add('23');
    DescSt.add('24-Relatório de Contratos em Situações não Previstas');
    ValSt.add('24');
    DescSt.add('31-Relatório de Contratos Evoluídos');
    ValSt.add('31');
    DescSt.add('32-Relatório de Contratos com Pedido de Habilitação Rejeitado');
    ValSt.add('32');
    DescSt.add('33-Relatório de Contratos com Transferência de Titularidade p/ Agente Cedente');
    ValSt.add('33');
    DescSt.add('34-Relatório de Contratos com Transferência de Titularidade p/ Agente Cessionário');
    ValSt.add('34');
    DescSt.add('41-Relatório de Contratos Incluídos no Ressarcimento');
    ValSt.add('41');
    DescSt.add('42-Relatório de Situação da Dívida - Agente Financeiro');
    ValSt.add('42');
    DescSt.add('43-Relatório de Contratos Utilizados no Abatimento');
    ValSt.add('43');
    DescSt.add('44-Relatório de Contratos Estornados');
    ValSt.add('44');
    DescSt.add('45-Relatório de Situação da Dívida');
    ValSt.add('45');
    DescSt.add('48-Relatório de Contratos Originários do FGTS com Diferencial na Taxa de Juros');
    ValSt.add('48');
    DescSt.add('49-Extrato de Pagamentos Efetuados');
    ValSt.add('49');
    DescSt.add('51-Relatório de Contratos com Término de Análise');
    ValSt.add('51');
    DescSt.add('52-Término de Análise');
    ValSt.add('52');
    DescSt.add('54-Relatório de Contratos com Documentação em Atraso');
    ValSt.add('54');
    DescSt.add('55-Relatório de Contratos com Término de Análise (Reprocessados)');
    ValSt.add('55');
    DescSt.add('57-Relatório de Contratos com Término de Análise (Reprocessados)-Consolidado');
    ValSt.add('57');
    DescSt.add('59-Relatório de Contratos com Término de Análise (TR)-Consolidado');
    ValSt.add('59');
    DescSt.add('61-Relatório de Contratos não Evoluídos Liberados para Análise');
    ValSt.add('61');
    DescSt.add('71-Relatório de Contratos Inexistentes no Cadastro Nacional de Mutuários');
    ValSt.add('71');
    DescSt.add('72-Relatório de Contratos com Indício de Múltiplos Financiamentos');
    ValSt.add('72');
    DescSt.add('73-Relatório de Contratos Existentes no Cadastro Nacional de Mutuários');
    ValSt.add('73');
    DescSt.add('78-Relatório de Contratos Existentes no CADMUT com Ocorrência de Sinistro');
    ValSt.add('78');
    DescSt.add('79-Relatório de Contratos Homologados Pendentes no Cadmut');
    ValSt.add('79');
    DescSt.add('80-Relatório de RCV Rejeitadas para Novação');
    ValSt.add('80');
    DescSt.add('81-Relatório de RNV Rejeitadas');
    ValSt.add('81');
    DescSt.add('82-Relatório de Contratos Novados com Tit. Emitidos');
    ValSt.add('82');
    DescSt.add('83-Relatório de RCV Automática Rejeitada');
    ValSt.add('83');
    DescSt.add('84-Relatório de Contratos com RCV Automática');
    ValSt.add('84');
    DescSt.add('85-Relatório de Planilhas de RNV Emitidas');
    ValSt.add('85');
    DescSt.add('86-Relatório de Contratos com ou sem RNV, RCV e RNV Automática');
    ValSt.add('86');
    DescSt.add('87-Relatório de Contratos com Solicitação de RNV');
    ValSt.add('87');
    DescSt.add('90-Relatório de Contratos com VAF3 e VAF4 Novados no Processamento');
    ValSt.add('90');
    DescSt.add('91-Relatório Analítico de Ctrs. c/ Saldo de VAF3 e VAF4 p/ Novação');
    ValSt.add('91');
    DescSt.add('92-Relatório Anal. de Ctrs. c/ Saldo de VAF3 e VAF4 p/ Novação(Valores em 01/01/1997)');
    ValSt.add('92');
    DescSt.add('93-Relatório Consolidado dos Valores Apurados de VAF3 e VAF4');
    ValSt.add('93');
    DescSt.add('94-Relatório de Contratos Originários do FGTS com Diferencial');
    ValSt.add('94');
    DescSt.add('95-Relatório de Contratos Originários do FGTS com Diferencial de Taxa de Juros');
    ValSt.add('95');
    DescSt.add('96-Relatório Analítico Cumulativo das Deduções');
    ValSt.add('96');
    DescSt.add('97-Relatório Especial RCNP');
    ValSt.add('97');
    DescSt.add('98-Relatório de RNV e RCV Rejeitadas');
    ValSt.add('98');
    DescSt.add('99-Relatório de RNV e RCV Acatadas');
    ValSt.add('99');
    DescSt.add('769601-Relatório de Registros Selecionados da Novação');
    ValSt.add('769601');
    DescSt.add('769602-Relatório de Registros Selecionados da Novação');
    ValSt.add('769602');
    DescSt.add('769603-Relatório de Registros Selecionados da Novação');
    ValSt.add('769603');
    DescSt.add('769604-Relatório de Registros Selecionados da Novação');
    ValSt.add('769604');
    DescSt.add('769605-Relatório de Registros Selecionados da Novação');
    ValSt.add('769605');
    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataComboCarteira(Campo : TpXmlNode;
                                                Valor : ansistring;
                                                QtdCampos : integer;
                                                MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  i,indice : integer;
begin
  le_arq_fis;
  abrecarteira;
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create; 
  try
    DescSt.add(' -Todos');
    ValSt.add('-1');    
    MontaCarteira(Lista);
    DescSt.sorted := true;
    for i := 0 to lista.count-1 do begin
      indice := DescSt.add(palavra(Lista[i],2,'=',#255,#255)+'-'+palavra(Lista[i],1,'=',#255,#255));
      Valst.insert(indice,palavra(Lista[i],2,'=',#255,#255));
    end;
    DescSt.sorted := false;
    MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                            Campo.Attributes['titulo'],
                            QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  fechacarteira;
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
  end;
end;

procedure TRelatorioGenerico.TrataComboClassificacaoSerie(Campo : TpXmlNode;
                                                          Valor : ansistring;
                                                          QtdCampos : integer;
                                                          MetaDados : TpMemory);
var
  Lista, DescSt, ValSt  : TStringlist;
  Aux                   : string;
  i                     : Integer;
  EditorDescricoes,
  EditorValores         : Tstringlist;
begin
  DescSt := TStringlist.create;
  ValSt  := Tstringlist.create;
  Lista  := Tstringlist.create;
  EditorDescricoes := Tstringlist.create;
  EditorValores := Tstringlist.create;
  try
    if Campo.attributes['dados'] > '' then begin
      for i := 1  to NumPalavras(Campo.attributes['dados'],';',#255,#255) do begin
        aux := palavra(Campo.attributes['dados'],i,';',#255,#255);
        DescSt.Add  (Palavra(Aux, 2, '=', #255, #255));
        ValSt.Add  (Palavra(Aux, 1, '=', #255, #255));
      end;
    end
    else begin
      DescSt.add('');
      ValSt.add('0');
    end;
    for i := 0 to MaxClassificacaoSerieStr do begin
      if ClassificacaoSerieStr[i] > '' then begin
        DescSt.add(ClassificacaoSerieStr[i]);
        EditorDescricoes.add(ClassificacaoSerieStr[i]);
        ValSt.add(intstr(i));
        EditorValores.add(intstr(i));
      end;
    end;

    if Campo.Attributes['UsaEditaLista'] = 'T' then
      MetaDados.AddCampoComboComLista(Campo.NodeName,
                                        '_Lista_'+Campo.NodeName,
                                        ValSt.indexof(valor),DescSt,ValSt,
                                        Nil,Campo.Attributes['titulo'],
                                        QtdCampos,true,
                                        EditorDescricoes,
                                        EditorValores,
                                        Campo.Attributes['Opcoes'],
                                        '',uppercase(Campo.Attributes['obrigatorio']) = 'T')
    else
        MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                Campo.Attributes['titulo'],
                                QtdCampos,true,'',uppercase(Campo.Attributes['obrigatorio']) = 'T');
  finally
    Lista.Free;
    DescSt.free;
    ValSt.free;
    EditorDescricoes.free;
    EditorValores.free;
  end;
end;


function TRelatorioGenerico.PegaProximoDialogo(Dados : TpMemory; IdTela : Integer; MetaDados : TpMemory) : boolean;
var
  Campo,
  XmlTela : TpXmlNode; 
  i,j : integer;
  valor : ansistring;
  Dominio : string;
  QtdCampos,
  digitos,
  valorint,
  decimais,
  Tamanho,
  TamanhoVisivel : integer;
  data : Tdata;
  DescSt,
  ValSt : Tstringlist;
  MA : TMes_Ano;
  valorreal : real;
  bool : boolean;
  Base : string;
begin
  QtdCampos := 0;
  XmlTela := FXml.DocumentElement['interface'+inttostr(IdTela)];
  if assigned(XmlTela) then begin
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      Dominio := uppercase(Campo.Attributes['Dominio']);
      if Dominio = 'STRING' then begin
        try
          Tamanho := valint(Campo.Attributes['tamanho']);
        except
          Tamanho := 40;
        end;
        try
          Tamanhovisivel := valint(Campo.Attributes['tamanhovisivel']);
        except
          Tamanhovisivel := 40;
        end;
        inc(QtdCampos);
        valor := Dados.Readval(Campo.NodeName);
        MetaDados.addcampostring(Campo.nodename,valor,
                                 Campo.Attributes['titulo'],
                                 Tamanho,
                                 TamanhoVisivel,
                                 qtdCampos,true,
                                 Campo.NodeName,
                                 uppercase(Campo.Attributes['aceitaFaixa']) = 'T',
                                 uppercase(Campo.Attributes['obrigatorio']) = 'T');
      end
      else if Dominio = 'DATA' then begin
        inc(QtdCampos);
        data := Dados.Readdata(Campo.NodeName);
        MetaDados.addcampoData(Campo.nodename,data,
                               Campo.Attributes['titulo'],QtdCampos,
                               true,
                               Campo.NodeName,
                               uppercase(Campo.Attributes['aceitaFaixa']) = 'T',
                               uppercase(Campo.Attributes['obrigatorio']) = 'T');
      end
      else if Dominio = 'INTEGER' then begin
        if Campo.Attributes['digitos'] > '' then
          digitos := valint(Campo.Attributes['digitos'])
        else
          digitos := 5;
        inc(QtdCampos);
        valorint := Dados.Readint(Campo.NodeName);
        MetaDados.addcampointeger(Campo.nodename,valorint,
                                  digitos,
                                  Campo.Attributes['titulo'],
                                  QtdCampos,true,
                                  Campo.NodeName,
                                  uppercase(Campo.Attributes['aceitaFaixa']) = 'T');
      end
      else if Dominio = 'ORDEM' then begin
        inc(QtdCampos);
        valor := Dados.ReadVal(Campo.NodeName);
        DescSt := TStringlist.create;
        ValSt  := Tstringlist.create;
        try
          for j := 0 to MaxOrdem do begin
            ValSt.add(NomeOrdem[j]);
            DescSt.add(NomeOrdem[j]);
          end;
          MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                  Campo.Attributes['titulo'],
                                  QtdCampos,true,'',
                                  uppercase(Campo.Attributes['obrigatorio']) = 'T');
        finally
          DescSt.free;
          ValSt.free;
        end;
      end
      else if Dominio = 'MESANO' then begin
        inc(QtdCampos);
        MA := Dados.ReadMA(Campo.NodeName);
        MetaDados.addcampoMesAno(Campo.nodename,MA,
                                 Campo.Attributes['titulo'],QtdCampos,true,
                                 Campo.NodeName,
                                 uppercase(Campo.Attributes['aceitaFaixa']) = 'T',
                                 uppercase(Campo.Attributes['obrigatorio']) = 'T');
      end
      else if (Dominio = 'CTR') or (Dominio = 'CTRVELHO') then begin
        inc(QtdCampos);
        valor := Dados.Readval(Campo.NodeName);
        if trim(Campo.Attributes['base']) > '' then
          Base := trim(Campo.Attributes['base'])
        else
          Base := 'ATV';
        MetaDados.addcampoctr(Campo.nodename,valor,
                              Campo.Attributes['titulo'],
                              15,
                              15,
                              qtdCampos,true,
                              Base,
                              Campo.NodeName,
                              uppercase(Campo.Attributes['aceitaFaixa']) = 'T',
                              uppercase(Campo.Attributes['obrigatorio']) = 'T');
      end
      else if Dominio = 'TMORA' then begin
        inc(QtdCampos);
        valor := Dados.ReadVal(Campo.NodeName);
        DescSt := TStringlist.create;
        ValSt  := Tstringlist.create;
        try
          for j := 1 to MaxTMora do begin
            ValSt.add(trim(palavra(TipoMoraStr[j],1,'-',#255,#255)));
            DescSt.add(TipoMoraStr[j]);
          end;
          MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                  Campo.Attributes['titulo'],
                                  QtdCampos,true,'',
                                  uppercase(Campo.Attributes['obrigatorio']) = 'T');
        finally
          DescSt.free;
          ValSt.free;
        end;
      end
      else if Dominio = 'MOEDA' then begin
        inc(QtdCampos);
        valorreal := Dados.Readreal(Campo.NodeName);
        MetaDados.addcamporeal(Campo.nodename,valorreal,
                               16,
                               2,
                               Campo.Attributes['titulo'],
                               QtdCampos,true,
                               Campo.NodeName,
                               uppercase(Campo.Attributes['aceitaFaixa']) = 'T');
      end
      else if Dominio = 'REAL' then begin
        if Campo.Attributes['digitos'] > '' then
          digitos := valint(Campo.Attributes['digitos'])
        else
          digitos := 12;
        if Campo.Attributes['decimais'] > '' then
          decimais := valint(Campo.Attributes['decimais'])
        else
          decimais := 6;
        inc(QtdCampos);
        valorreal := Dados.Readreal(Campo.NodeName);
        MetaDados.addcamporeal(Campo.nodename,valorreal,
                               digitos,
                               decimais,
                               Campo.Attributes['titulo'],
                               QtdCampos,true,
                               Campo.NodeName,
                               uppercase(Campo.Attributes['aceitaFaixa']) = 'T');
      end
      else if Dominio = 'BOOLEAN' then begin
        inc(QtdCampos);
        bool := Dados.Readbool(Campo.NodeName);
        MetaDados.addcampoboolean(Campo.nodename,bool,
                                  Campo.Attributes['titulo'],QtdCampos,true);
      end
      else if Dominio = 'PLANO' then begin
        inc(QtdCampos);
        valor := Dados.ReadVal(Campo.NodeName);
        DescSt := TStringlist.create;
        ValSt  := Tstringlist.create;
        try
          DescSt.add('PES'); ValSt.add('1');
          DescSt.add('PET'); ValSt.add('2');
          DescSt.Add('HIP'); ValSt.Add('3');
          MetaDados.AddcampoCombo(Campo.NodeName,ValSt.indexof(valor),DescSt,ValSt,
                                  Campo.Attributes['titulo'],
                                  QtdCampos,true,'',
                                  uppercase(Campo.Attributes['obrigatorio']) = 'T');
        finally
          DescSt.free;
          ValSt.free;
        end;
      end
      else if copy(Dominio,1,4) = 'XDB:' then begin
        inc(QtdCampos);
        valor := Dados.ReadVal(Campo.NodeName);
        TrataCampoXdb(Campo,Valor,Campo.Attributes['Dominio'],QtdCampos,Metadados,Campo.Attributes['VALORNADESCRICAO']='T');
      end
      else if UpperCase(Dominio) = 'MUNICIPIOPELOUFDAEMPRESA' then begin
        inc(QtdCampos);
        valor := Dados.ReadVal(Campo.NodeName);
        TrataMunicipioPeloUFDaEmpresa(Campo,Valor,Campo.Attributes['Dominio'],QtdCampos,Metadados,Campo.Attributes['VALORNADESCRICAO']='T');
      end
      else if (copy(Dominio,1,4) = 'SQL:') and assigned(FSqlConnection) then begin
        inc(QtdCampos);
        valor := Dados.ReadVal(Campo.NodeName);
        TrataCampoSql(Campo,Valor,Campo.Attributes['Dominio'],QtdCampos,Metadados);
      end
      else if Dominio = 'COMBOBOX' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataCampoCombo(Campo,Valor,QtdCampos,MetaDados);
      end
      else if Dominio = 'OPCAOPELOTIPO' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataCampoOpcaoPeloTipo(Campo,valor,Campo.Attributes['Dominio'],QtdCampos,MetaDados);
      end
      else if Dominio = 'CLASSE' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataCampoClasse(Campo,valor,QtdCampos,MetaDados);
      end
      else if Dominio = 'TIPOFCVS' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataComboTipoFCVS(Campo,valor,QtdCampos,MetaDados);
      end
      else if Dominio = 'TIPOCTR' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataComboTpCtr(Campo,valor,QtdCampos,MetaDados);
      end  else if Dominio = 'ARQCTR' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataCampoArqCtr(Campo,valor,QtdCampos,MetaDados);
      end  else if Dominio = 'CARTEIRA' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataComboCarteira(Campo,valor,QtdCampos,MetaDados);
      end else if Dominio = 'CLASSIFICACAOSERIE' then begin
        inc(QtdCampos);
        valor := Dados.readval(Campo.NodeName);
        TrataComboClassificacaoSerie(Campo,valor,QtdCampos,MetaDados);
      end else if Dominio = 'UF' then begin
        inc(Qtdcampos);
        valor := Dados.readval(Campo.NodeName);
        TrataCampoUF(campo,valor,QtdCampos,Metadados);
      end
      else
        raise exception.create('Domínio '+Dominio+' não suportado.');
    end;
    result := true;
  end
  else 
    result := false;
end;


procedure TRelatorioGenerico.ValidaParametros(Dados : TpMemory);
  procedure ValidaCtr (Dados : TpMemory; 
                       Base, NomeCampo : String; VerificaSeExiste : boolean;
                       ValorDefault : string; TipoDominio : string);
  var
    valor : string;
  begin
    if trim(Dados.Readval(NomeCampo)) = '' then
      valor := ValorDefault
    else begin
      if (uppercase(Base) = 'ATV') or (trim(Base) = '') then
        Le_Arq_Fis
      else if Uppercase(Base) = 'SIM' then
        Le_Arq_Sim
      else if Uppercase(Base) = 'FIN' then
        Le_Arq_Fin
      else begin
        base := 'SCCIDIRATV='+base;
        SetcEnv(base);
        Le_Arq_Fis;
      end;
      Abre_Cad;
      try
        if VerificaSeExiste then
          valor := StrToCtrExistente(FSqlConnection,Dados.Readval(NomeCampo))
        else
          if TipoDominio='CTRVELHO' then
            valor := StrToCtrVelho(Dados.Readval(NomeCampo))
          else
            valor := StrToCtr(Dados.Readval(NomeCampo));
      finally
        Fecha_Cad;
      end;
    end;
    Dados.Addval(NomeCampo,valor);
  end;
var
  Campo,
  XmlTela : TpXmlNode; 
  i : integer;
  Dominio : string;
  Idtela : integer;
  UsouArquivoDeContratos : boolean;
  ValorDefault : string;
begin
  UsouArquivoDeContratos := false;
  IdTela := 1;
  XmlTela := FXml.DocumentElement['interface'+inttostr(IdTela)];
  while assigned(XmlTela) do begin
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      Dominio := uppercase(Campo.Attributes['Dominio']);
      if Dominio = 'ARQCTR' then
        UsouArquivoDeContratos := trim(Dados.Readval(Campo.NodeName)) > '';
    end;
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      Dominio := uppercase(Campo.Attributes['Dominio']);
      if ((Dominio = 'CTR') or (Dominio = 'CTRVELHO')) and not UsouArquivoDeContratos then begin
        if Campo.Attributes['AceitaFaixa'] = 'T' then begin

          ValorDefault := palavra(Campo.Attributes['Default'],1,';',#255,#255);
          ValidaCtr (Dados, Campo.Attributes['Base'], Campo.NodeName+'1',false,ValorDefault,Dominio);
          
          ValorDefault := palavra(Campo.Attributes['Default'],2,';',#255,#255);
          ValidaCtr (Dados, Campo.Attributes['Base'], Campo.NodeName+'2',false,ValorDefault,Dominio);

        end
        else begin

          Valordefault := Campo.Attributes['Default'];
          ValidaCtr (Dados, Campo.Attributes['Base'], Campo.NodeName,true,ValorDefault,Dominio);

        end;
      end;
    end;
    inc(IdTela);
    XmlTela := FXml.DocumentElement['interface'+inttostr(IdTela)];
  end;
end;

procedure TRelatorioGenerico.ValidaParametros(Dados : TpXmlNode);
  procedure ValidaCtr (Dados : TpXmlNode; 
                       Base, NomeCampo : String; VerificaSeExiste : boolean;
                       ValorDefault : string; TipoDominio : string);
  var
    valor : string;
  begin
    if trim(Dados[NomeCampo].AsString) = '' then
      valor := ValorDefault
    else begin
      if (uppercase(Base) = 'ATV') or (trim(Base) = '') then
        Le_Arq_Fis
      else if Uppercase(Base) = 'SIM' then
        Le_Arq_Sim
      else if Uppercase(Base) = 'FIN' then
        Le_Arq_Fin
      else begin
        base := 'SCCIDIRATV='+base;
        SetcEnv(base);
        Le_Arq_Fis;
      end;
      Abre_Cad;
      try
        if VerificaSeExiste then
          valor := StrToCtrExistente(FSqlConnection,Dados[NomeCampo].AsString)
        else
          if TipoDominio='CTRVELHO' then
            valor := StrToCtrVelho(Dados[NomeCampo].AsString)
          else
            valor := StrToCtr(Dados[NomeCampo].AsString);
      finally
        Fecha_Cad;
      end;
    end;
    Dados.Add(NomeCampo).AsString := valor;
  end;
var
  Campo,
  XmlTela : TpXmlNode; 
  i : integer;
  Dominio : string;
  Idtela : integer;
  UsouArquivoDeContratos : boolean;
  ValorDefault : string;
begin
  UsouArquivoDeContratos := false;
  IdTela := 1;
  XmlTela := FXml.DocumentElement['interface'+inttostr(IdTela)];
  while assigned(XmlTela) do begin
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      Dominio := uppercase(Campo.Attributes['Dominio']);
      if Dominio = 'ARQCTR' then
        UsouArquivoDeContratos := trim(Dados[Campo.NodeName].AsString) > '';
    end;
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      Dominio := uppercase(Campo.Attributes['Dominio']);
      if ((Dominio = 'CTR') or (Dominio = 'CTRVELHO')) and not UsouArquivoDeContratos then begin
        if Campo.Attributes['AceitaFaixa'] = 'T' then begin

          ValorDefault := palavra(Campo.Attributes['Default'],1,';',#255,#255);
          ValidaCtr (Dados, Campo.Attributes['Base'], Campo.NodeName+'1',false,ValorDefault,Dominio);
          
          ValorDefault := palavra(Campo.Attributes['Default'],2,';',#255,#255);
          ValidaCtr (Dados, Campo.Attributes['Base'], Campo.NodeName+'2',false,ValorDefault,Dominio);

        end
        else begin

          Valordefault := Campo.Attributes['Default'];
          ValidaCtr (Dados, Campo.Attributes['Base'], Campo.NodeName,true,ValorDefault,Dominio);

        end;
      end;
    end;
    inc(IdTela);
    XmlTela := FXml.DocumentElement['interface'+inttostr(IdTela)];
  end;
end;


procedure ExecutaShell(RegistraExecucao : boolean;
                       Usuario : string;
                       ID : longint;
                       Inicio : tdatetime; 
                       Nome : String; Cmd : ansistring;
                       titulo : string;
                       co_sistema : ansistring = 'R';
                       co_modulo : integer = 0);
var
  NomeTempErr : string;
  Erros : Tstringlist;
  Qry : TSqlQuery;
  pid : integer;
{$IFDEF LINUX}
  Stream : TmemoryStream;
  ErrorCode : integer;
{$ENDIF}
begin
  pid := Getpid;
{$IFDEF LINUX}
{$IFDEF FPC}
  fpSetpgid(0,pid);
{$ELSE}
  setpgid(0,pid);
{$ENDIF}
{$ENDIF}
    Qry := TSqlQuery.create(nil);
    Erros := TStringList.create;
    try
      if RegistraExecucao then begin
        Qry.SqlConnection := GetSqlConnection(getenv('SCCIDIRATV'));
        Qry.Sql.clear;                             
        Qry.Sql.add('INSERT INTO ANDAMENTO_RELATORIO');
        Qry.Sql.add('(USUARIO,ID,RELATORIO,INICIO,DIRETORIO,PID,TITULO,CO_SISTEMA,CO_MODULO) VALUES');
        Qry.Sql.add('(:USUARIO,:ID,:RELATORIO,:INICIO,:DIRETORIO,:PID,:TITULO,:CO_SISTEMA,:CO_MODULO)');
        Qry.ParamByName('ID').asinteger := ID;
        Qry.ParamByName('USUARIO').asstring := Usuario;
        Qry.ParamByname('RELATORIO').asstring := Nome;
        Qry.ParamByname('INICIO').asSqlTimeStamp := DateTimeToSqlTimeStamp(Inicio);
        Qry.ParamByName('DIRETORIO').asstring := GetCurrentDir;
        Qry.ParamByName('PID').asinteger := pid;
        Qry.paramByname('TITULO').asstring := titulo;
        Qry.ParamByName('CO_SISTEMA').asstring := co_sistema;
        Qry.paramByname('CO_MODULO').asinteger := co_modulo;
        Qry.ExecSql;
      end;
{$IFDEF MSWINDOWS}
      if RegistraExecucao then 
        shell_nowait('execrel '+inttostr(ID)+' '+usuario+' '+cmd)
      else begin
        TempNam(NomeTempErr);
        shell_nowait(Cmd + ' 2> '+NomeTempErr);
	    Erros.loadfromfile(NomeTempErr);
	    try
  	      DeleteFile(NomeTempErr);
        except      end;
        if Erros.count > 0 then begin
            raise exception.create(Erros.text);
        end;
	  end;
{$ELSE}
      TempNam(NomeTempErr);
      shell(Cmd + ' 2> '+NomeTempErr);
	  Erros.loadfromfile(NomeTempErr);
	  try
  	    DeleteFile(NomeTempErr);
      except      end;
      if Erros.count > 0 then begin
        if not RegistraExecucao then
          raise exception.create(Erros.text);
      end;
      if (ShellExitCode = 0) and (Erros.Count > 0) then
        ErrorCode := 200
      else
        ErrorCode := ShellExitCode;
      if RegistraExecucao then begin
        Qry.Sql.clear;
        Qry.Sql.add('UPDATE ANDAMENTO_RELATORIO SET');
        Qry.Sql.add('  FIM = :FIM,');
        Qry.Sql.add('  EXITCODE = :EXITCODE,');
        Qry.Sql.add('  ERRO = :ERRO');                   
        Qry.Sql.add('WHERE (USUARIO = :USUARIO) AND (ID = :ID) ');
        Qry.ParamByName('USUARIO').asstring := Usuario;
        Qry.ParamByName('ID').asinteger := ID;
        Qry.ParamByname('FIM').asSQLTimeStamp := DateTimeToSqlTimeStamp(Now);
        Qry.ParamByName('EXITCODE').asinteger := ErrorCode;
        Stream := Tmemorystream.create;
        try
          Erros.SaveToStream(Stream);
          if Stream.size > 0 then begin
            Stream.Position := 0;
//            if uppercase(SqlConnection.DriverName) = 'OPENODBC' then 
//              Qry.ParamByName('ERRO').loadfromstream(Stream,ftMemo)
//            else
// Trocado para image e fica compativel
              Qry.ParamByName('ERRO').loadfromstream(Stream,ftBlob);
          end
          else begin
//            if uppercase(SqlConnection.DriverName) = 'OPENODBC' then 
//              Qry.ParamByname('ERRO').datatype := ftMemo
//            else
              Qry.ParamByname('ERRO').datatype := ftblob;
            Qry.ParamByName('ERRO').clear;
          end;
        finally
          Stream.free;
        end;
        Qry.ExecSql;
      end;
{$ENDIF}
    finally
      Erros.free;
      Qry.free;
    end;
end;

constructor TRelatorioGenericoTexto.create;
begin
  FSqlConnection := nil;
  FSaidas := Tstringlist.create;
end;

destructor TRelatorioGenericoTexto.destroy;
begin
  FSaidas.free;
  inherited;
end;

procedure TRelatorioGenericoTexto.MontaShell(Var Cmd : ansistring; Parms : TpMemory);
var
  token,
  valor : string;
begin
  while pos('#',cmd) > 0 do begin
    token := cmd;
    delete(token,1,pos('#',cmd));
    if pos(' ',token) > 0 then
      token := copy(token,1,pos(' ',token)-1);
    valor := stringreplace(Parms.readval(token),'#',' ',[rfReplaceAll]);
    cmd := stringreplace(cmd,'#'+token,valor,
                         [rfReplaceAll,rfIgnoreCase]);
  end;
end;

procedure TRelatorioGenericoTexto.MontaShell(Var Cmd : ansistring; Parms : TpXmlNode);
var
  token,
  valor : string;
begin
  while pos('#',cmd) > 0 do begin
    token := cmd;
    delete(token,1,pos('#',cmd));
    if pos(' ',token) > 0 then
      token := copy(token,1,pos(' ',token)-1);
    if (token='classe') then
      valor := stringreplace(Parms['DISPLAY_'+token].AsString,'#',' ',[rfReplaceAll])
    else
      valor := stringreplace(Parms[token].AsString,'#',' ',[rfReplaceAll]);
    cmd := stringreplace(cmd,'#'+token,valor,
                         [rfReplaceAll,rfIgnoreCase]);
  end;
end;


procedure TRelatorioGenericoTexto.GeraArquivos(RelatGen : TRelatorioGenerico; Dados : TpMemory);
var
  Campo,
  XmlTela : TpXmlNode;
  i : integer;
  Lista : Tstringlist;
begin
  XmlTela := RelatGen.Xml.DocumentElement['interface1'];
  if assigned(XmlTela) then
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      if (campo.Attributes['UsaEditaLista'] = 'T') and (Campo.Attributes['NomeArqLista'] > '') then begin
        Lista := Tstringlist.create;
        try
          Dados.readstrings('_LISTA_'+Campo.NodeName,Lista);
          Lista.savetofile(Campo.Attributes['NomeArqLista']);
        finally
          Lista.free;
        end;
      end;
    end;
end;

procedure TRelatorioGenericoTexto.GeraArquivos(RelatGen : TRelatorioGenerico; Dados : TpXmlNode);
var
  Campo,
  XmlTela : TpXmlNode;
  i,j : integer;
  Lista : Tstringlist;
  Dominio  : String;
begin
  XmlTela := RelatGen.Xml.DocumentElement['interface1'];
  if assigned(XmlTela) then
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      if (campo.Attributes['UsaEditaLista'] = 'T') and (Campo.Attributes['NomeArqLista'] > '') then begin
        Lista := Tstringlist.create;
        try
          if pos(':', Campo.Attributes['dominio']) > 0 then begin
            Dominio := Campo.Attributes['dominio'];
            Dominio := copy(Dominio,pos(':', Dominio)+1,Length(Dominio));
            for j := 0 to Dados.Count -1 do begin
              if (pos(Dominio, Dados[j].NodeName) > 0) and (pos('COD', Dados[j].NodeName) > 0) and (pos('DISPLAY', Dados[j].NodeName) <= 0) then
                Lista.add(Dados[j].AsString);
            end;
          end else begin
            for j := 0 to Dados['_LISTA_'+Campo.NodeName].Count -1 do
              Lista.add(Dados['_LISTA_'+Campo.NodeName][j].AsString);
          end;
          Lista.savetofile(Campo.Attributes['NomeArqLista']);
        finally
          Lista.free;
        end;
      end;
    end;
end;


procedure TRelatorioGenericoTexto.ConverteNulos(RelatGen : TRelatorioGenerico; Dados : TpMemory);
var
  Campo,
  XmlTela : TpXmlNode;
  i : integer;
begin
  XmlTela := RelatGen.Xml.DocumentElement['interface1'];
  if assigned(XmlTela) then
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      if (trim(campo.Attributes['Nulo']) > '') and (trim(Dados.readval(Campo.NodeName)) = '') then
        Dados.addval(Campo.NodeName,campo.Attributes['Nulo']);
    end;
end;

procedure TRelatorioGenericoTexto.ConverteNulos(RelatGen : TRelatorioGenerico; Dados : TpXmlNode);
var
  Campo,
  XmlTela : TpXmlNode;
  i : integer;
begin
  XmlTela := RelatGen.Xml.DocumentElement['interface1'];
  if assigned(XmlTela) then
    for i := 0 to XmlTela.count - 1 do begin
      Campo := XmlTela[i];
      if (trim(campo.Attributes['Nulo']) > '') and (trim(Dados[Campo.NodeName].AsString) = '') then
        Dados.add(Campo.NodeName).AsString := campo.Attributes['Nulo'];
    end;
end;


function TRelatorioGenericoTexto.Execute(Usuario : string; RelatGen : TRelatorioGenerico; 
                                         Dados : TpMemory; 
                                         Var Spool : ansistring;
                                         Espera : boolean) : longint;
var
  i : integer;
  Cmd : ansistring;
{$IFDEF LINUX}
  pid : integer;
{$ENDIF}
  Inicio : TDateTime;
begin
  FSaidas.clear;
  if not Assigned(FSqlConnection) then
    raise exception.create('Base de dados não configurada');
  Inicio := Now;
  Spool := GetEnv('SCCIDIRATV')+PathDelim+'spool'+PathDelim+Usuario+PathDelim+
           RelatGen.Nome+FormatDateTime('yyyymmddhhnnzzz',Inicio);
  if not ForceDirectories(Spool) then
    raise exception.create('Não foi possível criar spool('+spool+')');
  if not SetCurrentDir(Spool) then
    raise exception.create('Não foi possível acessar o spool('+spool+')');
  if RelatGen.TipoRelat = tipoRelat_Texto then begin
    FComando := RelatGen.Xml.DocumentElement['comando'].nodevalue;
    for i := 0 to RelatGen.SaidasXml.Count - 1 do
      if uppercase(RelatGen.SaidasXml[i].NodeName) = 'ARQUIVO' then
        FSaidas.add(RelatGen.SaidasXml[i].attributes['Titulo']+'='+
                    GetCurrentDir + PathDelim + RelatGen.SaidasXml[i].Attributes['nome']);
    Cmd := FComando;
    GeraArquivos(RelatGen,Dados);
    ConverteNulos(RelatGen,Dados);
    MontaShell(Cmd,Dados);
    if not Espera then
      result := LeGenerator(FSqlConnection,'GEN_ID_ANDAMENTO_RELATORIO')
    else
      result := -1;
    if Espera then
      ExecutaShell(false,Usuario,result,Inicio,RelatGen.Nome,Cmd,RelatGen.TituloUsuario(Dados))
    else begin
	  {$IFDEF LINUX}
      LiberaSqlConnections;
{$IFDEF FPC}
      pid := fpfork();
{$ELSE}
      pid := fork();
{$ENDIF}
      if pid = 0 then begin
        ExecutaShell(true,Usuario,result,Inicio,RelatGen.Nome,Cmd,RelatGen.TituloUsuario(dados)); // filho
        Halt(0);
      end;
	  {$ELSE}
	  ExecutaShell(true,Usuario,result,Inicio,RelatGen.Nome,Cmd,RelatGen.TituloUsuario(dados));
	  {$ENDIF}       
    end;
  end
  else
    raise exception.create('Tipo de relatório não suportado.');
end;

function TRelatorioGenericoTexto.Execute(Usuario : string; RelatGen : TRelatorioGenerico; 
                                         Dados : TpXmlNode; 
                                         Var Spool : ansistring;
                                         Espera : boolean) : longint;
var
  i : integer;
  Cmd : ansistring;
  sistema: ansistring;
  modulo: integer;
{$IFDEF LINUX}
  pid : integer;
{$ENDIF}
  Inicio : TDateTime;
begin
  FSaidas.clear;
  if not Assigned(FSqlConnection) then
    raise exception.create('Base de dados não configurada');
  sistema := 'R';
  modulo := 0;
  Inicio := Now;
  Spool := GetEnv('SCCIDIRATV')+PathDelim+'spool'+PathDelim+Usuario+PathDelim+
           RelatGen.Nome+FormatDateTime('yyyymmddhhnnzzz',Inicio);
  if assigned(Dados['sistema']) then
    sistema := Dados['sistema'].asString;
  if assigned(Dados['MODULO']) then
    modulo := Dados['MODULO'].asInteger;
  if not ForceDirectories(Spool) then
    raise exception.create('Não foi possível criar spool('+spool+')');
  if not SetCurrentDir(Spool) then
    raise exception.create('Não foi possível acessar o spool('+spool+')');
  if RelatGen.TipoRelat = tipoRelat_Texto then begin
    FComando := RelatGen.Xml.DocumentElement['comando'].nodevalue;
    for i := 0 to RelatGen.SaidasXml.Count - 1 do
      if uppercase(RelatGen.SaidasXml[i].NodeName) = 'ARQUIVO' then
        FSaidas.add(RelatGen.SaidasXml[i].attributes['Titulo']+'='+
                    GetCurrentDir + PathDelim + RelatGen.SaidasXml[i].Attributes['nome']);
    Cmd := FComando;
    GeraArquivos(RelatGen,Dados);
    ConverteNulos(RelatGen,Dados);
    MontaShell(Cmd,Dados);
    if not Espera then
      result := LeGenerator(FSqlConnection,'GEN_ID_ANDAMENTO_RELATORIO')
    else
      result := -1;
    if Espera then
      ExecutaShell(false,Usuario,result,Inicio,RelatGen.Nome,Cmd,RelatGen.TituloUsuario(Dados),sistema,modulo)
    else begin
	  {$IFDEF LINUX}
      LiberaSqlConnections;
{$IFDEF FPC}
      pid := fpfork();
{$ELSE}    
      pid := fork();
{$ENDIF}
      if pid = 0 then begin
        ExecutaShell(true,Usuario,result,Inicio,RelatGen.Nome,Cmd,RelatGen.TituloUsuario(dados),sistema,modulo); // filho
        Halt(0);
      end;
	  {$ELSE}
	  ExecutaShell(true,Usuario,result,Inicio,RelatGen.Nome,Cmd,RelatGen.TituloUsuario(dados),sistema,modulo);
	  {$ENDIF}       
    end;
  end
  else
    raise exception.create('Tipo de relatório não suportado.');
end;

function InsereExecucaoRelatorio(Pid : integer;
                                 Nome,
                                 Diretorio : String;
                                 titulo : string;
                                 co_sistema : ansistring = 'R';
                                 co_modulo : integer = 0):integer;
var
  Id : integer;
  Qry : TSqlQuery;
begin
  Id := 0;
  Qry := TSqlQuery.create(nil);
  try
    Id := LeGenerator(GetSqlConnection(PegaDirTab),'GEN_ID_ANDAMENTO_RELATORIO');
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.Sql.add('INSERT INTO ANDAMENTO_RELATORIO');
    Qry.Sql.add('(USUARIO,ID,RELATORIO,INICIO,DIRETORIO,PID,TITULO,CO_SISTEMA,CO_MODULO) VALUES');
    Qry.Sql.add('(:USUARIO,:ID,:RELATORIO,:INICIO,:DIRETORIO,:PID,:TITULO,:CO_SISTEMA,:CO_MODULO)');
    Qry.ParamByName('ID').DataType := ftinteger;
    Qry.ParamByName('USUARIO').DataType := ftString;
    Qry.ParamByname('RELATORIO').DataType := ftString;
    Qry.ParamByname('INICIO').DataType := ftDateTime;
    Qry.ParamByName('DIRETORIO').DataType := ftString;
    Qry.ParamByName('PID').DataType := ftinteger;
    Qry.paramByname('TITULO').DataType := ftString;
    Qry.ParamByName('CO_SISTEMA').DataType := ftString;
    Qry.paramByname('CO_MODULO').DataType := ftinteger;
    
    Qry.ParamByName('ID').asinteger := Id;
    Qry.ParamByName('USUARIO').asstring := PegaUsuario;
    Qry.ParamByname('RELATORIO').asstring := Nome;
    Qry.ParamByname('INICIO').asSqlTimeStamp := DateTimeToSqlTimeStamp(now);
    Qry.ParamByName('DIRETORIO').asstring := Diretorio;
    Qry.ParamByName('PID').asinteger := pid;
    Qry.paramByname('TITULO').asstring := titulo;
    Qry.ParamByName('CO_SISTEMA').asstring := co_sistema;
    Qry.paramByname('CO_MODULO').asinteger := co_modulo;
    Qry.ExecSql;
  finally
    Qry.free;
  end;
  Result := Id;
end;  

procedure AtualizaExecucaoRelatorio(Id,
                                    ErroCode : integer;
                                    Diretorio : String;
                                    titulo : string;
                                    Erro : Ansistring);
var
  NomeTempErr : string;
  Qry : TSqlQuery;
begin
    Qry := TSqlQuery.create(nil);
	  try
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.Sql.add('UPDATE ANDAMENTO_RELATORIO SET');
      Qry.sql.add('  DIRETORIO = :DIR,');
      Qry.Sql.add('  FIM = :FIM,');
      Qry.Sql.add('  EXITCODE = :EXITCODE,');
      Qry.Sql.add('  ERRO = :ERRO');                   
      Qry.Sql.add('WHERE (USUARIO = :USUARIO) AND (ID = :ID) ');
      Qry.ParamByName('USUARIO').DataType := ftString;
      Qry.ParamByName('ID').DataType := ftInteger;
      Qry.ParamByname('DIR').DataType := ftString;
      Qry.ParamByname('FIM').DataType := ftDateTime;
      Qry.ParamByName('EXITCODE').DataType := ftInteger;
      Qry.ParamByName('ERRO').DataType := ftBlob;

      Qry.ParamByName('USUARIO').asstring := Pegausuario;
      Qry.ParamByName('ID').asinteger := Id;
      Qry.ParamByname('DIR').AsString := Diretorio;
      Qry.ParamByname('FIM').asSQLTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ParamByName('EXITCODE').asinteger := ErroCode;
      Qry.paramByName('ERRO').asBlob := bytesof(Erro);
      Qry.ExecSql;
    finally
      Qry.free;
    end;
end;

procedure GetBuscaExecucaoRelatorio(JsonIn,JsonOut:TpXml);
var
  Qry : TSqlQuery;
  Ids,
  Relatorios,
  Titulos,
  AndamentoRel,
  Dados : TpXmlNode;
  usuario: String;
  i : integer;
begin
  Qry        := TSqlQuery.create(nil);
  Dados      := JsonOut.addOrGet('dados');
  Ids        := JsonIn.addOrGet('IDS');
  Relatorios := JsonIn.addOrGet('RELATORIOS');
  Titulos    := JsonIn.addOrGet('TITULOS');

  if assigned(jsonIn['USUARIO']) and (jsonIn['USUARIO'].asString <> '') then
    usuario := jsonIn['USUARIO'].asString
  else
    usuario := Pegausuario;
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.Sql.add('SELECT * FROM ANDAMENTO_RELATORIO');
    Qry.Sql.add('WHERE USUARIO=:USUARIO');
    Qry.ParamByName('USUARIO').asString := usuario;
    if IDs.count = 1 then begin
      Qry.Sql.add('AND ID =:ID');
      Qry.ParamByName('ID').asString := IDs[0].asString;
    end
    else
    if IDs.count > 1 then begin
      Qry.Sql.add('AND ID IN('); 
        for i := 0 to IDs.count -1 do begin
          if i = 0 then
            Qry.Sql.add(':ID'+intToStr(i))
          else
            Qry.Sql.add(',:ID'+intToStr(i));
            Qry.ParamByName('ID'+intToStr(i)).asInteger := IDs[i].asInteger;
    end;
      Qry.Sql.add(')');
    end;

    if Relatorios.count = 1 then begin
      Qry.Sql.add('AND RELATORIO =:RELATORIO');
      Qry.ParamByName('RELATORIO').asString := Relatorios[0].asString;
    end
    else
    if Relatorios.count > 1 then begin
      Qry.Sql.add('AND RELATORIO IN('); 
        for i := 0 to Relatorios.count -1 do begin
          if i = 0 then
            Qry.Sql.add(':RELATORIO'+intToStr(i))
          else
            Qry.Sql.add(',:RELATORIO'+intToStr(i));
            Qry.ParamByName('RELATORIO'+intToStr(i)).asString := Relatorios[i].asString;
    end;
      Qry.Sql.add(')');
    end;

    if Titulos.count = 1 then begin
      Qry.Sql.add('AND TITULO =:TITULO');
      Qry.ParamByName('TITULO').asString := Titulos[0].asString;
    end
    else
    if Titulos.count > 1 then begin
      Qry.Sql.add('AND TITULO IN('); 
        for i := 0 to Titulos.count -1 do begin
          if i = 0 then
            Qry.Sql.add(':TITULO'+intToStr(i))
          else
            Qry.Sql.add(',:TITULO'+intToStr(i));
            Qry.ParamByName('TITULO'+intToStr(i)).asString := Titulos[i].asString;
    end;
      Qry.Sql.add(')');
    end;
    Qry.open;
    while not qry.eof do begin
      AndamentoRel := Dados.add('GRID_ANDAMENTO_RELATORIO');
      AndamentoRel.add('ID').asInteger := Qry.Fieldbyname('ID').asInteger;
      AndamentoRel.add('USUARIO').AsString := Qry.Fieldbyname('USUARIO').asstring;
      AndamentoRel.add('RELATORIO').AsString := Qry.Fieldbyname('RELATORIO').asstring;
      AndamentoRel.add('DIRETORIO').AsString := Qry.Fieldbyname('DIRETORIO').asstring;
      if not Qry.fieldbyname('INICIO').isNull then
        AndamentoRel.add('INICIO').asString := FormatDateTime('DD/MM/YYYY HH:MM:SS',Qry.fieldbyname('INICIO').asDateTime)
      else
        AndamentoRel.add('INICIO').asString := '';
      if not Qry.fieldbyname('FIM').isNull then
        AndamentoRel.add('FIM').asString := FormatDateTime('DD/MM/YYYY HH:MM:SS',Qry.fieldbyname('FIM').asDateTime)
      else
        AndamentoRel.add('FIM').asString := '';
      AndamentoRel.add('ERRO').asString := Qry.Fieldbyname('ERRO').asString;
      AndamentoRel.add('EXITCODE').asInteger := Qry.Fieldbyname('EXITCODE').asInteger;
      AndamentoRel.add('PID').asInteger := Qry.Fieldbyname('PID').asInteger;
      AndamentoRel.add('TITULO').asString := Qry.Fieldbyname('TITULO').asString;
      AndamentoRel.add('CO_SISTEMA').asString := Qry.Fieldbyname('CO_SISTEMA').asString;
      AndamentoRel.add('CO_MODULO').asInteger := Qry.Fieldbyname('CO_MODULO').asInteger;
      AndamentoRel.add('DETALHES').asString := Qry.Fieldbyname('DETALHES').asString;
      Qry.next;
    end;
  finally
    Qry.free;
  end;
  JsonOut.addOrGet('success').asBoolean := true;
end;

procedure VerificaExecAndamentoPorUsuario(CoSistema,Titulo,Erro : String; CoModulo : Integer);
var
  NomeTempErr : string;
  Qry : TSqlQuery;
begin
    Qry := TSqlQuery.create(nil);
	  try
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.Sql.add('SELECT * FROM ANDAMENTO_RELATORIO');
      Qry.sql.add('WHERE USUARIO=:Usuario AND CO_SISTEMA=:CoSistema AND CO_MODULO=:CoModulo AND TITULO=:Titulo');
      Qry.ParamByName('Usuario').asstring := PegaUsuario;
      Qry.ParamByname('CoSistema').AsString := CoSistema;
      Qry.ParamByName('CoModulo').asinteger := CoModulo;
      Qry.ParamByname('Titulo').AsString := Titulo;
      Qry.Open;
      while not Qry.Eof do begin
        if Qry.FieldByName('Fim').isNull then
          raise exception.create(Erro);
        Qry.next;
      end;
      Qry.Close;
    finally
      Qry.free;
    end;
end;

end.
