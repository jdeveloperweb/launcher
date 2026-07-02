unit  wsistarqlib;

{$V+}
{$H-}
interface

uses
  Classes, SysUtils,lib1, scislib, aelib, pxmllib, pdb, pIniFiles,
  bdlib, scciio,  sccidef, sccilib, xdb, punix,
  stringtransf, datalib,  smv, DIMime,wlmemory,uloglib,{$IFDEF FPC}orchestratorlib,{$ENDIF}
{$IFDEF XE}
  Data.SqlTimSt,Data.SqlExpr,
{$ENDIF}
  {$IFDEF FPC} zstream, base64, RegExpr,{$ELSE} DB, ZLib, {$ENDIF} sccisqldef;

type
  TFormatoVariavelTelaDocumento = (frmtvarteladoc_desconhecido,
                                   frmtvarteladoc_data,
                                   frmtvarteladoc_moeda,
                                   frmtvarteladoc_numero,
                                   frmtvarteladoc_texto);
  ECtrJaImplantadoException = class(Exception);
  
  TpItemDiretorio = record
                      FileName : string;
                      ID : integer;
                      Crc : integer;
                      Size : integer;
                      tipo : integer;
                    end;
  TArrItensDiretorio = array of TpItemDiretorio;

const

  FormatoVariavelTelaDocumentoDesc : array[TFormatoVariavelTelaDocumento] of string = ('','Data','Moeda','Número','Texto');
  TPGravacao_AmazonS3 = 2;
  TPGravacao_FileSystem = 1;
  TPGravacao_Banco = 0;
  LocalArmazenamentoS3: String = 'aws://s3';


  procedure MontaFilhosDoID( LeGlobal : Boolean;
                             IDPai   : longint;                             
                             NodePai : TpXmlNode;
                             Recursivo : boolean = true;
                             SomenteDiretorios : boolean = false;
                             SomenteDiretoriosIncluiLixeira : boolean = false;
                             LiberaPerfil : boolean = true;
                             ControlaAcesso : boolean = false); overload;

  procedure MontaFilhosDoID( SqlConnection : TSqlConnection;
                             LeGlobal : Boolean;
                             IDPai   : longint;
                             NodePai : TpXmlNode;
                             Recursivo : boolean = true;
                             SomenteDiretorios : boolean = false;
                             SomenteDiretoriosIncluiLixeira : boolean = false;
                             LiberaPerfil : boolean = true;
                             ControlaAcesso : boolean = false;
                             OrdenadoPorNome : boolean = false); overload;

  function MontaRaizStr(Sqlconnection : TSqlConnection; LeGlobal : Boolean;
                         Var St : AnsiString;Id : integer; 
                         Doc : string; 
                         Recursivo : boolean = true; 
                          SomenteDiretorios : boolean = false; 
                          SomenteDiretoriosIncluiLixeira : boolean = false; 
                          ControlaAcesso : boolean = false;
                          EhEvp: boolean = false): longint;

  procedure MontaRaiz(NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;EhEvp : boolean = false); overload;
  procedure MontaRaiz(SqlConnection : TSqlConnection; NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;
                      EhEvp: boolean = false ); overload;
  procedure MontaRaiz(LeGlobal : Boolean;NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;EhEvp: boolean = false);overload;
  procedure MontaRaiz(Sqlconnection : TSqlConnection; LeGlobal : Boolean;NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; 
                      SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;
                      EhEvp: boolean = false);overload;
  function GeraIdRaiz(SqlConnection : TSqlConnection;
                      ID : integer;
                      List : Thashedstringlist) : integer;
  function GeraIdRaiz2(SqlConnection : TSqlConnection;
                      ID : integer;
                      List : Thashedstringlist;
                      var lst : text) : integer;  
  function BuscaGrupoDoc(grupo : string;msg : string =''):integer;
  function InsereItemNaBaseESeqNome( IDPai  : longint;
                                     Tipo   : longint;
                                     Var Nome : ansistring;
                                     EXIBEPASTA : String;
                                     SequenciaNome : boolean = true) : longint;
  function  InsereItemNaBase( IDPai  : longint;
                             Tipo   : longint;
                             Nome   : ansistring) : longint; overload;
  function InsereItemTempNaBase(SqlConnection : TSqlConnection;
                                Nome: String): LongInt;
  function InsereItemNaBaseSqlConnection( SqlConnection : TSqlConnection;
                                          IDPai  : longint;
                                          Tipo   : longint;
                                          Nome   : ansistring;
                                          SequenciaNome : boolean = false) : longint;
  function  InsereVersao(ID, UltVersao : longint; Texto : ansistring): longint; overload;
  function  InsereVersaoBinario(SqlConnection : TSqlConnection; ID, UltVersao : longint; Stream : TStream; MiniaturaStr : AnsiString = '';FileNameGravacao : Ansistring = ''): longint; overload;
  function  InsereVersaoBinario(ID, UltVersao : longint; filename : TFilename): longint; overload;
  function  InsereVersaoBinario(SqlConnection : TSqlConnection; ID, UltVersao : longint; filename : TFilename;FileNameGravacao : Ansistring = ''): longint; overload;


function  InsereItemNaBase( SqlConnection : TSqlConnection;
                            IDPai  : longint;
                            Tipo   : longint;
                            Nome   : ansistring;
                            NO_Descricao : str255 = '';
                            CO_DOC_Dossie : longint = 0;
                            Co_Tipo_Arquivo : longint = 0;
                            Co_Identificacao : longint = 0) : longint; overload;

function InsereItemNaBase( SqlConnection : TSqlConnection;
                           IDPai  : longint;
                           Tipo   : longint;
                           Nome   : ansistring;
                           IN_CRIA_VERSAO_ATUALIZADA,
                           IN_DOCUMENTO_OCULTO,
                           IN_CONTROLE_VERSAO,
                           IN_DOCUMENTO_SO_LEITURA : string;
                           TE_OBSERVACAO_ARQUIVO : ansistring;
                           ItemRaiz : boolean = false) : longint; overload;

function InsereItemNaBase( SqlConnection : TSqlConnection;
                           IDPai  : longint;
                           Tipo   : longint;
                           Nome   : ansistring;
                           IN_CRIA_VERSAO_ATUALIZADA,
                           IN_DOCUMENTO_OCULTO,
                           IN_CONTROLE_VERSAO,
                           IN_DOCUMENTO_SO_LEITURA : string;
                           TE_OBSERVACAO_ARQUIVO : ansistring;
                           NO_Descricao : str255;
                           CO_Doc_Dossie : longint;
                           ItemRaiz : boolean = false) : longint; overload;


function  InsereVersao(SqlConnection : TSqlConnection;
                       ID, UltVersao : longint; Texto : ansistring): longint; overload;
function LeIDdoDiretorio(SqlConnection : TSqlConnection; Pasta : string; idpai : integer = 0): integer;
procedure ListaArquivosDoDiretorio(SqlConnection : TSqlConnection;
                                   IdPai : integer; Arquivos : Tstrings); overload;

procedure ListaArquivosDoDiretorio(SqlConnection : TSqlConnection;
                                   Pasta : string; Arquivos : Tstrings); overload;

function GravaDocumentoTemporario(FilePathName: TFilename;
                                  FileNameFinal,SessionKey: string
                                  ):LongInt;
procedure GravaTextoVersao (ID, Versao    : Integer;
                           Texto          : AnsiString;
                           var NovaVersao : Integer);
procedure GravaBinarioVersao (ID, Versao     : Integer;
                              filename       : TFilename;
                              var NovaVersao : Integer); overload;
procedure GravaBinarioVersao (SqlConnection  : TSqlConnection;
                              ID, Versao     : Integer;
                              filename       : TFilename;
                              var NovaVersao : Integer;
                              GravaMiniatura : boolean = false); overload;
procedure GravaBinarioVersao (SqlConnection  : TSqlConnection;
                              ID, Versao     : Integer;
                              Stream         : TStream;
                              var NovaVersao : Integer;
                              MiniaturaStr      : AnsiString = ''); overload;


procedure GeraStreamMiniaturaImagem (NomeArq : TFileName; var Stream : TFileStream);
procedure AlteraNomeDoc (ID : Integer;  Nome : String);

procedure GeraNovaArvoreDeDocumentos(    SqlConnection : TSqlConnection; 
                                     Var IDRaiz : longint; 
                                         IDTemplate : longint = -1;
                                         ConsideraArqNaLixeira : boolean = true);
procedure AtualizaArvoreDeDocumentos(SqlConnection : TSqlConnection; IDRaiz : longint; Default : integer = -1);
procedure LeTemplate(SqlConnection : TSqlConnection;
                     IDTemplate : longint;
                     XmlTemplate : TpXml);
procedure AtualizaArvoreAPartirDoTemplate(SqlConnection : TSqlConnection;
                                          IDRaiz : longint;
                                          XmlTemplate : TpXml); overload;
function ExisteID(SqlConnection : TSqlConnection; ID : longint) : boolean;
function  IDDoDocumento(SqlCOnnection : TSqlConnection; documento : string; IDPai : integer) : integer;
procedure SaveDocumentoToFile(SqlConnection : TSqlConnection; ID : integer; Filename : TFileName;versao : integer = 0);
function SaveDocumentoToPdfFile(SqlConnection : TSqlConnection; ID : integer; Filename : TFileName;versao : integer = 0 ;
                                 Tamfonte: double = 5.0; Retrato: Boolean = false ; Titulo: String = '';PdfA : boolean = false): String;
procedure SaveDocumentoToStream(SqlConnection : TSqlConnection; ID : integer; Stream : TStream); overload;
procedure SaveDocumentoToStream(SqlConnection : TSqlConnection;
                                    ID : integer;
                                    Stream : TStream;
                                Var Nome : ansistring;
                                Var Versao : integer); overload;
procedure SaveDocumentoTemporarioToStream(
                                    ID : integer;
                                    SessionKey: String;
                                    Versao: LongInt;
                                    Stream : TStream);
function SaveDocumentoTemporarioToFile(
                                      ID : integer;
                                      sessionKey : String;
                                      FilePath : String = '';
                                      versao : integer = 1): String;
procedure SaveVersaoToStream(SqlConnection : TSqlConnection; ID, Versao : integer; Stream : TStream);
function GeraIDPaiDocumentosContrato(SqlConnection : TSqlConnection; Ctr : TpCtr; UsaSimulacao : boolean = false): longint;
function GeraIDPaiDocumentosImovel(SqlConnection : TSqlConnection; Empreend : longint; CodImv : string): longint;
function GeraIDPaiDocumentosEmp(SqlConnection : TSqlConnection; Empreend : longint): longint;
function GeraIDPaiDocumentosPretendente(SqlConnection : TSqlConnection; Inscricao : string): longint;
function TestaIDPaiDocumentosPretendente(SqlConnection : TSqlConnection; Inscricao : string): longint;
function GeraIDPaiDocumentosTarefa(SqlConnection : TSqlConnection; Tarefa : integer): longint;
procedure InsereIdentificadorItemTempNaBase(SqlConnection : TSqlConnection;
                                            ID: longint;SessionKey: String);
function InsereArquivo(Sqlconnection : TSqlConnection;
                       IDPai : integer; Nome : string; FileName : TFileName;
                       NO_Descricao : str255 = ''; CO_Doc_Dossie : longint = 0;
                       Co_Tipo_Arquivo : longint = 0;
                       Co_Identificacao : longint = 0): integer;

function InsereArquivoVersao(Sqlconnection : TSqlConnection;
                       IDPai : integer; Nome : string; FileName : TFileName;
                       NO_Descricao : str255 = ''; CO_Doc_Dossie : longint = 0;
                       Co_Tipo_Arquivo : longint = 0;
                       Co_Identificacao : longint = 0;
                       NomeAntigo: string = ''): integer;

function InsereStream(Sqlconnection : TSqlConnection;
                      IDPai : integer; Nome : string; Stream : TStream;
                      NO_Descricao : str255 = ''; CO_Doc_Dossie : longint = 0;
                      Co_Tipo_Arquivo : longint = 0;
                      Co_Identificacao : longint = 0): integer;

procedure AlteraDetalhesItem(SqlConnection : TSqlconnection;
                             ID : Integer;
                             Nome : String;
                             NO_Descricao : str255;
                             CO_Doc_Dossie : longint);

function NomeDocumento(SqlConnection : TSqlconnection; ID : integer) : string;
procedure LeDetalhesItem(SqlConnection : TSqlconnection; ID : Integer; Buffer : TpMemory);
procedure LeDocumentoDaPastaParaODiscoWeb(SqlConnection : TSqlconnection; Pasta,Nome : string; FileName : TFileName;var achou : boolean);
procedure LeDocumentoDaPastaParaODisco(SqlConnection : TSqlconnection; Pasta,Nome : string; FileName : TFileName);
function GeraPath(SqlConnection : TSqlConnection; ID : integer) : string;
function GeraPath2(SqlConnection : TSqlConnection; ID : integer;ExibeGlobais : Boolean) : string;
function ObtemIDPelaHierarquia(SqlConnection       : TSqlConnection;
                               IDpai,CodHierarquia : integer;
                               Inclui              : Boolean = True): integer;
procedure LeDocumentosXmlDoDisco(Dir : string; Root : TpXmlNode; Raiz : boolean = true);
procedure AtualizaDocumentosPeloXmlDisco(SqlConnection : TSqlConnection; XmlTemplate : TpXml);
procedure LeTodaArvoreParaXml(SqlConnection : TSqlConnection; IDRaiz : longint; Node : TpXmlNode);
procedure AtualizaNivelPeloXmlDisco(SqlConnection : TsqlConnection; Node, NodeTemplate : TpXmlNode);
procedure LeTelaParametros(SqlConnection : TSqlConnection;
                           texto : ansistring;
                           Filename: string;
                           Buffer : TpMemory;
                           TrocaTextPorMemo : boolean = false);
procedure VerificaCriterios(SqlConnection : TSqlConnection;
                            ID : longint;
                            Var CriaVersao,
                                ControleVersao,
                                GravaNovaVersao : boolean);
procedure MontaListaDocDaPastaParaCombo (SqlConnection : TsqlConnection;
                                         Pasta : String;
                                         IdIDent : longint;
                                         Var Lista : TStringList;
                                         ForcaPath : boolean = false);
procedure PegaNomeSeq (SqlConnection : TsqlConnection;
                       Var Doc : String;
                       IdPai : longint);

procedure DescompactaStream(Original, DesCompactado : TStream);
function CompactaStream(Original, Compactado : TStream): boolean;
function RetornaLocalArmazenaDocImgs : ansistring;
function RetornaFileSystemName(ID : integer; Versao : integer): ansistring;
procedure GaranteCaminhoFileSystemName(FileName : TFileName);
procedure ListaVariaveis(Texto : ansistring; FileName : string; LstVariaveisDocumento : Tstringlist; PadraoCorpWeb : boolean = false;NaoAddRepetida : boolean = false);
function EncontraPasta(SqlConnection : TSqlConnection; NomePasta : string; IDPai : integer; Var Achou : boolean) : integer;
function EncontraPastaPeloNome(SqlConnection : TSqlConnection; 
                               NomePasta : string) : integer;
function ObtemDocumentoNaPasta(NomeModelo,NomeTemp,Pasta : String): boolean;                               

procedure ExcluiUmArquivo(SqlConnection : TSqlConnection; ID : integer);
procedure ExcluiFilhosDoID(SqlConnection : TSqlConnection; IDRaiz : integer; ExcluiLixeira : boolean = true);
procedure ExcluiArvoreDocumentos(SqlConnection : TSqlConnection; IDRaiz : integer);
function LeVersaoDocumento(Sqlconnection : TSqlConnection; id : integer) : integer;
function ForcaPathDocumento(SqlConnection : TSqlConnection; IdPai : integer; Path : ansistring) : integer;
procedure LeDetalhesDocumento(    SqlConnection : TSqlconnection;
                                  ID : Integer;
                              Var Nome : string;
                              Var CodHierarquia : integer);

function LeIDdoItem(SqlConnection : TSqlConnection; 
                    Nome : string;
                    idpai : integer;
                    BuscaComCaseSensitive : boolean = false): integer;
function LeIDDoPath(SqlConnection : TSqlConnection;
                    Path : ansistring;
                    IDPai : integer;
                    BuscaComCaseSensitive : boolean = false): longint;
function NovaVersao(Sqlconnection : TSqlConnection; ID : longint): longint;
function ExtensaoDocumentoID(SqlConnection : TSqlconnection; ID : integer) : string;
function LeArqsXml(Sqlcon : TSqlconnection;nome,pasta : string;var Stream : TMemoryStream):boolean;
function LeArquivo(var Stream : TmemoryStream;Filename : TFileName) : string;
function LeArquivoInterface(var Stream : TmemoryStream;Filename : TFileName) : string;
procedure TrocaVariavelParaCorpWeb(Filename : AnsiString);
function ObtemIdPai(SqlConnection : TsqlConnection ; id : integer):integer;
procedure CopiaBinarioDocumento(SqlConnection : TSqlConnection; IDOrigem,IdDestino : integer; Prepare : boolean = false);
procedure LeDocumento(ID : Integer; var ListaOut : TscciMemory);
Function GravarPropriedades (ID : integer;
                             Propaga : boolean;
                             CO_HIERARQUIA_DOCUMENTO,
                             TE_OBSERVACAO_ARQUIVO,
                             IN_CONTROLE_VERSAO,
                             IN_CRIA_VERSAO_ATUALIZADA,
                             IN_DOCUMENTO_OCULTO,
                             IN_DOCUMENTO_SO_LEITURA,
                             IN_EXIBE_PASTA : String;
                             IN_CONTROLE_ASSINATURA : string = 'F';
                             IN_TIPO_ASSINATURA : integer = 0;
                             QT_REPRESENTANTES_ASSIN : integer = 0) : String;
function ExisteCtr(Ctr : TpCtr):boolean;
procedure LeArvore (IDRaiz : Integer;
                   Grupo,
                   CtrDocumentos : String;
                   SomenteDiretorios : Boolean;
                   var Arvore : Tpxml);
procedure verificaExistencia(FileName : String;
                            var Existe : Boolean);

function validaPropriedadesDoc(FileName : String;
                               var Existe : Boolean;
                               IdPai : integer):string;
function ValidaUsuarioDocumentoTemporario(
                                    SqlConnection : TSqlConnection;
                                    ID : integer;
                                    SessionKey: String): Boolean;
procedure AtualizaSizes(SqlCOnnection : TSqlConnection; ID,versao,size,sizec : integer);

procedure LePasta(StreamIn, StreamOut : TStream);

procedure ExcluiItem (StreamIn, StreamOut : TStream);

procedure RegistraLogErro( msg : ansistring; inscricao : string; logaplic : TLogAplic);

procedure InsereItemBinario (StreamIn, StreamOut : TStream);

procedure AlteraNome (StreamIn, StreamOut : TStream);

function adicionaArquivoSistArq(NomeArquivo, NomePasta: string):integer;

function atualizaDocumentoEmSpcSerasa(idAndamentoSerasa, idSistArq : integer; arquivoCrit : string):boolean;

{$IFDEF FPC}
procedure ObtemArquivosExternosDoJasper(FileNameJasper : ansistring; Files : Tstrings);
{$ENDIF}
function ObtemIDS(Operacao : Integer;
                  Caminho: String;
                  BuscaComCaseSensitive : boolean = false):Integer;
function UtilizaScciEmDocker:boolean;
function LeEntradaSpcSerasa (SqlConnection: TSqlConnection; NomeArq: AnsiString; CaminhoSistarq: AnsiString = ''):AnsiString;
function InsereArquivoEDeletaOriginal(SqlConnection : TSqlConnection; Caminho, FileName : AnsiString; NomeNoSistarq : AnsiString = ''):Integer;
procedure InsereArquivosLista(SqlConnection : TSqlConnection; Caminho, ArquivoArqs : AnsiString);
function ProcuraSaidaSpcSerasa(var filename: AnsiString):boolean;
{$IFDEF FPC}
function GravarArquivoNoS3(Modulo,FilePathName: String ; GeraUUID: boolean = true): AnsiString;
function GerarUUID: string;
procedure InsereVersaoAmazonS3(FilePathName: AnsiString);
function  LeArquivoAmazonS3(FilePathName: AnsiString ; modulo : String = 'DOCUMENTOS'): AnsiString;
procedure DeletaArquivoAmazonS3(FilePathName: AnsiString ; modulo : String = 'DOCUMENTOS');
{$ENDIF}
implementation

var
  gQryCopiaBinarioDocumento : TSqlQuery;

(*procedure debug(st : Ansistring);
var f : text;
begin
assign (f,pegadiratv+'/debug.txt');
append(f);
writeln(f,st);
close (f);
end;*)

procedure MontaListaDocDaPastaParaCombo (SqlConnection : TsqlConnection;
                                         Pasta : String;
                                         IdIDent : longint;
                                         Var Lista : TStringList;
                                         ForcaPath : boolean = false);
var 
  Qry : TsqlQuery;
  Id : longint;
begin
  Qry := TsqlQuery.create(nil);
  try
    if ForcaPath then
      ID := ForcaPathDocumento(SqlCOnnection, IdIdent, Pasta)
    else
      ID := LeIDdoDiretorio(SqlConnection,Pasta,IDIDent);
    Qry.sqlconnection := SqlConnection;
    Qry.sql.add('SELECT * FROM SISTARQ WHERE IDPAI=:ID AND TIPO=2 ');
    Qry.ParamByName('ID').asInteger:=ID; 
    Qry.Open;
    while not Qry.eof do begin
      Lista.add(Qry.fieldByName('NOME').asString);
      Qry.next;
    end;
  finally
  end;
end;

procedure PegaNomeSeq (SqlConnection : TsqlConnection;
                       VAr Doc : String;
                       IdPai : longint);
var 
  Qry : TsqlQuery;
  Seq : Integer;
  Nome: String;
begin
  Nome := '';
  Qry := TsqlQuery.create(nil);
  try
    Qry.sqlconnection := SqlConnection;
    Qry.sql.add('SELECT * FROM SISTARQ WHERE IDPAI=:ID AND TIPO=2 AND (NOME LIKE :Nome) ORDER BY NOME DESC');
    Qry.ParamByName('ID').asInteger:=IDPAI; 
    Qry.ParamByName('NOME').asString:=Doc+'%'; 
    Qry.Open;
    IF not Qry.eof then begin
      nome := Qry.fieldByName('NOME').asString;
      Seq := StrToIntDef(Copy(nome,Length(nome) -7,4),0) + 1;
      Doc := Doc + IntStr2(seq,4);
    end else
      Doc := Doc + IntStr2(1,4);

  finally
  end;
end;

procedure MontaFilhosDoID( LeGlobal : Boolean;
                           IDPai   : longint;
                           NodePai : TpXmlNode;
                           Recursivo : boolean = true;
                           SomenteDiretorios : boolean = false;
                           SomenteDiretoriosIncluiLixeira : boolean = false;
                           LiberaPerfil : boolean = true;
                           ControlaAcesso : boolean = false);
begin
  MontaFilhosDoID( SCISConnection,
                   LeGlobal,
                   IDPai,
                   NodePai,
                   Recursivo,
                   SomenteDiretorios,
                   SomenteDiretoriosIncluiLixeira,
                   LiberaPerfil,
                   ControlaAcesso);
end;

procedure LePerfilDoUsuario(SqlConnection : TSqlConnection; Usuario : string; Var PerfilPrimario, Perfilsecundario : integer);
var
  UserField : AnsiString;
  Query : TSqlQuery;
begin
  UserField := '';
  PerfilPrimario := 0;
  PerfilSecundario := 0;
  Query := TSqlQuery.Create(nil);
  try
    Query.SqlConnection := SqlConnection;
    GetCEnv ('USERFIELD', UserField);
    if (UserField = '') or (UserField = 'USUARIO') then begin
      Query.Sql.Add ('SELECT PERF_PRIMARIO as PRIMARIO, PERF_SECUNDARIO as SECUNDARIO FROM USUARIO');
      Query.Sql.Add ('WHERE USUARIO = :usuario')
    end
    else if UserField = 'CO_USUARIO' then begin
      Query.Sql.Add ('SELECT CO_PERFIL_PRIMARIO as PRIMARIO, CO_PERFIL_SECUNDARIO as SECUNDARIO FROM USUARIO');
      Query.Sql.Add ('WHERE CO_USUARIO = :usuario');
    end
    else
      Raise Exception.Create ('Variável de ambiente USERFIELD está com valor inválido: ' +
                                UserField + '.');
    Query.ParamByName('usuario').asstring := usuario;
    Query.open;
    if not Query.isEmpty then begin
      Perfilprimario := Query.fieldbyname('PRIMARIO').asinteger;
      Perfilsecundario := Query.fieldbyname('SECUNDARIO').asinteger;
    end;
  finally
    Query.free;
  end;
end;


function ERaiz(SqlConnection : TSqlConnection; id:integer; var idpai : integer): boolean;
var
  Qry : TSqlQuery;
begin
  result := true;
  idpai := id;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SQLConnection;
    Qry.Sql.add('select idpai from sistarq where id=:id');
    Qry.parambyname('id').asinteger := id;
    qry.open;
    if qry.isempty then
      raise exception.create('Base de documentos inconsistente.');
    result := Qry.FieldByName('IDPai').asinteger = id;
    if not result then idpai := Qry.FieldByName('IDPai').asinteger;
    qry.close;
  finally
    Qry.free;
  end;
end;

function PodeLiberarPerfil(SqlConnection : tSqlConnection; Id : Integer;LeGlobal : boolean = false;  ControlaAcesso : boolean = false;EhEvp: boolean = false):boolean;
var
  Qry : TSqlQuery;
  P1,P2,
  idpai : integer;
begin
  IdPai := 0;
  P1 := 0;
  P2 := 0;
  if not ControlaAcesso then result := true
  else begin
    result := false;
    if (not LeGlobal) and (not EhEvp) then begin
      if not ERaiz(Sqlconnection,id,idpai) then ID := ObtemIdPelaHierarquia(Sqlconnection,-1,id,false)
      else ID := -1;
    end;
    Qry := TSQLQuery.create(nil);
    try
      Qry.SqlConnection := SqlConnection;
      Qry.SQL.add('select * from perfil_sistarq where id=:id');
      Qry.ParamByName('ID').asinteger := ID;
      Qry.Open;
      if Qry.eof then result := true
      else begin
        LePerfilDoUsuario(Sqlconnection,PegaUsuario,P1,P2);
        while not Qry.eof do begin
          if Qry.fieldbyname('Cod_perfil').asinteger = P1 then begin
             result := true;       
          end;
          Qry.next;
        end;
      end;
      Qry.Close;
    finally
      Qry.free;
    end;
  end;
end;  
  
function PegaEntidadeUsuario(SqlConnection : TsqlConnection;Usuario : ShortString;ehEvp : Boolean):integer;
var QryAux  : TSqlQuery;
begin
  QryAux  := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SqlConnection;

    if ehevp then begin
      QryAux.Sql.Add ( 'SELECT CO_ENTIDADE_PRIMARIA FROM USUARIO');
      QryAux.Sql.Add ( 'WHERE CO_USUARIO = ' + QuotedStr(Usuario));
    end else begin
    
      QryAux.Sql.Add ( 'SELECT ENT_PRIMARIA FROM USUARIO');
      QryAux.Sql.Add ( 'WHERE USUARIO = ' + QuotedStr(Usuario));
    end;
      
    
    QryAux.Open;
    Result  := QryAux.Fields[0].AsInteger;
    QryAux.Close;
  Finally
    QryAux.Free;
  end;
end;

function ObtemSetorUsuario(SQLConnection : TSQLConnection;Usuario : ShortString;EhEvp : Boolean) : ShortString;
var QryAux  : TSqlQuery;
begin
  QryAux := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SQLConnection;
    if ehevp then begin
      QryAux.Sql.Add('SELECT CO_SETOR FROM USUARIO');
      QryAux.Sql.Add('WHERE CO_USUARIO = ' + QuotedStr(Usuario));
    end else begin
      QryAux.Sql.Add('SELECT CO_SETOR FROM USUARIO');
      QryAux.Sql.Add('WHERE USUARIO = ' + QuotedStr(Usuario));
    end;


    QryAux.Open;
    Result := QryAux.FieldByName('CO_SETOR').AsString;
    QryAux.Close;
  Finally
    QryAux.Free;
  end;
end;

function RegParaUsuario(SQLConnection : TSQLConnection;
                        id,perfil,ent :integer;
                        setor,
                        Usuario : ShortString;
                        var PodeEditarPorControle,PodeExcluirPorControle : String) : boolean;
var QryAux  : TSqlQuery;
begin
  QryAux := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SQLConnection;
    QryAux.Sql.Add('SELECT * FROM PERFIL_SISTARQ');
    QryAux.Sql.Add('WHERE USUARIO = ' + QuotedStr(Usuario));
    QryAux.Sql.Add(' AND  ID = ' + inttostr(id));
    QryAux.Sql.Add(' AND  (COD_PERFIL = ' + inttostr(perfil));
    QryAux.Sql.Add(' OR  COD_PERFIL = ' + inttostr(0)+')');
    QryAux.Sql.Add(' AND  COD_ENT = ' + inttostr(ent));
    QryAux.Sql.Add(' AND  CO_SETOR = ' + QuotedStr(setor));
    QryAux.Open;
    result := not QryAux.eof;
    if result then begin
      PodeEditarPorControle := qryaux.fieldbyname('in_pode_atualizar').asString;
      PodeExcluirPorControle := qryaux.fieldbyname('in_pode_excluir').asString;

    end;
    QryAux.Close;


  Finally
    QryAux.Free;
  end;
end;

function RegParaSetor(SQLConnection : TSQLConnection;
                        id,perfil,ent :integer;
                        setor : String;
                        var PodeEditarPorControle,PodeExcluirPorControle : String) : boolean;
var QryAux  : TSqlQuery;
begin
  QryAux := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SQLConnection;
    QryAux.Sql.Add('SELECT * FROM PERFIL_SISTARQ');
    QryAux.Sql.Add('WHERE CO_SETOR = ' + QuotedStr(setor) );
    QryAux.Sql.Add(' AND  ID = ' + inttostr(id));
    QryAux.Sql.Add(' AND  (COD_PERFIL = ' + inttostr(perfil));
    QryAux.Sql.Add(' OR  COD_PERFIL = ' + inttostr(0)+')');
    QryAux.Sql.Add(' AND  COD_ENT = ' + inttostr(ent));
    QryAux.Sql.Add(' AND  (USUARIO = ' + Quotedstr('')+' OR USUARIO IS NULL)');

    QryAux.Open;

    result := not QryAux.eof;
    if result then begin
      PodeEditarPorControle := qryaux.fieldbyname('in_pode_atualizar').asString;
      PodeExcluirPorControle := qryaux.fieldbyname('in_pode_excluir').asString;
    end;

    QryAux.Close;


  Finally
    QryAux.Free;
  end;
end;

function RegParaEntidade(SQLConnection : TSQLConnection;
                        id,perfil,ent :integer;
                        var PodeEditarPorControle,PodeExcluirPorControle : String) : boolean;
var QryAux  : TSqlQuery;
begin
  QryAux := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SQLConnection;
    QryAux.Sql.Add('SELECT * FROM PERFIL_SISTARQ');
    QryAux.Sql.Add('WHERE COD_ENT = ' + inttostr(ent));
    QryAux.Sql.Add(' AND  (CO_SETOR = ' + Quotedstr('')+' OR CO_SETOR IS NULL)' );
    QryAux.Sql.Add(' AND  (USUARIO = ' + Quotedstr('')+' OR USUARIO IS NULL)');
    QryAux.Sql.Add(' AND  ID = ' + inttostr(id));
    QryAux.Sql.Add(' AND  (COD_PERFIL = ' + inttostr(perfil));
    QryAux.Sql.Add(' OR  COD_PERFIL = ' + inttostr(0)+')');
    QryAux.Open;
    result := not QryAux.eof;
    if result then begin
      PodeEditarPorControle := qryaux.fieldbyname('in_pode_atualizar').asString;
      PodeExcluirPorControle := qryaux.fieldbyname('in_pode_excluir').asString;
    end;
    QryAux.Close;


  Finally
    QryAux.Free;
  end;
end;

function RegParaPerfil(SQLConnection : TSQLConnection;
                        id,perfil :integer;
                        var PodeEditarPorControle,PodeExcluirPorControle : String) : boolean;
var QryAux  : TSqlQuery;
begin
  QryAux := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SQLConnection;
    QryAux.Sql.Add('SELECT * FROM PERFIL_SISTARQ');
    QryAux.Sql.Add('WHERE (COD_PERFIL = ' + inttostr(perfil));
    QryAux.Sql.Add(' OR  COD_PERFIL = ' + inttostr(0));
    QryAux.Sql.Add(') AND  ID = ' + inttostr(id));
    QryAux.Sql.Add(' AND  COD_ENT = ' + inttostr(0));
    QryAux.Sql.Add(' AND  (CO_SETOR = ' + Quotedstr('')+' OR CO_SETOR IS NULL)' );
    QryAux.Sql.Add(' AND  (USUARIO = ' + Quotedstr('')+' OR USUARIO IS NULL)');

    QryAux.Open;
    result := not QryAux.eof;
    if result then begin
      PodeEditarPorControle := qryaux.fieldbyname('in_pode_atualizar').asString;
      PodeExcluirPorControle := qryaux.fieldbyname('in_pode_excluir').asString;
    end;

    QryAux.Close;

  Finally
    QryAux.Free;
  end;
end;

function RegParaID(SQLConnection : TSQLConnection;
                        id : integer;
                        var PodeEditarPorControle,PodeExcluirPorControle : String) : boolean;
var QryAux  : TSqlQuery;
begin
  QryAux := TSQLQuery.Create(nil);
  try
    QryAux.SQLConnection := SQLConnection;
    QryAux.Sql.Add('SELECT * FROM PERFIL_SISTARQ');
    QryAux.Sql.Add('WHERE ID = ' + inttostr(id));
    QryAux.Open;
    result := not QryAux.eof;
    if result then begin
      PodeEditarPorControle := qryaux.fieldbyname('in_pode_atualizar').asString;
      PodeExcluirPorControle := qryaux.fieldbyname('in_pode_excluir').asString;
    end;
    QryAux.Close;
  Finally
    QryAux.Free;
  end;
end;




function PodeLiberarPerfilControle(SqlConnection : tSqlConnection; Id : Integer;var PodeEditarPorControle :string ; var PodeExcluirPorControle : string; LeGlobal : boolean = false; ControlaAcesso : boolean = false;EhEvp: boolean = false): boolean;
var
  Qry : TSqlQuery;
  P1,P2,
  idpai,idHierarquia,ent : integer;
  setor : string;
begin
    idHierarquia := 0;
    IdPai := 0;
    P1 := 0;
    P2 := 0;
    result := false;
    if (not LeGlobal) and (not EhEvp)  then begin
      if not ERaiz(Sqlconnection,id,idpai) then begin
         idHierarquia := ObtemIdPelaHierarquia(Sqlconnection,-1,id,false);
      end;
      ///else ID := -1;
      if idHierarquia >= 0 then ID := idHierarquia;
    end;
    
    Qry := TSQLQuery.create(nil);
    try
      Qry.SqlConnection := SqlConnection;
      Qry.SQL.add('select * from perfil_sistarq where id=:id');
      Qry.sql.add(' order by cod_perfil,cod_ent,co_setor,usuario');
      Qry.ParamByName('ID').asinteger := ID;
      Qry.Open;

      if  Qry.eof then begin
        idpai := ObtemIdPai(SqlConnection,Id);
        if (idPai > 0) and (idpai < id) then
           result := PodeLiberarPerfilControle(SqlConnection, IdPai,
                                    PodeEditarPorControle,
                                    PodeExcluirPorControle, LeGlobal, 
                                    ControlaAcesso,EhEvp)
        else 
        result := true;
      end
      else begin
        LePerfilDoUsuario(Sqlconnection,PegaUsuario,P1,P2);
        Ent := PegaEntidadeUsuario(Sqlconnection,PegaUsuario,EhEvp);
        Setor := ObtemSetorUsuario(SQLConnection,PegaUsuario,EhEvp);
        if RegParaUsuario(SQLConnection,id,p1,ent,setor,pegausuario,PodeEditarPorControle,PodeExcluirPorControle) then
        begin
           result := true;
        end else if RegParaSetor(SQLConnection,id,p1,ent,setor,PodeEditarPorControle,PodeExcluirPorControle) then
        begin
           result := true;
        end else if RegParaEntidade(SQLConnection,id,p1,ent,PodeEditarPorControle,PodeExcluirPorControle) then
        begin
           result := true;
        end else if RegParaPerfil(SQLConnection,id,p1,PodeEditarPorControle,PodeExcluirPorControle) then
        begin
           result := true;
        end;

      end;
      Qry.Close;
    finally
      Qry.free;
  
  end;
end;  


procedure MontaFilhosDoID( SqlConnection : TSqlConnection;
                           LeGlobal : Boolean;
                           IDPai   : longint;
                           NodePai : TpXmlNode;
                           Recursivo : boolean = true;
                           SomenteDiretorios : boolean = false;
                           SomenteDiretoriosIncluiLixeira : boolean = false;
                           LiberaPerfil : boolean = true;
                           ControlaAcesso : boolean = false;
                           OrdenadoPorNome : boolean = false);
var
  Qry : TSQLQuery;
  Node : TpXmlNode;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Close;
    Qry.Sql.clear;
    Qry.SQL.Add('select IN_EXIBE_PASTA,Id, Nome, Tipo, IN_CONTROLE_VERSAO, IN_CRIA_VERSAO_ATUALIZADA,');
    Qry.SQL.Add('IN_DOCUMENTO_OCULTO, IN_DOCUMENTO_SO_LEITURA,no_descricao,co_doc_dossie,co_hierarquia_documento, nu_ordem,');
    Qry.SQL.Add('CO_TIPO_ARQUIVO, CO_IDENTIFICACAO ');
    Qry.SQL.Add('from sistarq where idpai = :id and id <> :id ');
    Qry.ParamByName('ID').asinteger := IDPai;
    if SomenteDiretorios or (not LiberaPerfil) then begin
      if SomenteDiretoriosIncluiLixeira then begin
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz or TIPO = :Lixeira)');
        Qry.ParamByname('Lixeira').asinteger := ord(ta_Lixeira);
      end
      else
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz)');
      Qry.ParamByname('Pasta').asinteger := ord(ta_Pasta);
      Qry.ParamByname('Raiz').asinteger := ord(ta_raiz);
    end;
    if OrdenadoPorNome then
      Qry.Sql.add(' ORDER BY NOME');
    Qry.open;
    while not Qry.Eof do begin
      if Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring <> 'S' then 
        if ((LeGlobal and (Qry.fieldByName('IN_EXIBE_PASTA').AsString ='S')) or
          (Not LeGlobal) or (Qry.FieldByName('Tipo').asInteger = 3){ or
          (Qry.FieldByName('TIPO').asINteger = Ord(ta_documento))}) then begin
        Node := NodePai.AddChild(Qry.FieldByName('ID').asstring);
        Node.Attributes['NOME'] :=  Qry.FieldByName('Nome').asstring;
        Node.Attributes['TIPO'] := Qry.FieldByName('TIPO').asstring;
        Node.Attributes['ID']   := Qry.FieldByName('ID').asstring;
        if not PodeLiberarPerfil(SqlConnection,Qry.FieldByName('id').asinteger,LeGlobal,ControlaAcesso) then begin
          Node.Attributes['IN_DOCUMENTO_SO_LEITURA'] := 'S';
          Node.Attributes['IN_EDITA_PROPRIEDADE'] := 'N';
        end
        else 
          Node.Attributes['IN_DOCUMENTO_SO_LEITURA'] :=
                            Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring;

        Node.Attributes['IN_CRIA_VERSAO_ATUALIZADA'] :=
                            Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring;
        Node.Attributes['IN_CONTROLE_VERSAO'] :=
                            Qry.FieldByName('IN_CONTROLE_VERSAO').asstring;
        Node.Attributes['NO_DESCRICAO'] := Qry.FieldByName('NO_DESCRICAO').asstring;
        Node.Attributes['CO_DOC_DOSSIE'] := inttostr(Qry.FieldByName('CO_DOC_DOSSIE').asinteger);
        Node.Attributes['co_hierarquia_documento'] := inttostr(Qry.FieldByName('co_hierarquia_documento').asinteger);
        if not Qry.fieldbyname('nu_ordem').isnull then
          Node.Attributes['nu_ordem'] := inttostr(Qry.fieldbyname('nu_ordem').asinteger);
        Node.Attributes['CO_TIPO_ARQUIVO']   := Qry.FieldByName('CO_TIPO_ARQUIVO').asstring;
        Node.Attributes['CO_IDENTIFICACAO']   := Qry.FieldByName('CO_IDENTIFICACAO').asstring;

        if Recursivo then
          MontaFilhosDoID(SqlConnection,LeGlobal,Qry.FieldByName('ID').asinteger,Node,Recursivo,SomenteDiretorios,SomenteDiretoriosIncluiLixeira,liberaPerfil,ControlaAcesso);
      end;
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;


procedure MontaFilhosDoIDStr( SqlConnection : TSqlConnection;
                           LeGlobal : Boolean;
                           IDPai   : longint;
                           Doc     : String;
                           var St : Ansistring;
                           var idini : integer;
                           Recursivo : boolean = true;
                           SomenteDiretorios : boolean = false;
                           SomenteDiretoriosIncluiLixeira : boolean = false;
                           LiberaPerfil : boolean = true;
                           ControlaAcesso : boolean = false);
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Close;
    Qry.Sql.clear;
    Qry.SQL.Add('select IN_EXIBE_PASTA,Id, Nome, Tipo, IN_CONTROLE_VERSAO, IN_CRIA_VERSAO_ATUALIZADA,');
    Qry.SQL.Add('IN_DOCUMENTO_OCULTO, IN_DOCUMENTO_SO_LEITURA,no_descricao,co_doc_dossie,co_hierarquia_documento, nu_ordem');
    Qry.SQL.Add('from sistarq where idpai = :id and id <> :id ');
    Qry.ParamByName('ID').asinteger := IDPai;
    if SomenteDiretorios or (not LiberaPerfil) then begin
      if SomenteDiretoriosIncluiLixeira then begin
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz or TIPO = :Lixeira)');
        Qry.ParamByname('Lixeira').asinteger := ord(ta_Lixeira);
      end
      else
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz)');
      Qry.ParamByname('Pasta').asinteger := ord(ta_Pasta);
      Qry.ParamByname('Raiz').asinteger := ord(ta_raiz);
    end;
    Qry.open;
    while not Qry.Eof do begin
      if Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring <> 'S' then 
        if (LeGlobal and (Qry.fieldByName('IN_EXIBE_PASTA').AsString ='S')) or
          (Not LeGlobal) or (Qry.FieldByName('Tipo').asInteger = 3) or
          (Qry.FieldByName('TIPO').asINteger = Ord(ta_documento))  then begin
        St := St +'/'+  (Qry.FieldByName('Nome').asstring);
       // recursivo := Qry.FieldByName('Nome').asstring <> doc;
        recursivo := Pos(doc, AnsiUpperCase(Qry.FieldByName('Nome').asstring)) = 0 ;
        if not recursivo then idini := Qry.FieldByName('ID').asinteger;
        if Recursivo then
          MontaFilhosDoIDStr(SqlConnection,LeGlobal,Qry.FieldByName('ID').asinteger,doc,St,idini,Recursivo,SomenteDiretorios,SomenteDiretoriosIncluiLixeira,liberaPerfil,ControlaAcesso);
      end;
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;


procedure MontaRaiz(NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;EhEvp: boolean = false); overload;
begin
  MontaRaiz(SCISConnection,False,NodePai,Id, Recursivo,SomenteDiretorios,SomenteDiretoriosIncluiLixeira,ControlaAcesso,EhEvp);
end;


procedure MontaRaiz(SqlConnection : TSqlConnection; NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; 
ControlaAcesso : boolean = false;EhEvp: boolean = false); overload;
begin
  MontaRaiz(SqlConnection,False,NodePai,Id, Recursivo,SomenteDiretorios,SomenteDiretoriosIncluiLixeira,ControlaAcesso,EhEvp);
end;


procedure MontaRaiz(LeGlobal : Boolean;NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;EhEvp: boolean = false);overload;
begin
  MontaRaiz(SCISConnection,LeGlobal,NodePai,Id,Recursivo,SomenteDiretorios,SomenteDiretoriosIncluiLixeira,Controlaacesso,EhEvp);
end;

procedure MontaRaiz(Sqlconnection : TSqlConnection; LeGlobal : Boolean;NodePai : TpXmlNode;Id : integer; Recursivo : boolean = true; 
                    SomenteDiretorios : boolean = false; SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;
                    EhEvp: boolean = false);overload;
var
  Qry : TSQLQuery;
  Node : TpXmlNode;
  LiberaPerfil : boolean;
  PodeEditarPorControle,
  PodeExcluirPorControle : String;
                             
begin
  PodeEditarPorControle := 'T';
  PodeExcluirPorControle := 'T';
  Qry := TSQLQuery.create(nil);


  try
    LiberaPerfil := PodeLiberarPerfilControle(SqlConnection,id,PodeEditarPorControle,PodeExcluirPorControle,
                    LeGlobal,ControlaAcesso,EhEvp);
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select IN_EXIBE_PASTA,Id, IdPai, Nome, Tipo, IN_CONTROLE_VERSAO, IN_CRIA_VERSAO_ATUALIZADA,');
    Qry.SQL.Add('IN_DOCUMENTO_OCULTO, IN_DOCUMENTO_SO_LEITURA,no_descricao,co_doc_dossie,co_hierarquia_documento, NU_ORDEM');
    Qry.SQL.Add('from sistarq where id = :id ');
    if SomenteDiretorios{ or (not LiberaPerfil) }then begin
      if SomenteDiretoriosIncluiLixeira then begin
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz or TIPO = :Lixeira)');
        Qry.ParamByname('Lixeira').asinteger := ord(ta_Lixeira);
      end
      else
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz)');
      Qry.ParamByname('Pasta').asinteger := ord(ta_Pasta);
      Qry.ParamByname('Raiz').asinteger := ord(ta_raiz);
    end;
    Qry.Params[0].datatype := ftinteger;
    Qry.Params[0].asinteger :=id;
    Qry.open;
    if Qry.IsEmpty then
      raise exception.create('Sistema de arquivos vazio')
    else if Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring = 'S' then
      raise exception.create('Sistema de arquivos só tem documentos ocultos.');
    if not liberaperfil then 
      raise exception.create('Esse usuário não tem permissão para acessar essa pasta.');
     // raise exception.create('Seu perfil não tem permissão para visualizar documentos desta pasta.');


    if (LeGlobal and (Qry.fieldByName('IN_EXIBE_PASTA').AsString ='S')) or
       (Not LeGlobal) or (Qry.FieldByName('Id').asInteger = 0) or 
       (Qry.FieldByName('Tipo').asInteger = 3) then begin   
      Node := NodePai.AddChild(Qry.FieldByName('ID').asstring);
     
      if LeGlobal and
        (Qry.FieldByName('Nome').asString = 'Documentos') then
           Node.Attributes['NOME'] :=  'Documentos Globais'
      else Node.Attributes['NOME'] :=  Qry.FieldByName('Nome').asstring;
      Node.Attributes['TIPO'] := Qry.FieldByName('TIPO').asstring;
      Node.Attributes['PODEEDITARPORCONTROLE'] := (PodeEditarPorControle);
      Node.Attributes['PODEEXCLUIRPORCONTROLE'] := (PodeExcluirPorControle);
      if Qry.FieldByName('ID').asinteger = Qry.FieldByname('IDPai').asinteger then
        Node.Attributes['TIPO'] := '0'; // Para prever o tipo correto das raizes de contratos
      Node.Attributes['ID']   := Qry.FieldByName('ID').asstring;
      Node.Attributes['IN_DOCUMENTO_SO_LEITURA'] :=
                            Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring;
      Node.Attributes['IN_CRIA_VERSAO_ATUALIZADA'] :=
                            Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring;
      Node.Attributes['IN_CONTROLE_VERSAO'] :=
                            Qry.FieldByName('IN_CONTROLE_VERSAO').asstring;
      Node.Attributes['NO_DESCRICAO'] := Qry.FieldByName('NO_DESCRICAO').asstring;
      Node.Attributes['CO_DOC_DOSSIE'] := inttostr(Qry.FieldByName('CO_DOC_DOSSIE').asinteger);
      Node.Attributes['co_hierarquia_documento'] := inttostr(Qry.FieldByName('co_hierarquia_documento').asinteger);
      if not Qry.fieldbyname('nu_ordem').isnull then
        Node.Attributes['nu_ordem'] := inttostr(Qry.fieldbyname('nu_ordem').asinteger);
      if not liberaPerfil then begin
        Node.Attributes['IN_DOCUMENTO_SO_LEITURA'] := 'S';
        Node.Attributes['IN_EDITA_PROPRIEDADE'] := 'N';
      end
      else 
        Node.Attributes['IN_DOCUMENTO_SO_LEITURA'] :=
                          Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring;

      if LiberaPerfil then MontaFilhosDoID(SqlConnection,leGlobal,Qry.FieldByName('ID').asinteger,Node,Recursivo,SomenteDiretorios,SomenteDiretoriosIncluiLixeira,LiberaPerfil,Controlaacesso);
    end;
  finally
    Qry.free;
  end;
end;

function MontaRaizStr(Sqlconnection : TSqlConnection; LeGlobal : Boolean;
                       Var St : AnsiString;Id : integer; 
                       doc : String;
                       Recursivo : boolean = true; 
                       SomenteDiretorios : boolean = false; 
                       SomenteDiretoriosIncluiLixeira : boolean = false; ControlaAcesso : boolean = false;
                       EhEvp: boolean = false): longint;
var
  Qry : TSQLQuery;
  LiberaPerfil : boolean;

begin
  result := 0;
  Qry := TSQLQuery.create(nil);
  try
    LiberaPerfil := PodeLiberarPerfil(SqlConnection,id,LeGlobal,ControlaAcesso,EhEvp);
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select IN_EXIBE_PASTA,Id, IdPai, Nome, Tipo, IN_CONTROLE_VERSAO, IN_CRIA_VERSAO_ATUALIZADA,');
    Qry.SQL.Add('IN_DOCUMENTO_OCULTO, IN_DOCUMENTO_SO_LEITURA,no_descricao,co_doc_dossie,co_hierarquia_documento, NU_ORDEM');
    Qry.SQL.Add('from sistarq where id = :id ');
    if SomenteDiretorios or (not LiberaPerfil) then begin
      if SomenteDiretoriosIncluiLixeira then begin
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz or TIPO = :Lixeira)');
        Qry.ParamByname('Lixeira').asinteger := ord(ta_Lixeira);
      end
      else
        Qry.Sql.add(' and (TIPO = :Pasta or TIPO = :Raiz)');
      Qry.ParamByname('Pasta').asinteger := ord(ta_Pasta);
      Qry.ParamByname('Raiz').asinteger := ord(ta_raiz);
    end;
    Qry.Params[0].datatype := ftinteger;
    Qry.Params[0].asinteger :=id;
    Qry.open;
    if Qry.IsEmpty then
      raise exception.create('Sistema de arquivos vazio')
    else if Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring = 'S' then
      raise exception.create('Sistema de arquivos só tem documentos ocultos.');

    if (LeGlobal and (Qry.fieldByName('IN_EXIBE_PASTA').AsString ='S')) or
       (Not LeGlobal) or (Qry.FieldByName('Id').asInteger = 0) or 
       (Qry.FieldByName('Tipo').asInteger = 3) then begin   
      St := St +'/'+ Qry.FieldByName('Nome').asstring;
      recursivo := Pos(doc, AnsiUpperCase(Qry.FieldByName('Nome').asstring)) = 0 ;
      if not recursivo then result := Qry.FieldByName('ID').asinteger;
      if recursivo then MontaFilhosDoIDStr(SqlConnection,leGlobal,
         Qry.FieldByName('ID').asinteger,Doc,St,result,Recursivo,
         SomenteDiretorios,SomenteDiretoriosIncluiLixeira,
         LiberaPerfil,Controlaacesso);
    end;
  finally
    Qry.free;
  end;
end;


function BuscaGrupoDoc(grupo : string;msg : string =''):integer;
var
  Qry : TSQLQuery;
begin
  result := 0;
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SCISConnection;
    Qry.SQL.add('select Id from sistarq where Upper(nome) = Upper(:nome)');
    Qry.Params[0].datatype := ftstring;
    Qry.Params[0].asstring := Grupo;
    Qry.open;
    if Qry.IsEmpty then
      if msg > '' then
        raise exception.create(msg)
      else raise exception.create('Sistema de arquivos vazio');
    result := qry.fieldbyname('id').asInteger;
  finally
    Qry.free;
  end;
end;

procedure IdRaizDoDoc(Sqlconnection : TSqlConnection;Id : Integer);
var
  Qry : TSQLQuery;
  list : Thashedstringlist;
begin
  Qry := TSQLQuery.create(nil);
  list := Thashedstringlist.create;
  try
    Qry.SqlConnection := SQlConnection;
    Qry.SQL.add('update sistarq set Idraiz=:Pid where id=:iditem');
    Qry.Params[0].asInteger := GeraIdRaiz(SqlConnection,Id,list);
    Qry.Params[1].asInteger := Id;
    Qry.execsql;
  finally
    list.free;
    Qry.free;
  end;
end;

procedure PegaProxNomeSeq (    SqlConnection : TsqlConnection;
                               IdPai : longint;
                           VAr Nome : ansistring);
var
  Qry : TsqlQuery;
  Seq : Integer;
  nometemp : string;
  ext : string;
  exttemp : string;
  seqnome : integer;
  Doc : ansistring;
begin
  Seq := -1;
  Qry := TsqlQuery.create(nil);
  try
    Qry.sqlconnection := SqlConnection;
    Qry.sql.add('SELECT * FROM SISTARQ WHERE IDPAI=:ID AND (NOME LIKE :Nome)');
    Qry.ParamByName('ID').asInteger:=IDPAI;

    Doc := nome;
    
    Ext := ExtractFileExt(doc);
    if ext > '' then
      delete(doc,length(doc)-length(ext)+1,length(ext));
      
    Qry.ParamByName('NOME').asString:=Doc+'%'+ext;

    Qry.Open;
    while not Qry.Eof do begin

      nometemp := Qry.fieldByName('NOME').asString;

      exttemp := ExtractFileExt(nometemp);
      if exttemp > '' then
        delete(nometemp,length(nometemp)-length(exttemp)+1,length(exttemp));

      if (uppercase(copy(nometemp,1,length(doc))) = uppercase(doc)) and
         (uppercase(exttemp) = uppercase(ext)) then begin

        // se o começo e o fim são iguais, verifico se vem "(seq)"

        // deixo só o (seq)
        delete(nometemp,1,length(doc));

        if nometemp = '' then begin// se não sobrou nada é pq não tem indice, apenas o nome
          if Seq = -1 then
            Seq := 0;
        end
        else if nometemp[1] = '(' then begin// confiro se realmente é um (...)
          delete(nometemp,1,1);
          if pos(')',nometemp) = length(nometemp) then begin
            delete(nometemp,length(nometemp),1);
            try
              // tenta converter o seq do arquivo se der erro, ignora
              seqnome := strtoint(nometemp);

              // vê se o seq é maior que o último visto
              if seqnome > seq then
                seq := seqnome;
            except
              // apenas ignorar registro lido
            end;
          end;
        end;
      end;
      Qry.next;
    end;
    
    // se já tem algum sequencia, soma 1 e devolve. 0 é o nome sem qualquer indice
    if seq > -1 then
      Nome := Doc + '(' + inttostr(seq+1) + ')' + ext;
      
  finally
    Qry.free;
  end;
end;

function InsereItemNaBaseESeqNome0( SqlConnection : TSqlConnection;
                                    IDPai  : longint;
                                    Tipo   : longint;
                                    Var Nome : ansistring;
                                    EXIBEPASTA : String;
                                    SequenciaNome : boolean = true) : longint;
var
  Qry,
  QryPai : TSqlQuery;
  incluiu : boolean;
  erros : integer;
  ext : ansistring;
  nomeaux : ansistring;
begin
  NomeAux := '';
  ext := '';
  if Trim(exibepasta) = 'T' then
     ExibePasta := 'S';
  if Trim(exibepasta) = 'F' then
    ExibePasta := 'N';
  erros := 0;
  incluiu := false;
  { 247 devido a criação de nome repetido onde ele insere o (1) no final do nome }
  if length(nome) > 247 then
    raise exception.create('O Nome do arquivo ultrapassou o tamanho máximo permitido!');
  result := LeGenerator(SqlConnection,id_SistArq);
  Qry    := TSqlQuery.create(nil);
  QryPai := TSqlQuery.create(nil);
  try
    Qry.SQLConnection    := SqlConnection;
    QryPai.SQLConnection := SqlConnection;
    if  Tipo = 2 then begin
      QryPai.Sql.Add('SELECT IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO,');
      QryPai.Sql.add( '      IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA');
      QryPai.Sql.Add('FROM SISTARQ');
      QryPai.Sql.Add('WHERE ID = ' + IntToStr(IDPai));
      QryPai.Open;
      if  not QryPai.Eof then begin
        Qry.SQL.Add('INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO,IN_EXIBE_PASTA,');
        Qry.SQL.Add('IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO,');
        Qry.SQL.Add('IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA) VALUES ');
        Qry.SQL.Add('(:ID,:IDPAI,:NOME,:TIPO,:EXIBEPASTA,');
        Qry.SQL.Add(' :IN_CRIA_VERSAO_ATUALIZADA, :IN_DOCUMENTO_OCULTO,');
        Qry.SQL.Add(' :IN_CONTROLE_VERSAO, :IN_DOCUMENTO_SO_LEITURA)');
        Qry.Params[5].AsString := QryPai.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').AsString;
        Qry.Params[6].AsString := QryPai.FieldByName('IN_DOCUMENTO_OCULTO').AsString;
        Qry.Params[7].AsString := QryPai.FieldByName('IN_CONTROLE_VERSAO').AsString;
        Qry.Params[8].AsString := QryPai.FieldByName('IN_DOCUMENTO_SO_LEITURA').AsString;
      end
      else
        Qry.SQL.text := 'INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO) VALUES '+
                        '(:ID,:IDPAI,:NOME,:TIPO)';
    end
    else
      Qry.SQL.text := 'INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO,IN_EXIBE_PASTA) VALUES '+
                      '(:ID,:IDPAI,:NOME,:TIPO,:EXIBEPASTA)';

    Qry.Params[0].asinteger := result;
    Qry.Params[1].asinteger := IDPai;
    if SequenciaNome then begin
      nomeAux := nome;
      PegaProxNomeSeq(Qry.SqlConnection,IdPai,NomeAux);
      Qry.Params[2].asstring := nomeaux;
    end
    else
      Qry.Params[2].asstring  := Nome;
    Qry.Params[3].asinteger := Tipo;
    Qry.Params[4].asString := ExibePasta;

    repeat
      try
        Qry.ExecSql;
        idRaizDoDoc(sqlconnection,result);
        incluiu := true;
      except
        on e : exception do begin
          if (pos('duplicate value',e.message) > 0 {Firebird}) or
             (pos('duplicate key',e.message) > 0 {Mssql}) or
             (pos('violada',e.message) > 0 {Oracle}) then begin
            inc(Erros);
            if Erros > 5 then
              raise exception.create('Não foi possível incluir registro no módulo de documentos')
            else if ExisteID(Qry.SqlConnection,result) then begin
              result := LeGenerator(SqlConnection,id_SistArq);
              Qry.Params[0].asinteger := result;
            end
            else if SequenciaNome then begin
              nomeAux := nome;
              PegaProxNomeSeq(Qry.SqlConnection,IdPai,NomeAux);
              Qry.Params[2].asstring := nomeaux;
            end
            else
              raise exception.create('1Já existe arquivo com este nome.')
          end
          else
            raise;
        end;
      end;
    until incluiu;
  finally
    Qry.free;
    QryPai.Free;
  end;

  if Incluiu and (NomeAux > '') then
    Nome := NomeAux;
end;

function InsereItemNaBaseESeqNome( IDPai  : longint;
                                   Tipo   : longint;
                                   Var Nome : ansistring;
                                   EXIBEPASTA : String;
                                   SequenciaNome : boolean = true) : longint;
begin
  result := InsereItemNaBaseESeqNome0(SCISConnection,IDPai,Tipo,Nome,ExibePasta,SequenciaNome);
end;

function InsereItemNaBase( IDPai  : longint;
                           Tipo   : longint;
                           Nome   : ansistring) : longint;
begin
  result := InsereItemNabaseESeqNome(IDPai,Tipo,Nome,'F',false);
end;

function InsereItemNaBaseSqlConnection( SqlConnection : TSqlConnection;
                                        IDPai  : longint;
                                        Tipo   : longint;
                                        Nome   : ansistring;
                                        SequenciaNome : boolean = false) : longint;
begin
  result := InsereItemNabaseESeqNome0(SqlConnection,IDPai,Tipo,Nome,'F',SequenciaNome);
end;

function NovaVersao(Sqlconnection : TSqlConnection; ID : longint): longint;
var
  Qry : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SQLConnection := SqlConnection;
    Qry.SQL.text := 'SELECT MAX(VERSAO) as UltVersao FROM CONTROLEVERSAO '+
                    'WHERE ID = :ID';
    Qry.Params[0].asinteger := ID;
    Qry.Open;
    if Qry.isempty then
      result := 1
    else
      result := Qry.FieldByName('UltVersao').asinteger + 1;
  finally
    Qry.free;
  end;
end;

function LeVersaoDocumento(Sqlconnection : TSqlConnection; id : integer) : integer;
var
  Qry : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SQLConnection := SqlConnection;
    Qry.SQL.text := 'SELECT MAX(VERSAO) as UltVersao FROM CONTROLEVERSAO '+
                    'WHERE ID = :ID';
    Qry.Params[0].asinteger := ID;
    Qry.Open;
    if Qry.isempty then
      result := 0
    else
      result := Qry.FieldByName('UltVersao').asinteger;
  finally
    Qry.free;
  end;
end;

function EncodeInvBase64ForFilenames(i:LongInt):ansistring;
var
  j: integer;
  S:string;
begin
  s := '';
  setlength(s,4);
  s[4] := char((i and $ff000000) shr 24);
  s[3] := char((i and $00ff0000) shr 16);
  s[2] := char((i and $0000ff00) shr 8);
  s[1] := char((i and $000000ff));
  Result := copy(MimeEncodeString(s),1,6);
  for j := 1 to length(Result) do
  if Result[j] = '/' then Result[j] := '_';
end;

function PegaLocalDoEvp : AnsiString;
var
  Qry : TSqlQuery;
  JaConectado : Boolean;
begin
  JaConectado := assigned(SCISConnection) and SCISConnection.Connected;
  if  not JaConectado then
     scislib.AbreConexao;

  if pos('scat.gdb',SCISConnection.Params.values['database']) > 0 then begin
    Qry := TSqlQuery.create(nil);
    try
      Qry.SqlConnection := SCISConnection;
      Qry.Sql.Text := 'select no_local_img from configuracao_scat ';
      Qry.open;
      result := Qry.FieldByName('no_local_img').asstring;
      if not JaConectado then
          scislib.FechaConexao;
  finally
      Qry.free;
    end;
  end;
end;


function incaseinsensitive : boolean;
var
  Qry : TSqlQuery;
  JaConectado : Boolean;
begin
  JaConectado := assigned(SCISConnection) and SCISConnection.Connected;
  if  not JaConectado then
     scislib.AbreConexao;

  if pos('scat.gdb',SCISConnection.Params.values['database']) > 0 then begin
    Qry := TSqlQuery.create(nil);
    try
      Qry.SqlConnection := SCISConnection;
      Qry.Sql.Text := 'select in_case_insensitive from configuracao_scat ';
      Qry.open;
      result := Qry.Fields[0].asstring = 'S';
      if not JaConectado then
          scislib.FechaConexao;
  finally
      Qry.free;
    end;
  end else result := scciconf.LocalArmazenaInsensitive;
end;



function RetornaLocalArmazenaDocImgs : ansistring;
begin
  result := trim(PegaLocalDoEvp);
  if result='' then begin
   if trim(scciconf.LocalArmazenaDocImgs) > '' then begin
     result := TrocaVariaveisDeAmbiente(scciconf.LocalArmazenaDocImgs);
     if ((trim(result) = '') or (not DirectoryExists(result))) and not (trim(result) = LocalArmazenamentoS3) then
       raise exception.create('Configuração de local de armazenamento de documentos e imagens não aponta para um caminho válido.');
   end
   else
    result := '';
  end;
end;

function RetornaFileSystemName(ID : integer; Versao : integer): ansistring;
var
  fileName : TFileName;
  LocalArmazenaDocImgs: AnsiString;
begin
  result := '';
  LocalArmazenaDocImgs := RetornaLocalArmazenaDocImgs;
  if trim(LocalArmazenaDocImgs) <> LocalArmazenamentoS3 then
    result := IncludeTrailingPathDelimiter(LocalArmazenaDocImgs);
  FileName := EncodeInvBase64ForFileNames(ID);
  result := result + copy(FileName,1,1) + PathDelim +
                     copy(FileName,2,1) + PathDelim +
                     copy(FileName,3,1) + PathDelim +
                     FileName;
  if incaseinsensitive then
    result := result + '.' + inttostr(ID) +
                       '.' + intstr2(Versao,3)
  else
    result := ChangeFileExt(result,'.'+intstr2(Versao,3));
end;

function RetornaFileName(ID : integer): ansistring;
var
   Qry : TSqlQuery;
begin
   Result := '';
   Qry := TSqlQuery.create(nil);
   try
     Qry.SqlConnection := GetSqlConnection(pegaDirTab);
     Qry.Sql.add('select nome from SISTARQ');
     Qry.Sql.add('where id =:Id');
     Qry.ParamByName('Id').datatype := ftinteger;
     Qry.ParamByName('Id').asinteger := ID;
     Qry.Open;
     if not Qry.isEmpty then
       Result := Qry.FieldByName('nome').asString;
   finally
     Qry.free;
   end;
end;

procedure GaranteCaminhoFileSystemName(FileName : TFileName);
begin
  if not directoryExists(ExtractFilePath(FileName)) then
    if not ForceDirectories(ExtractFilePath(FileName)) then
      raise exception.create('Não foi possível criar o caminho '+ExtractFilePath(FileName));
end;
{$IFDEF FPC}
function GerarUUID: string;
function GerarRandomHash: string;
var
  i: Integer;
  hashValue: string;
begin
  Randomize;
  hashValue := '';
  for i := 1 to 8 do
  begin
    hashValue := hashValue + IntToHex(Random(16), 1);
  end;
  Result := hashValue;
end;
var
  timeStamp: TDateTime;
  hash: string;
begin
  timeStamp := Now;

  hash := GerarRandomHash;
  Result := Format('%s-%s', [
    FormatDateTime('YYYYMMDDHHNNSSZZZ', timeStamp),
    hash
  ])+'_';
end;

function LeArquivoAmazonS3(FilePathName: AnsiString ; modulo : String = 'DOCUMENTOS'): AnsiString;
var
  Res : TpXMl;
  NomeArq : String;
  usaOrquestrador : boolean;
begin
  Res := Tpxml.create;
  NomeArq := 'RealizarDownloadDocumentoS3.json';
  result := '';
  usaOrquestrador := readUsaOrquestrador();
  try
    if FileExists(NomeArq) then deleteFile(NomeArq);
    if usaOrquestrador then
      shell('informacoesOrquestradorS3 DOWNLOADDOCUMENTOS3 '+modulo+' -a '+FilePathName)
    else  
      shell('informacoesAmazon DOWNLOADDOCUMENTOS3 '+modulo+' -a '+FilePathName);

    if FileExists(NomeArq) then begin
      Res.ParseFile(NomeArq);
      if lib1.StrToBool(Res['success'].asString) then begin
        result := Res['file_path_name'].asString;
        if (result = '') or not FileExists(result) then
          raise exception.create('Erro ao obter arquivo da integração Amazon S3!');
      end
      else if assigned(Res['message']) then
        raise exception.create(Res['message'].asString)
      else raise exception.create('Documento não encontrado na integração Amazon S3!');
    end else raise exception.create('Serviço de integração Amazon não encontrado!');
  finally
    if FileExists(NomeArq) then deleteFile(NomeArq);
    Res.free;
  end;
end;

procedure DeletaArquivoAmazonS3(FilePathName: AnsiString ; modulo : String = 'DOCUMENTOS');
var
  Res : TpXMl;
  ReqBody : TpxmlNode;
  NomeArq : String;
begin
  Res := Tpxml.create;
  NomeArq := 'RealizarDeleteDocumentoS3.json';
  try
    if FileExists(NomeArq) then deleteFile(NomeArq);
    shell('informacoesAmazon DELETADOCUMENTOS3 '+modulo+' -a '+FilePathName);
    if FileExists(NomeArq) then begin
      Res.ParseFile(NomeArq);
      if not lib1.StrToBool(Res['success'].asString) then begin
        raise exception.create('Documento não encontrado na integração Amazon S3!');
      end
      else if assigned(Res['message']) and (not lib1.StrToBool(Res['success'].asString)) then
        raise exception.create(Res['message'].asString);
    end else raise exception.create('Serviço de integração Amazon não encontrado!');
  finally
    if FileExists(NomeArq) then deleteFile(NomeArq);
    Res.free;
  end;
end;

function GravarArquivoNoS3(Modulo,FilePathName: String ; GeraUUID: boolean = true): AnsiString;
var
  Detalhes,
  NomeArq: String;
  Res : TpXMl;
  NomeBucket,
  UrlEndPointBucket,
  ChaveApiBucket,
  UrlS3,
  file_name : AnsiString;
begin
  NomeArq := 'RealizarUploadDocumentoS3.json';
  result := '';
  Res := Tpxml.create;
  try
    if GeraUUID then
      file_name := GerarUUID+extractFileName(FilePathName)
    else
      file_name := extractFileName(FilePathName);
    if FileExists(NomeArq) then deleteFile(NomeArq);
    shell('informacoesAmazon UPLOADDOCUMENTOS3 '+Modulo+' '+file_name+' -a '+FilePathName);
    if FileExists(NomeArq) then begin
      Res.ParseFile(NomeArq);
      if Res['success'].AsBoolean then begin
        UrlS3 := Res['url_s3'].asString;
        result := UrlS3;
      end
      else if assigned(Res['message']) then
        raise exception.create(Res['message'].asString)
      else
        raise exception.create('Falha no serviço de integracao Amazon S3!');
    end else raise exception.create('Serviço de integracao Amazon S3 não encontrado!');
  finally
    if FileExists(NomeArq) then deleteFile(NomeArq);
    Res.free;
  end;
end;

procedure InsereVersaoAmazonS3(FilePathName: AnsiString);
begin
  // Não vou gerar o UUID nesse modo pois o hash do FilePathName já garante que o documento vai ser único!
  GravarArquivoNoS3('DOCUMENTOS',FilePathName,false{GeraUUID});
end;
{$ENDIF} 
function InsereVersao(ID, UltVersao : longint; Texto : ansistring): longint;
var
  Stream : TMemoryStream;
  Qry : TSqlQuery;
  Compactado : TmemoryStream;
  FileName : TFilename;
  LocalArmazenaDocImgs : TFileName;
  size,sizec : integer;
  TpGravacao: smallInt;
begin
  //Size := 0;
  SizeC := 0;
  FileName := '';
  LocalArmazenaDocImgs := RetornaLocalArmazenaDocImgs;
  Stream := TMemoryStream.create;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SQLConnection := SCISConnection;
    result := NovaVersao(SCISConnection,ID);
    if result <= UltVersao then
      raise exception.create('Outro usuario já modificou este documento');

    if trim(LocalArmazenaDocImgs) > '' then begin
      Qry.SQl.text := 'INSERT INTO CONTROLEVERSAO (ID,VERSAO,TP_GRAVACAO,ALT_USUARIO,ALT_DATA,COMPACTADO,NOME,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO) VALUES '+
                      '(:ID,:VERSAO,:TP_GRAVACAO,:ALT_USUARIO,:ALT_DATA,:COMPACTADO,:NOME,:NU_TAMANHO_ARQUIVO,:NU_TAMANHO_COMPACTADO)';
      Qry.Params[0].asinteger := ID;
      Qry.Params[1].asinteger := result;
      Qry.Params[6].asString := RetornaFileName(ID);
      Stream.writebuffer(texto[1],length(texto));
      size := Stream.Size;
      Stream.position := 0;
      Compactado := TMemoryStream.create;
      
      try
        FileName := RetornaFileSystemName(ID,result);
        GaranteCaminhoFileSystemName(FileName);
        if CompactaStream(Stream,Compactado) then begin
          Compactado.Position := 0;
          Compactado.SaveToFile(FileName);
          sizec := Compactado.Size;
          Qry.Params[5].asstring := BooleanToSqlBoolean(true);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end
        else begin
          Stream.position := 0;
          Stream.SaveToFile(FileName);
          
          Qry.Params[5].asstring := BooleanToSqlBoolean(false);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end;
      finally
        Compactado.free;
      end;
      {$IFDEF FPC}
      if LocalArmazenaDocImgs = LocalArmazenamentoS3 then begin
        TpGravacao := TPGravacao_AmazonS3;
        InsereVersaoAmazonS3(FileName);
      end
      else {$ENDIF}
        TpGravacao := TPGravacao_FileSystem;
      Qry.Params[2].asinteger := TpGravacao;
      Qry.Params[3].asstring := PegaUsuario;
      Qry.Params[4].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ExecSql;
    end
    else begin
      Qry.SQl.text := 'INSERT INTO CONTROLEVERSAO (ID,VERSAO,DADO,ALT_USUARIO,ALT_DATA,COMPACTADO,NOME,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO) VALUES '+
                      '(:ID,:VERSAO,:DADO,:ALT_USUARIO,:ALT_DATA,:COMPACTADO,:NOME,:NU_TAMANHO_ARQUIVO,:NU_TAMANHO_COMPACTADO)';
      Qry.Params[0].asinteger := ID;
      Qry.Params[1].asinteger := result;
      Qry.Params[6].asString := RetornaFileName(ID);
      Stream.writebuffer(texto[1],length(texto));
      size := Stream.Size;
      Stream.position := 0;
      Compactado := TMemoryStream.create;
      try
        if CompactaStream(Stream,Compactado) then begin
          sizec := Compactado.Size;
          Compactado.Position := 0;
          Qry.Params[2].loadfromstream(Compactado,ftblob);
          Qry.Params[5].asstring := BooleanToSqlBoolean(true);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end
        else begin
          Stream.position := 0;
          Qry.Params[2].loadfromstream(Stream,ftblob);
          Qry.Params[5].asstring := BooleanToSqlBoolean(false);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end;
      finally
        Compactado.free;
      end;
      Qry.Params[3].asstring := PegaUsuario;
      Qry.Params[4].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ExecSql;
    end;
  finally
    Qry.free;
    Stream.free;
  end;
end;

function  InsereVersaoBinario(SqlConnection : TSqlConnection; 
                              ID, UltVersao : longint; 
                              Stream : TStream;
                              MiniaturaStr : AnsiString = '';
                              FileNameGravacao : Ansistring = ''): longint;
var
  Qry : TSqlQuery;
  Compactado : TMemoryStream;
  FileName : TFileName;
  FileStream : TFileStream;
  LocalArmazenaDocImgs : TFileName;
  size,sizec : integer;
  MiniaturaStream: TStringStream;
  TpGravacao: SmallInt;
  ansi : ansistring;
begin
  //Size := 0;
  SizeC := 0;
  LocalArmazenaDocImgs := RetornaLocalArmazenaDocImgs;
  Qry := TSqlQuery.create(nil);
  MiniaturaStream := nil;
  try
    Qry.SQLConnection := SqlConnection;
    result := NovaVersao(SqlConnection,ID);
    if (UltVersao > -1) and (result <= UltVersao) then
      raise exception.create('Outro usuario já modificou este documento');
    size := Stream.Size;
    if trim(LocalArmazenaDocImgs) > '' then begin
      ansi := 'INSERT INTO CONTROLEVERSAO (ID,VERSAO,TP_GRAVACAO,ALT_USUARIO,ALT_DATA,COMPACTADO,NOME,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO,TE_IMAGEM_REDUZIDA, ';
      ansi := ansi + '  HASH_DOCUMENTO_MIGRADO ) VALUES ';
      ansi := ansi + '(:ID,:VERSAO,:TP_GRAVACAO,:ALT_USUARIO,:ALT_DATA,:COMPACTADO,:NOME,:NU_TAMANHO_ARQUIVO,:NU_TAMANHO_COMPACTADO,:TE_IMAGEM_REDUZIDA,';
      ansi := ansi + '  :HASH_DOCUMENTO_MIGRADO )';
      Qry.SQl.text := ansi;
      Qry.Params[0].asinteger := ID;
      Qry.Params[1].asinteger := result;
      if FileNameGravacao > '' then
        Qry.Params[6].asString := FileNameGravacao
      else
        Qry.Params[6].asString := RetornaFileName(ID);
      Compactado := TMemoryStream.create;
      try
        FileName := RetornaFileSystemName(ID,result);
        GaranteCaminhoFileSystemName(FileName);
        if CompactaStream(Stream,Compactado) then begin
          sizec := Compactado.Size;
          Compactado.Position := 0;
          Compactado.SaveToFile(FileName);
          Qry.Params[5].asstring := BooleanToSqlBoolean(true);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end
        else begin
          FileStream := TFileStream.create(FileName,FmCreate);
          try
            FileStream.copyfrom(Stream,0);
          finally
            FileStream.free;
          end;
          Qry.Params[5].asstring := BooleanToSqlBoolean(false);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end;
        MiniaturaStream := TStringStream.create(MiniaturaStr);
        MiniaturaStream.position := 0;
        Qry.Params[9].loadfromstream(MiniaturaStream, ftblob);
      finally
        Compactado.free;
        MiniaturaStream.free;
      end;
      {$IFDEF FPC}
      if LocalArmazenaDocImgs = LocalArmazenamentoS3 then begin
        TpGravacao := TPGravacao_AmazonS3;
        InsereVersaoAmazonS3(FileName);
      end
      else {$ENDIF}
        TpGravacao := TPGravacao_FileSystem;

      {$IFDEF FPC}
      if LocalArmazenaDocImgs = LocalArmazenamentoS3 then
        Qry.paramByName('HASH_DOCUMENTO_MIGRADO').asString := FileName
      else {$ENDIF}
        Qry.paramByName('HASH_DOCUMENTO_MIGRADO').asString := '';

      Qry.Params[2].asinteger := TpGravacao;
      Qry.Params[3].asstring := PegaUsuario;
      Qry.Params[4].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ExecSql;
    end
    else begin
      Qry.SQl.text := 'INSERT INTO CONTROLEVERSAO (ID,VERSAO,DADO,ALT_USUARIO,ALT_DATA,COMPACTADO,NOME,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO,TE_IMAGEM_REDUZIDA) VALUES '+
                      '(:ID,:VERSAO,:DADO,:ALT_USUARIO,:ALT_DATA,:COMPACTADO,:NOME,:NU_TAMANHO_ARQUIVO,:NU_TAMANHO_COMPACTADO,:TE_IMAGEM_REDUZIDA)';
      Qry.Params[0].asinteger := ID;
      Qry.Params[1].asinteger := result;
      if FileNameGravacao > '' then
        Qry.Params[6].asString := FileNameGravacao
      else
        Qry.Params[6].asString := RetornaFileName(ID);
      Compactado := TMemoryStream.create;
      try
        if CompactaStream(Stream,Compactado) then begin
          sizec := Compactado.Size;
          Compactado.position := 0;
          Qry.Params[2].loadfromstream(Compactado,ftblob);
          Qry.Params[5].asstring := BooleanToSqlBoolean(true);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end
        else begin
          Stream.position := 0;
          Qry.Params[2].loadfromstream(Stream,ftblob);
          Qry.Params[5].asstring := BooleanToSqlBoolean(false);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end;
        MiniaturaStream := TStringStream.create(MiniaturaStr);
        MiniaturaStream.position := 0;
        Qry.Params[9].loadfromstream(MiniaturaStream, ftblob);
      finally
        Compactado.free;
        MiniaturaStream.free;
      end;
      Qry.Params[3].asstring := PegaUsuario;
      Qry.Params[4].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ExecSql;
    end;
  finally
    Qry.free;
  end;
end;

function  InsereVersaoBinario(SqlConnection : TSqlConnection; ID, UltVersao : longint; filename : TFilename;FileNameGravacao : Ansistring = ''): longint;
var
  FileStream : TFileStream;
begin
  FileStream := TFileStream.create(FileName,FmOpenRead  or fmShareDenyNone);
  try
    if FileNameGravacao>'' then
      result := InsereVersaoBinario(SqlConnection,ID,UltVersao,FileStream,'',FileNameGravacao)
    else
      result := InsereVersaoBinario(SqlConnection,ID,UltVersao,FileStream);
  finally
    FileStream.free;
  end;
end;

function  InsereVersaoBinario(ID, UltVersao : longint; filename : TFilename): longint;
begin
  result := InsereVersaoBinario(SCISConnection,ID,UltVersao,FileName);
end;


function InsereItemNaBase( SqlConnection : TSqlConnection;
                           IDPai  : longint;
                           Tipo   : longint;
                           Nome   : ansistring;
                           NO_Descricao : str255 = '';
                           CO_Doc_Dossie : longint = 0;
                           Co_Tipo_Arquivo : longint = 0;
                           Co_Identificacao : longint = 0) : longint;
var
  Qry,
  QryPai : TSqlQuery;
  StField,
  StParam : string;
begin
  StField := '';
  StParam := '';
  if NO_Descricao > '' then begin
    StField := ',no_descricao';
    StParam := ',:no_descricao';
  end;
  if CO_Doc_Dossie > 0 then begin
    StField := StField + ',co_doc_dossie';
    StParam := StParam + ',:co_doc_dossie';
  end;
  result := LeGenerator(SqlConnection,id_SistArq);
  Qry    := TSqlQuery.create(nil);
  QryPai := TSqlQuery.create(nil);
  try
    Qry.SQLConnection    := SqlConnection;
    QryPai.SQLConnection := SqlConnection;
    if  Tipo = 2 then begin
      QryPai.Sql.Add('SELECT IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO,');
      QryPai.Sql.add( '      IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA');
      QryPai.Sql.Add('FROM SISTARQ');
      QryPai.Sql.Add('WHERE ID = ' + IntToStr(IDPai));
      QryPai.Open;
      if  not QryPai.Eof then begin
        Qry.SQL.Add('INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO,CO_TIPO_ARQUIVO, CO_IDENTIFICACAO,');
        Qry.SQL.Add('IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO,');
        Qry.SQL.Add('IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA'+StField+' ) VALUES ');
        Qry.SQL.Add('(:ID,:IDPAI,:NOME,:TIPO,:CO_TIPO_ARQUIVO,:CO_IDENTIFICACAO,');
        Qry.SQL.Add(' :IN_CRIA_VERSAO_ATUALIZADA, :IN_DOCUMENTO_OCULTO,');
        Qry.SQL.Add(' :IN_CONTROLE_VERSAO, :IN_DOCUMENTO_SO_LEITURA'+StParam+')');
        Qry.Params[6].AsString := QryPai.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').AsString;
        Qry.Params[7].AsString := QryPai.FieldByName('IN_DOCUMENTO_OCULTO').AsString;
        Qry.Params[8].AsString := QryPai.FieldByName('IN_CONTROLE_VERSAO').AsString;
        Qry.Params[9].AsString := QryPai.FieldByName('IN_DOCUMENTO_SO_LEITURA').AsString;
      end
      else
        Qry.SQL.text := 'INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO,CO_TIPO_ARQUIVO,CO_IDENTIFICACAO'+StField+') VALUES '+
                        '(:ID,:IDPAI,:NOME,:TIPO,:CO_TIPO_ARQUIVO,:CO_IDENTIFICACAO'+StParam+')';
    end
    else
      Qry.SQL.text := 'INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO,CO_TIPO_ARQUIVO,CO_IDENTIFICACAO'+StField+') VALUES '+
                      '(:ID,:IDPAI,:NOME,:TIPO,:CO_TIPO_ARQUIVO,:CO_IDENTIFICACAO'+StParam+')';

    Qry.Params[0].asinteger := result;
    Qry.Params[1].asinteger := IDPai;
    Qry.Params[2].asstring  := Nome;
    Qry.Params[3].asinteger := Tipo;
    Qry.Params[4].asinteger := Co_Tipo_Arquivo;
    Qry.Params[5].asinteger := Co_Identificacao;

    if NO_Descricao > '' then
      Qry.ParamByName('no_descricao').asstring := NO_Descricao;
    if CO_Doc_Dossie > 0 then
      Qry.ParamByName('co_doc_dossie').asinteger := CO_Doc_Dossie;
    try
      Qry.ExecSql;
      idRaizDoDoc(Sqlconnection,result);
    except
      on e : exception do begin
        if (pos('duplicate value',e.message) > 0 {Firebird}) or
           (pos('duplicate key',e.message) > 0 {Mssql}) or
           (pos('violada',e.message) > 0 {Oracle}) then
          raise exception.create('Já existe arquivo com este nome.')
        else
          raise;
      end;
    end;
  finally
    Qry.free;
    QryPai.Free;
  end;
end;
function GravaDocumentoTemporario(FilePathName: TFilename; FileNameFinal,SessionKey: string):LongInt;
var
  ID,Versao, NovaVersao : LongInt;
  SqlConnection: TSqlConnection;
  Transaction   : TTransactionDesc;
begin
  Versao :=0;
  NovaVersao :=0;
  Result := 0;
  SqlConnection := GetSqlConnection(PegaDirTab);
  try
    Transaction.TransactionID := 10;
    Transaction.IsolationLevel := xilREADCOMMITTED;
    SqlConnection.StartTransaction(Transaction);
    ID   := InsereItemTempNaBase(SqlConnection,FileNameFinal);
    GravaBinarioVersao(SqlConnection,
                        ID,
                        Versao,
                        FilePathName,
                        NovaVersao
                        );
    InsereIdentificadorItemTempNaBase(SqlConnection,ID,SessionKey);
    try
      SqlConnection.Commit(Transaction);
    except
      SqlConnection.Rollback(Transaction);
      raise;
    end;
    Result := ID;
  finally
    if (FilePathName > '') and FileExists(FilePathName) then
      deletefile(FilePathName);
  end;
end;

procedure InsereIdentificadorItemTempNaBase(SqlConnection : TSqlConnection;
                                            ID: longint;SessionKey: String);
var
  Qry : TSqlQuery;
begin
  
  if (trim(SessionKey) = '') or (ID <= 0)   then
    raise exception.create('SessionKey ou ID do Documento não informados!')
  else begin
    Qry := TSqlQuery.create(nil);
    Qry.SQLConnection    := SqlConnection;
    Qry.SQL.Add('INSERT INTO SISTARQ_TEMPORARIO (ID,SESSIONKEY)');
    Qry.SQL.Add('VALUES (:ID,:SESSIONKEY)');
    Qry.ParamByName('ID').datatype         := ftinteger;
    Qry.ParamByName('SESSIONKEY').datatype := ftstring;
    Qry.ParamByName('ID').asInteger        := ID;
    Qry.ParamByName('SESSIONKEY').asString := SessionKey;
    Qry.ExecSql;
    Qry.Sql.Clear;
  end;
end;

function InsereItemTempNaBase(SqlConnection : TSqlConnection;
                              Nome: String): LongInt;
begin
  Result := InsereItemNaBase(SqlConnection,0,0,Nome,'N','T','N','N','',true);
end;

function InsereItemNaBase( SqlConnection : TSqlConnection;
                           IDPai  : longint;
                           Tipo   : longint;
                           Nome   : ansistring;
                           IN_CRIA_VERSAO_ATUALIZADA,
                           IN_DOCUMENTO_OCULTO,
                           IN_CONTROLE_VERSAO,
                           IN_DOCUMENTO_SO_LEITURA : string;
                           TE_OBSERVACAO_ARQUIVO : ansistring;
                           NO_Descricao : str255;
                           CO_Doc_Dossie : longint;
                           ItemRaiz : boolean = false) : longint;
var
  Qry : TSqlQuery;
  StField,
  StParam : string;
  n : integer;
{$IFDEF XE}
  stream : tstringstream;
{$ENDIF}
begin
 Randomize; 

  // vamos gerar um número aleatório entre 0 e 10 
   n := Random(10); 
  StParam := '';
  StField := '';
  if NO_Descricao > '' then begin
    StField := ',no_descricao';
    StParam := ',:no_descricao';
  end;
  if CO_Doc_Dossie > 0 then begin
    StField := StField + ',co_doc_dossie';
    StParam := StParam + ',:co_doc_dossie';
  end;
  result := LeGenerator(SqlConnection,id_SistArq);
  Qry    := TSqlQuery.create(nil);
  try
    Qry.SQLConnection    := SqlConnection;
    if Tipo = 2 then
      if ItemRaiz then
        raise exception.create('Item raiz não pode ser um documento');
    Qry.SQL.Add('INSERT INTO SISTARQ (ID,IDPAI,NOME,TIPO,');
    Qry.SQL.Add('IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO,');
    Qry.SQL.Add('IN_CONTROLE_VERSAO, IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO'+StField+' ) VALUES ');
    Qry.SQL.Add('(:ID,:IDPAI,:NOME,:TIPO,');
    Qry.SQL.Add(' :IN_CRIA_VERSAO_ATUALIZADA, :IN_DOCUMENTO_OCULTO,');
    Qry.SQL.Add(' :IN_CONTROLE_VERSAO, :IN_DOCUMENTO_SO_LEITURA,:TE_OBSERVACAO_ARQUIVO'+StParam+')');
    Qry.Params[0].asinteger := result;
    if ItemRaiz then
      Qry.Params[1].asinteger := result
    else
      Qry.Params[1].asinteger := IDPai;
    Qry.Params[2].asstring  := Nome;
    Qry.Params[3].asinteger := Tipo;
    Qry.Params[4].AsString := IN_CRIA_VERSAO_ATUALIZADA;
    Qry.Params[5].AsString := IN_DOCUMENTO_OCULTO;
    Qry.Params[6].AsString := IN_CONTROLE_VERSAO;
    Qry.Params[7].AsString := IN_DOCUMENTO_SO_LEITURA;
{$IFDEF XE}
   Stream := TStringStream.create(TE_OBSERVACAO_ARQUIVO);
    try
      Stream.Position := 0;
      Qry.Params[8].loadfromstream(stream,ftblob);
    finally
      Stream.free;
    end;
{$ELSE}
    Qry.Params[8].asBlob := BytesOf( TE_OBSERVACAO_ARQUIVO+inttostr(n));
{$ENDIF}
    if NO_Descricao > '' then
      Qry.paramByName('NO_DESCRICAO').asstring := NO_Descricao;
    if CO_Doc_Dossie > 0 then
      Qry.paramByName('CO_DOC_DOSSIE').asinteger := CO_Doc_Dossie;
    try
      Qry.ExecSql;
      idRaizDoDoc(Sqlconnection,result);
    except
      on e : exception do begin
        if (pos('duplicate value',e.message) > 0 {Firebird}) or
           (pos('duplicate key',e.message) > 0 {Mssql}) or
           (pos('violada',e.message) > 0 {Oracle}) then
          raise exception.create('Ja existe arquivo com este nome:'+  Nome)
        else
          raise;
      end;
    end;
  finally
    Qry.free;
  end;
end;

function InsereItemNaBase( SqlConnection : TSqlConnection;
                           IDPai  : longint;
                           Tipo   : longint;
                           Nome   : ansistring;
                           IN_CRIA_VERSAO_ATUALIZADA,
                           IN_DOCUMENTO_OCULTO,
                           IN_CONTROLE_VERSAO,
                           IN_DOCUMENTO_SO_LEITURA : string;
                           TE_OBSERVACAO_ARQUIVO : ansistring;
                           ItemRaiz : boolean = false) : longint;
begin
  result := InsereItemNabase(SqlConnection,IDPai,Tipo,Nome,IN_CRIA_VERSAO_ATUALIZADA,
                             IN_DOCUMENTO_OCULTO,IN_CONTROLE_VERSAO,IN_DOCUMENTO_SO_LEITURA,
                             TE_OBSERVACAO_ARQUIVO,'',0,ItemRaiz);
end;

function InsereVersao(SqlConnection : TSqlConnection;
                      ID, UltVersao : longint; Texto : ansistring): longint;
var
  Stream : TMemoryStream;
  Qry : TSqlQuery;
  Compactado : TMemoryStream;
  FileName : TFileName;
  size,sizec : integer;
begin
  //Size := 0;
  SizeC := 0;

  Stream := TMemoryStream.create;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SQLConnection := SqlConnection;
    Qry.SQL.text := 'SELECT MAX(VERSAO) as UltVersao FROM CONTROLEVERSAO '+
                    'WHERE ID = :ID';
    Qry.Params[0].asinteger := ID;
    Qry.Open;
    if Qry.isempty then
      result := 1
    else
      result := Qry.FieldByName('UltVersao').asinteger + 1;
    Qry.Close;
    if result <= UltVersao then
      raise exception.create('Outro usuario já modificou este documento');

    if trim(RetornaLocalArmazenaDocImgs) > '' then begin
      Qry.SQl.text := 'INSERT INTO CONTROLEVERSAO (ID,VERSAO,TP_GRAVACAO,ALT_USUARIO,ALT_DATA,COMPACTADO,NOME,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO) VALUES '+
                      '(:ID,:VERSAO,:TP_GRAVACAO,:ALT_USUARIO,:ALT_DATA,:COMPACTADO,:NOME,:NU_TAMANHO_ARQUIVO,:NU_TAMANHO_COMPACTADO)';
      Qry.Params[0].asinteger := ID;
      Qry.Params[1].asinteger := result;
      Qry.Params[6].asString := RetornaFileName(ID);
      Stream.writebuffer(texto[1],length(texto));
      size := Stream.Size;
      Stream.position := 0;
      Compactado := TMemoryStream.create;
      try
        FileName := RetornaFileSystemName(ID,result);
        GaranteCaminhoFileSystemName(FileName);
        if CompactaStream(Stream,Compactado) then begin
          sizec := Compactado.Size;
          Compactado.Position := 0;
          Compactado.SaveToFile(FileName);
          Qry.Params[2].asinteger := TPGravacao_FileSystem;
          Qry.Params[5].asstring := BooleanToSqlBoolean(true);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end
        else begin
          Stream.position := 0;
          Stream.SaveToFile(Filename);
          Qry.Params[2].asinteger := TPGravacao_FileSystem;
          Qry.Params[5].asstring := BooleanToSqlBoolean(false);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end;
      finally
        Compactado.free;
      end;
      Qry.Params[3].asstring := PegaUsuario;
      Qry.Params[4].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ExecSql;
    end
    else begin
      Qry.SQl.text := 'INSERT INTO CONTROLEVERSAO (ID,VERSAO,DADO,ALT_USUARIO,ALT_DATA,COMPACTADO,NOME,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO) VALUES '+
                      '(:ID,:VERSAO,:DADO,:ALT_USUARIO,:ALT_DATA,:COMPACTADO,:NOME,:NU_TAMANHO_ARQUIVO,:NU_TAMANHO_COMPACTADO)';
      Qry.Params[0].asinteger := ID;
      Qry.Params[1].asinteger := result;
      Qry.Params[6].asString := RetornaFileName(ID);
      Stream.writebuffer(texto[1],length(texto));
      size := Stream.Size;
      Stream.position := 0;
      Compactado := TMemoryStream.create;
      try
        if CompactaStream(Stream,Compactado) then begin
          sizec := Compactado.Size;
          Compactado.Position := 0;
          Qry.Params[2].loadfromstream(Compactado,ftblob);
          Qry.Params[5].asstring := BooleanToSqlBoolean(true);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end
        else begin
          Stream.position := 0;
          Qry.Params[2].loadfromstream(Stream,ftblob);
          Qry.Params[5].asstring := BooleanToSqlBoolean(false);
          Qry.Params[8].asInteger := SizeC;
          Qry.Params[7].asInteger := Size;
        end;
      finally
        Compactado.free;
      end;
      Qry.Params[3].asstring := PegaUsuario;
      Qry.Params[4].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      Qry.ExecSql;
    end;
  finally
    Qry.free;
    Stream.free;
  end;
end;

function LeIDdoDiretorio(SqlConnection : TSqlConnection; Pasta : string; idpai : integer = 0): integer;
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Add('SELECT ID,NOME FROM SISTARQ');
    Qry.Sql.add('WHERE (IDPAI = :idpai) and (TIPO = 1)');
    Qry.ParamByName('idpai').asinteger := idpai;
    Qry.open;
    result := -1;
    while not Qry.Eof and (result < 0) do begin
      if uppercase(Pasta) = uppercase(Qry.FieldByName('NOME').asstring) then
        result := Qry.FieldByName('ID').asinteger;
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;

function ObtemIdPai(SqlConnection : TsqlConnection ; id : integer):integer;
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Add('SELECT IDPAI FROM SISTARQ');
    Qry.Sql.add('WHERE (ID = :id)');
    Qry.ParamByName('id').asinteger := id;
    Qry.open;
    result := -1;
    if not Qry.Eof then begin
      result := Qry.FieldByName('IDPAI').asinteger;
    end;
  finally
    Qry.free;
  end;
end;

procedure CopiaBinarioDocumento(SqlConnection : TSqlConnection; IDOrigem,IdDestino : integer; Prepare : boolean = false);
var
  TempFilename : ansistring;
begin
  // se os documentos ficarem fisicamente no disco, não tenho opção
  // tenho que copiar os arquivos baixando para o disco e depois reincluíndo
  // mas se os documentos ficarem no blob da tabela VERSAODOCUMENTO, posso apenas
  // apenas duplicar o registro diretamente pelo sql, evitando assim o processo
  // de baixar o binário. Sol. 69697
  
  if trim(scciconf.LocalArmazenaDocImgs) > '' then begin
    TempFilename := makeTempFileName;
    try
      SaveDocumentoToFile(GetSqlConnection(PegaDirAtv),IDOrigem,TempFilename);
      InsereVersaoBinario(GetSqlConnection(PegaDirAtv),IdDestino,0,TempFileName);
    finally
      DeleteFile(TempFileName);
    end;
  end
  else begin

    if Assigned(gQryCopiaBinarioDocumento) and
      (not Prepare or (gQryCopiaBinarioDocumento.SqlConnection <> SqlConnection)) then
      FreeAndNil(gQryCopiaBinarioDocumento);
    
    if not Assigned(gQryCopiaBinarioDocumento) then begin
      gQryCopiaBinarioDocumento := TSqlQuery.create(nil);
      gQryCopiaBinarioDocumento.SqlConnection := SqlConnection;
      gQryCopiaBinarioDocumento.Sql.BeginUpdate;
      try
        gQryCopiaBinarioDocumento.Sql.add('INSERT INTO CONTROLEVERSAO (ID,VERSAO,DADO,ALT_USUARIO,ALT_DATA,COMPACTADO,NU_TAMANHO_ARQUIVO,NU_TAMANHO_COMPACTADO)');
        gQryCopiaBinarioDocumento.Sql.add('select :IdDestino,1,CV1.DADO,:usuario,:data,CV1.COMPACTADO,CV1.NU_TAMANHO_ARQUIVO,CV1.NU_TAMANHO_COMPACTADO from controleversao CV1');
        gQryCopiaBinarioDocumento.Sql.add('where CV1.id=:IdOrigem and');
        gQryCopiaBinarioDocumento.Sql.add('CV1.versao = (select max(CV2.versao) from controleversao CV2 where CV2.id=CV1.id)');
      finally
        gQryCopiaBinarioDocumento.Sql.EndUpdate;
      end;
      gQryCopiaBinarioDocumento.parambyname('IdDestino').datatype := ftinteger;
      gQryCopiaBinarioDocumento.parambyname('usuario').datatype := ftstring;
      gQryCopiaBinarioDocumento.parambyname('data').datatype := ftdatetime;
      gQryCopiaBinarioDocumento.parambyname('IdOrigem').datatype := ftinteger;
      gQryCopiaBinarioDocumento.parambyname('IdOrigem').datatype := ftinteger;
      gQryCopiaBinarioDocumento.Prepared := Prepare;
    end;

    try
      gQryCopiaBinarioDocumento.parambyname('IdDestino').asinteger := IdDestino;
      gQryCopiaBinarioDocumento.parambyname('usuario').asstring := PegaUsuario;
      gQryCopiaBinarioDocumento.parambyname('data').asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
      gQryCopiaBinarioDocumento.parambyname('IdOrigem').asinteger := IdOrigem;
      gQryCopiaBinarioDocumento.ExecSql;
    finally
      if not Prepare then
        FreeAndNil(gQryCopiaBinarioDocumento);
    end;

  end;
end;


procedure ListaArquivosDoDiretorio(SqlConnection : TSqlConnection;
                                   Pasta : string; Arquivos : Tstrings);
var
  Qry : TSQLQuery;
  ID : integer;
begin
  Qry      := TSQLQuery.create(nil);
  try
    ID := LeIDdoDiretorio(SqlConnection,Pasta);
    if ID > 0 then begin
      Qry.SqlConnection := SqlConnection;
      Qry.Sql.Add('SELECT ID,NOME FROM SISTARQ');
      Qry.Sql.add('WHERE (IDPAI = :IDPAI) and (TIPO = 2)');
      Qry.ParamByName('IDPAI').asinteger := ID;
      Qry.open;
      while not Qry.Eof do begin
        Arquivos.add(Qry.FieldByName('NOME').asstring+'='+
                     Qry.FieldByName('ID').asstring);
        Qry.Next;
      end;
    end;
  finally
    Qry.free;
  end;
end;


procedure ListaArquivosDoDiretorio(SqlConnection : TSqlConnection;
                                   idpai : integer; Arquivos : Tstrings);
var
  Qry : TSQLQuery;
begin
  Qry      := TSQLQuery.create(nil);
  try
    if IDpai > 0 then begin
      Qry.SqlConnection := SqlConnection;
      Qry.Sql.Add('SELECT ID,NOME FROM SISTARQ');
      Qry.Sql.add('WHERE (IDPAI = :IDPAI) and (TIPO = 2)');
      Qry.ParamByName('IDPAI').asinteger := IDpai;
      Qry.open;
      while not Qry.Eof do begin      
        Arquivos.add(Qry.FieldByName('NOME').asstring+'='+
                     Qry.FieldByName('ID').asstring);
        Qry.Next;
      end;
    end;
  finally
    Qry.free;
  end;
end;



procedure AlteraNomeDoc (ID : Integer;  Nome : String);
var Qry : TSqlQuery;
    JaConectado : Boolean;
begin
    JaConectado := assigned(SCISConnection) and SCISConnection.Connected;
    if not JaConectado then
      scislib.AbreConexao;
    Qry := TSqlQuery.create(nil);
    try
      Qry.SqlConnection := SCISConnection;
      Qry.Sql.Text := 'update sistarq '+
                      'set nome = :nome '+
                      'where id = :id';
      Qry.params[0].asstring  := Nome;
      Qry.params[1].asinteger := ID;
      try
{$IFDEF FPC}
        Qry.ExecSql;
{$ELSE}
        if Qry.ExecSql = 0 then
          raise exception.create('Nao foi possivel renomear');
{$ENDIF}
      except
        on e : exception do begin
          if (pos('duplicate value',e.message) > 0 {Firebird}) or
             (pos('duplicate key',e.message) > 0 {Mssql}) or
             (pos('violada',e.message) > 0 {Oracle}) then
            raise exception.create('Ja existe arquivo com este nome.')
          else raise;
        end;
      end;
    finally
      if not JaConectado then
        scislib.FechaConexao;
      Qry.free;
    end;
end;

procedure AlteraDetalhesItem(SqlConnection : TSqlconnection;
                             ID : Integer;
                             Nome : String;
                             NO_Descricao : str255;
                             CO_Doc_Dossie : longint);
var
  Qry : TSqlQuery;
  StDocDossie : string;
begin
  StDocDossie := '';
  if CO_Doc_Dossie > 0 then
    stDocDossie := 'CO_DOC_DOSSIE = :CO_DOC_DOSSIE'
  else
    stDocDOssie := 'CO_DOC_DOSSIE = NULL';
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Text := 'update sistarq '+
                    'set nome = :nome, '+
                    'no_descricao = :no_descricao, '+
                    stDocDossie+
                    ' where id = :id';
    Qry.parambyname('Nome').asstring  := Nome;
    Qry.parambyname('ID').asinteger := ID;
    Qry.ParamByname('NO_DESCRICAO').asstring := NO_Descricao;
    if CO_Doc_Dossie > 0 then
      Qry.ParamByname('CO_DOC_DOSSIE').asinteger := CO_Doc_Dossie;
    try
{$IFDEF FPC}
      Qry.ExecSql;
{$ELSE}
      if Qry.ExecSql = 0 then
        raise exception.create('Nao foi possível atualizar os detalhes');
{$ENDIF}
    except
      on e : exception do begin
        if (pos('duplicate value',e.message) > 0 {Firebird}) or
           (pos('duplicate key',e.message) > 0 {Mssql}) or
           (pos('violada',e.message) > 0 {Oracle}) then
          raise exception.create('Ja existe arquivo com este nome.')
        else raise;
      end;
    end;
  finally
    Qry.free;
  end;
end;

function NomeDocumento(SqlConnection : TSqlconnection; ID : integer) : string;
var
  Qry : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Text := 'select nome from sistarq where id = :id';
    Qry.parambyname('ID').asinteger := ID;
    Qry.open;
    if Qry.Isempty then
      raise exception.create('Documento não encontrado');
    result := Qry.FieldByName('Nome').asstring;
  finally
    Qry.free;
  end;
end;

procedure LeDetalhesItem(SqlConnection : TSqlconnection; ID : Integer; Buffer : TpMemory);
var
  Qry : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Text := 'select ID, IDPai, nome, NO_DESCRICAO, CO_DOC_DOSSIE from sistarq '+
                    ' where id = :id';
    Qry.parambyname('ID').asinteger := ID;
    Qry.open;
    if Qry.Isempty then
      raise exception.create('Item não encontrado');
    Buffer.addint('ID',Qry.FieldByName('ID').asinteger);
    Buffer.addval('Nome',Qry.FieldByName('Nome').asstring);
    buffer.addval('NO_Descricao',Qry.FieldByName('NO_Descricao').asstring);
    buffer.addint('CO_Doc_Dossie',Qry.FieldByName('CO_Doc_Dossie').asinteger);
  finally
    Qry.free;
  end;
end;

procedure LeDetalhesDocumento(    SqlConnection : TSqlconnection;
                                  ID : Integer;
                              Var Nome : string;
                              Var CodHierarquia : integer);
var
  Qry : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Text := 'select nome, CO_HIERARQUIA_DOCUMENTO from sistarq '+
                    ' where id = :id and TIPO=2';
    Qry.parambyname('ID').asinteger := ID;
    Qry.open;
    if Qry.Isempty then
      raise exception.create('Documento não encontrado');
    Nome := Qry.FieldByName('Nome').asstring;
    CodHierarquia := Qry.FieldByName('CO_HIERARQUIA_DOCUMENTO').asinteger;
  finally
    Qry.free;
  end;
end;

procedure VerificaCriterios(SqlConnection : TSqlConnection;
                            ID : longint;
                            Var CriaVersao,
                                ControleVersao,
                                GravaNovaVersao : boolean);
var
  Qry             : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Add('SELECT S.IN_CRIA_VERSAO_ATUALIZADA, ');
    Qry.Sql.add( '      S.IN_CONTROLE_VERSAO');
    Qry.Sql.Add('FROM SISTARQ S');
    Qry.SQL.Add('WHERE S.ID = ' + IntToStr(ID));
    Qry.Open;

    if (Qry.FieldbyName('IN_CRIA_VERSAO_ATUALIZADA').AsString = 'S') then
      CriaVersao := true
    else
      CriaVersao := false;

    if (Qry.FieldbyName('IN_CONTROLE_VERSAO').AsString = 'S') then
      ControleVersao := True
    else
      ControleVersao := False;

    // Verifica se cria nova versão do documento a cada gravação
    if not CriaVersao then begin
      Qry.Close;
      Qry.Sql.Clear;

      // Verifica se o documento tem controle de versão(aprovação)
      GravaNovaVersao := False;
      if  ControleVersao then begin
        // Tem que verificar se já existe versão e se todas estão aprovadas
        Qry.Sql.add('SELECT VERSAO, DT_IMPLANTACAO_VERSAO FROM CONTROLEVERSAO ' );
        Qry.Sql.add('WHERE ID = ' + IntToStr(ID));
        Qry.Sql.add('ORDER BY VERSAO DESC');
        Qry.Open;
        if  Qry.eof then
            GravaNovaVersao := True
        else if not Qry.FieldByName('DT_IMPLANTACAO_VERSAO').isNull then
            GravaNovaVersao := True;
      end
      else begin
        // Tem que verificar se já existe versão
        Qry.Sql.add('SELECT MAX(VERSAO) as UltVersao FROM CONTROLEVERSAO ' );
        Qry.Sql.add('WHERE ID = ' + IntToStr(ID));
        Qry.Open;
        if Qry.FieldByName('UltVersao').asinteger = 0 then
          GravaNovaVersao := True;
      end;
    end
    else
      GravaNovaVersao := false;
  finally
    Qry.Free;
  end;
end;

procedure GravaTextoVersao (ID, Versao    : Integer;
                           Texto          : AnsiString;
                           var NovaVersao : Integer);
var
  Qry             : TSqlQuery;
  JaConectado,
  GravaNovaVersao,
  CriaVersao,
  ControleVersao  : Boolean;
  Stream,
  Compactado : TMemoryStream;
  FileName : TFileName;
  size, sizec : integer;
  TpGravacao : SmallInt;
begin
  sizec :=0;
  GravaNovaVersao := false;
  ControleVersao := false;
  CriaVersao := false;
  Qry := TSqlQuery.create(nil);
  try
    JaConectado := assigned(SCISConnection) and SCISConnection.Connected;
    if not JaConectado then
      scislib.AbreConexao;
    Qry.SqlConnection := SCISConnection;
    VerificaCriterios(SCISConnection,ID,CriaVersao,ControleVersao,GravaNovaVersao);
    if not CriaVersao then begin
      if GravaNovaVersao then begin
        NovaVersao := InsereVersao( ID, VERSAO, Texto);
      end
      else if trim(RetornaLocalArmazenaDocImgs) > '' then begin
        // Atualiza a última versão existente
        Qry.Close;
        Qry.Sql.Clear;
        Qry.Sql.Add('UPDATE CONTROLEVERSAO SET');
        Qry.Sql.Add('DADO = NULL,');
        Qry.Sql.Add('ALT_USUARIO = :ALT_USUARIO,');
        Qry.Sql.Add('ALT_DATA = :ALT_DATA,');
        Qry.Sql.Add('COMPACTADO = :COMPACTADO,');
        Qry.Sql.Add('TP_GRAVACAO = :TP_GRAVACAO');
        Qry.Sql.Add(',NU_TAMANHO_ARQUIVO=:NU_TAMANHO_ARQUIVO,');
        Qry.Sql.Add('NU_TAMANHO_COMPACTADO=:NU_TAMANHO_COMPACTADO ');
        Qry.SQL.Add('WHERE ID = ' + IntToStr(ID));
        Qry.SQL.Add('AND VERSAO = ' + IntToStr(VERSAO));
        Compactado := TMemoryStream.create;
        Stream := TMemoryStream.create;
        try
          FileName := RetornaFileSystemName(ID,VERSAO);
          GaranteCaminhoFileSystemName(FileName);
          Stream.writebuffer(texto[1],length(texto));
          size  := Stream.size;
          Stream.position := 0;
          if CompactaStream(Stream,Compactado) then begin
            sizec := Compactado.size;
            Compactado.position := 0;
            Compactado.SaveToFile(FileName);
            Qry.params[2].asstring := BooleanToSqlBoolean(true);
          end
          else begin
            Stream.Position := 0;
            Stream.SaveToFile(Filename);
            Qry.params[2].asstring := BooleanToSqlBoolean(false);
          end;
        finally
          Stream.free;
          Compactado.free;
        end; {$IFDEF FPC}
        if RetornaLocalArmazenaDocImgs = LocalArmazenamentoS3 then begin
          TpGravacao := TPGravacao_AmazonS3;
          InsereVersaoAmazonS3(FileName);
        end
        else {$ENDIF}
          TpGravacao := TPGravacao_FileSystem;
        Qry.Params[3].asInteger := TpGravacao;
        Qry.Params[4].asInteger := size;
        Qry.Params[5].asInteger := sizec;
        Qry.Params[0].asstring := PegaUsuario;
        Qry.Params[1].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
        try
          Qry.ExecSql;
          NovaVersao := VERSAO;
        except
          on e : exception do begin
            raise exception.create('Ocorreu o seguinte erro ao atualizar o texto ' +
                                   'do documento - ' + e.message );
          end;
        end;
      end
      else begin
        // Atualiza a última versão existente
        Qry.Close;
        Qry.Sql.Clear;
        Qry.Sql.Add('UPDATE CONTROLEVERSAO SET');
        Qry.Sql.Add('DADO = :DADO,');
        Qry.Sql.Add('ALT_USUARIO = :ALT_USUARIO,');
        Qry.Sql.Add('ALT_DATA = :ALT_DATA,');
        Qry.Sql.Add('COMPACTADO = :COMPACTADO,');
        Qry.Sql.Add('TP_GRAVACAO = NULL');
        Qry.Sql.Add(',NU_TAMANHO_ARQUIVO=:NU_TAMANHO_ARQUIVO,');
        Qry.Sql.Add('NU_TAMANHO_COMPACTADO=:NU_TAMANHO_COMPACTADO ');
        Qry.SQL.Add('WHERE ID = ' + IntToStr(ID));
        Qry.SQL.Add('AND VERSAO = ' + IntToStr(VERSAO));
        Qry.Params[0].DataType := ftBlob;
        Compactado := TMemoryStream.create;
        Stream := TMemoryStream.create;
        try
          Stream.writebuffer(texto[1],length(texto));
          size  := Stream.size;
          Stream.position := 0;
          if CompactaStream(Stream,Compactado) then begin
            sizec  := Compactado.size;
            Compactado.position := 0;
            Qry.Params[0].loadfromstream(Compactado,ftblob);
            Qry.params[3].asstring := BooleanToSqlBoolean(true);
          end
          else begin
{$IFDEF XE}
            Stream := TStringStream.create(Texto);
            try
              Stream.Position := 0;
              Qry.Params[0].loadfromstream(stream,ftblob);
            finally
              Stream.free;
            end;
{$ELSE}
            Qry.Params[0].asBlob := BytesOf( Texto);
{$ENDIF}
            Qry.params[3].asstring := BooleanToSqlBoolean(false);
          end;
        finally
          Stream.free;
          Compactado.free;
        end;
        Qry.Params[4].asInteger := size;
        Qry.Params[5].asInteger := sizec;
        Qry.Params[1].asstring := PegaUsuario;
        Qry.Params[2].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
        try
          Qry.ExecSql;
          NovaVersao := VERSAO;
        except
          on e : exception do begin
            raise exception.create('Ocorreu o seguinte erro ao atualizar o texto ' +
                                   'do documento - ' + e.message );
          end;
        end;
      end;
    end
    else begin
      // Cria sempre uma nova versão
      NovaVersao := InsereVersao( ID, VERSAO, Texto);
    end;
    if not JaConectado then
      scislib.FechaConexao;
  finally
    Qry.Free;
  end;
end;

procedure GravaBinarioVersao (ID, Versao     : Integer;
                              filename       : tfilename;
                              var NovaVersao : Integer);
var
  JaConectado : Boolean;
begin
    JaConectado := assigned(SCISConnection) and SCISConnection.Connected;
    if  not JaConectado then
        scislib.AbreConexao;

    GravaBinarioVersao (SCISConnection, ID, Versao, filename, NovaVersao);

    if not JaConectado then
      scislib.FechaConexao;
end;

procedure GravaBinarioVersao (SqlConnection  : TSqlConnection;
                              ID, Versao     : Integer;
                              Stream         : TStream;
                              var NovaVersao : Integer;
                              MiniaturaStr   : AnsiString = ''); 
var
  Qry             : TSqlQuery;
  GravaNovaVersao,
  CriaVersao,
  ControleVersao  : Boolean;
  Compactado : TMemoryStream;
  FileNameFS : TFileName;
  FileStream : TFileStream;
  size,sizec : integer;
  miniaturaStream : TStringStream;
  TpGravacao: SmallInt;
begin
  //Size := 0;
  SizeC := 0;
  GravaNovaVersao := false;
  CriaVersao := false;
  ControleVersao := false;
  Qry := TSqlQuery.create(nil);
  MiniaturaStream := nil;
  try
    Qry.SqlConnection := SqlConnection;
    VerificaCriterios(SqlConnection,ID,CriaVersao,ControleVersao,GravaNovaVersao);
    if not CriaVersao then begin
      if GravaNovaVersao then begin
        NovaVersao := InsereVersaoBinario(SqlConnection, ID, VERSAO, Stream, MiniaturaStr);
      end
      else if trim(RetornaLocalArmazenaDocImgs) > '' then begin
        // Atualiza a última versão existente
        Qry.Close;
        Qry.Sql.Clear;
        Qry.Sql.Add('UPDATE CONTROLEVERSAO SET');
        Qry.Sql.Add('DADO = NULL,');
        Qry.Sql.Add('ALT_USUARIO = :ALT_USUARIO,');
        Qry.Sql.Add('ALT_DATA = :ALT_DATA,');
        Qry.Sql.Add('COMPACTADO = :COMPACTADO,');
        Qry.Sql.Add('NU_TAMANHO_ARQUIVO=:NU_TAMANHO_ARQUIVO,');
        Qry.Sql.Add('NU_TAMANHO_COMPACTADO=:NU_TAMANHO_COMPACTADO,');
        Qry.Sql.Add('TE_IMAGEM_REDUZIDA = :TE_IMAGEM_REDUZIDA,');
        Qry.Sql.Add('TP_GRAVACAO = :TP_GRAVACAO');
        Qry.SQL.Add('WHERE ID = ' + IntToStr(ID));
        Qry.SQL.Add('AND VERSAO = ' + IntToStr(VERSAO));
        Compactado := TMemoryStream.create;
        Stream.Position := 0;
        size := Stream.Size;
        try
          FileNameFS := RetornaFileSystemName(ID,VERSAO);
          GaranteCaminhoFileSystemName(FileNameFS);
          if CompactaStream(Stream,Compactado) then begin
            sizec := Compactado.Size;
            Compactado.Position := 0;
            Compactado.SaveToFile(FileNameFS);
            Qry.Params[2].asstring := BooleanToSqlBoolean(true);
            Qry.Params[3].asInteger := Size;
            Qry.Params[4].asInteger := Sizec;
          end
          else begin
            FileStream := TFileStream.create(FileNameFS,FmCreate);
            try
              FileStream.copyFrom(Stream,0);
            finally
              FileStream.free;
            end;
            Qry.Params[2].asstring := BooleanToSqlBoolean(false);
            Qry.Params[3].asInteger := Size;
            Qry.Params[4].asInteger := Sizec;
          end;
          MiniaturaStream := TStringStream.create(MiniaturaStr);
          MiniaturaStream.position := 0;
          Qry.Params[5].loadfromstream(MiniaturaStream, ftblob);
          if UpperCase(SqlConnection.DriverName) = 'POSTGRES' then
            Qry.Params[5].asBlob := BytesOf('')
          else
            Qry.Params[5].asstring := '';
        finally
          Compactado.free;
          MiniaturaStream.free;
        end; 
        {$IFDEF FPC}
        if RetornaLocalArmazenaDocImgs = LocalArmazenamentoS3 then begin
          TpGravacao := TPGravacao_AmazonS3;
          InsereVersaoAmazonS3(FileNameFS);
        end
        else {$ENDIF}
          TpGravacao := TPGravacao_FileSystem;
        Qry.Params[6].asinteger := TpGravacao;
        Qry.Params[0].asstring := PegaUsuario;
        Qry.Params[1].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
        try
          Qry.ExecSql;
          NovaVersao := VERSAO;
        except
          on e : exception do begin
            raise exception.create('Ocorreu o seguinte erro ao atualizar o texto ' +
                                   'do documento - ' + e.message );
          end;
        end;
      end
      else begin
        // Atualiza a última versão existente
        Qry.Close;
        Qry.Sql.Clear;
        Qry.Sql.Add('UPDATE CONTROLEVERSAO SET');
        Qry.Sql.Add('DADO = :DADO,');
        Qry.Sql.Add('ALT_USUARIO = :ALT_USUARIO,');
        Qry.Sql.Add('ALT_DATA = :ALT_DATA,');
        Qry.Sql.Add('COMPACTADO = :COMPACTADO,');
        Qry.Sql.Add('NU_TAMANHO_ARQUIVO=:NU_TAMANHO_ARQUIVO,');
        Qry.Sql.Add('NU_TAMANHO_COMPACTADO=:NU_TAMANHO_COMPACTADO,');
        Qry.Sql.Add('TE_IMAGEM_REDUZIDA = :TE_IMAGEM_REDUZIDA,');        
        Qry.Sql.Add('TP_GRAVACAO = NULL');
        Qry.SQL.Add('WHERE ID = ' + IntToStr(ID));
        Qry.SQL.Add('AND VERSAO = ' + IntToStr(VERSAO));
        Qry.Params[0].DataType := ftBlob;
        Compactado := TMemoryStream.create;
        size := Stream.Size;
        Stream.Position := 0;
        try
          if CompactaStream(Stream,Compactado) then begin
            sizec := Compactado.Size;
            Compactado.Position := 0;
            Qry.Params[0].loadfromstream(Compactado,ftblob);
            Qry.Params[3].asstring := BooleanToSqlBoolean(true);
            Qry.Params[4].asInteger := Size;
            Qry.Params[5].asInteger := Sizec;
          end
          else begin
            Qry.Params[0].loadfromstream(Stream,ftblob);
            Qry.Params[3].asstring := BooleanToSqlBoolean(false);
            Qry.Params[4].asInteger := Size;
            Qry.Params[5].asInteger := Sizec;
          end;
          MiniaturaStream := TStringStream.create(MiniaturaStr);
          MiniaturaStream.position := 0;
          Qry.Params[6].loadfromstream(MiniaturaStream, ftblob);
        finally
          Compactado.free;
          MiniaturaStream.free;
        end;
        Qry.Params[1].asstring := PegaUsuario;
        Qry.Params[2].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
        try
          Qry.ExecSql;
          NovaVersao := VERSAO;
        except
          on e : exception do begin
            raise exception.create('Ocorreu o seguinte erro ao atualizar o texto ' +
                                   'do documento - ' + e.message );
          end;
        end;
      end;
    end
    else begin
      // Cria sempre uma nova versão
      NovaVersao := InsereVersaoBinario(SqlConnection, ID, VERSAO, Stream, MiniaturaStr);
    end;
  finally
    Qry.Free;
  end;
end;

function GeraMiniaturaImagem (filename: tfilename): AnsiString;
var
  filenameMiniatura : AnsiString;
  st : AnsiString;
  fstream : TFileStream;
begin
  result := '';
  st := '';
  filenameMiniatura := makeTempFileName();
  fstream := nil;
  try
    shell('convert -background white -thumbnail x35 ' + filename + ' ' + filenameMiniatura);
    if fileexists(filenameMiniatura) then begin
      fstream := TFileStream.create(filenameMiniatura, fmOpenRead);
      setLength(st, fstream.size);
      fstream.ReadBuffer(st[1], fstream.size);
{$IFDEF FPC}
      result := 'data:image/png;base64,' + EncodeStringBase64(st);
{$ENDIF}
    end
  finally
    fstream.free;
    if fileExists(filenameminiatura) then
      deleteFile(fileNameMiniatura);
  end;
end;

procedure GeraStreamMiniaturaImagem (NomeArq : TFileName; var Stream : TFileStream);
var
  NomeArqMini : AnsiString;
  FileStream : TFileStream;
begin
  NomeArqMini := makeTempFileName();
  FileStream := nil;
  try
    shell('convert -background white -thumbnail x35 ' + NomeArq + ' ' + NomeArqMini);
    if fileExists(NomeArqMini) then begin
      FileStream := TFileStream.create(NomeArqMini, fmOpenRead);
      Stream.CopyFrom(FileStream, 0);
    end
  finally
    FileStream.free;
  end;
end;

procedure GravaBinarioVersao (SqlConnection  : TSqlConnection;
                              ID, Versao     : Integer;
                              filename       : tfilename;
                              var NovaVersao : Integer;
                              GravaMiniatura  : boolean = false);
var
  Stream : TFileStream;
  MiniaturaStr : AnsiString;
begin
  MiniaturaStr := '';

  if GravaMiniatura then
    MiniaturaStr := GeraMiniaturaImagem(filename);
  Stream := TFileStream.create(filename,FmOpenRead or fmShareDenyNone);
  try
    GravaBinarioVersao (SqlConnection,ID,Versao,Stream,NovaVersao,MiniaturaStr);
  finally
    Stream.free;
  end;

{ Versão antiga
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    VerificaCriterios(SqlConnection,ID,CriaVersao,ControleVersao,GravaNovaVersao);
    if not CriaVersao then begin
      if GravaNovaVersao then begin
        NovaVersao := InsereVersaoBinario(SqlConnection, ID, VERSAO, filename);
      end
      else if trim(RetornaLocalArmazenaDocImgs) > '' then begin
        // Atualiza a última versão existente
        Qry.Close;
        Qry.Sql.Clear;
        Qry.Sql.Add('UPDATE CONTROLEVERSAO SET');
        Qry.Sql.Add('DADO = NULL,');
        Qry.Sql.Add('ALT_USUARIO = :ALT_USUARIO,');
        Qry.Sql.Add('ALT_DATA = :ALT_DATA,');
        Qry.Sql.Add('COMPACTADO = :COMPACTADO,');
        Qry.Sql.Add('TP_GRAVACAO = '+inttostr(TPGravacao_FileSystem));
        Qry.SQL.Add('WHERE ID = ' + IntToStr(ID));
        Qry.SQL.Add('AND VERSAO = ' + IntToStr(VERSAO));
        Compactado := TMemoryStream.create;
        Stream := TFileStream.create(filename,FmOpenRead or fmShareDenyNone);
        try
          FileNameFS := RetornaFileSystemName(ID,VERSAO);
          GaranteCaminhoFileSystemName(FileNameFS);
          if CompactaStream(Stream,Compactado) then begin
            Compactado.Position := 0;
            Compactado.SaveToFile(FileNameFS);
            Qry.Params[2].asstring := BooleanToSqlBoolean(true);
          end
          else begin
            FileStream := TFileStream.create(FileNameFS,FmCreate);
            try
              FileStream.copyFrom(Stream,0);
            finally
              FileStream.free;
            end;
            Qry.Params[2].asstring := BooleanToSqlBoolean(false);
          end;
        finally
          Stream.free;
          Compactado.free;
        end;
        Qry.Params[0].asstring := PegaUsuario;
        Qry.Params[1].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
        try
          Qry.ExecSql;
          NovaVersao := VERSAO;
        except
          on e : exception do begin
            raise exception.create('Ocorreu o seguinte erro ao atualizar o texto ' +
                                   'do documento - ' + e.message );
          end;
        end;
      end
      else begin
        // Atualiza a última versão existente
        Qry.Close;
        Qry.Sql.Clear;
        Qry.Sql.Add('UPDATE CONTROLEVERSAO SET');
        Qry.Sql.Add('DADO = :DADO,');
        Qry.Sql.Add('ALT_USUARIO = :ALT_USUARIO,');
        Qry.Sql.Add('ALT_DATA = :ALT_DATA,');
        Qry.Sql.Add('COMPACTADO = :COMPACTADO,');
        Qry.Sql.Add('TP_GRAVACAO = NULL');
        Qry.SQL.Add('WHERE ID = ' + IntToStr(ID));
        Qry.SQL.Add('AND VERSAO = ' + IntToStr(VERSAO));
        Qry.Params[0].DataType := ftBlob;
        Compactado := TMemoryStream.create;
        Stream := TFileStream.create(filename,FmOpenRead or fmShareDenyNone);
        try
          if CompactaStream(Stream,Compactado) then begin
            Compactado.Position := 0;
            Qry.Params[0].loadfromstream(Compactado,ftblob);
            Qry.Params[3].asstring := BooleanToSqlBoolean(true);
          end
          else begin
            Qry.Params[0].loadfromfile(filename,ftblob);
            Qry.Params[3].asstring := BooleanToSqlBoolean(false);
          end;
        finally
          Stream.free;
          Compactado.free;
        end;
        Qry.Params[1].asstring := PegaUsuario;
        Qry.Params[2].asSqlTimeStamp := DateTimeToSqlTimeStamp(Now);
        try
          Qry.ExecSql;
          NovaVersao := VERSAO;
        except
          on e : exception do begin
            raise exception.create('Ocorreu o seguinte erro ao atualizar o texto ' +
                                   'do documento - ' + e.message );
          end;
        end;
      end;
    end
    else begin
      // Cria sempre uma nova versão
      NovaVersao := InsereVersaoBinario(SqlConnection, ID, VERSAO, filename);
    end;
  finally
    Qry.Free;
  end;
}

end;

function ExisteID(SqlConnection : TSqlConnection; ID : longint) : boolean;
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id from sistarq where id = :id');
    Qry.Parambyname('id').asinteger := id;
    Qry.open;
    result := not Qry.IsEmpty;
  finally
    Qry.free;
  end;
end;

procedure GeraFilhosDoIDAPartirDoTemplate(SqlConnection : TSqlConnection;
                                          IDPai,IDPaiTemplate : longint;
                                          ConsideraArqNaLixeira : boolean = true);
var
  Qry : TSQLQuery;
  IDRaiz : Longint;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie ');
    Qry.Sql.add('from sistarq where idpai = :id and id <> :id');
    Qry.ParamByName('Id').asinteger := idPaiTemplate;
    Qry.open;
    while not Qry.Eof do begin
      IDRaiz := InsereItemNaBase(SqlConnection,IDPai,Qry.FieldByname('Tipo').asinteger,Qry.FieldByName('Nome').asstring,
                                 Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring,
                                 Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring,
                                 Qry.FieldByName('IN_CONTROLE_VERSAO').asstring,
                                 Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring,
                                 Qry.FieldByName('TE_OBSERVACAO_ARQUIVO').asstring,
                                 Qry.FieldByName('NO_DESCRICAO').asstring,
                                 Qry.FieldByName('CO_DOC_DOSSIE').asinteger);

      if not (ConsideraArqNaLixeira and (Qry.FieldByName('TIPO').asinteger = 3)) then
        GeraFilhosDoIDAPartirDoTemplate(SqlConnection,IDRaiz,Qry.FieldByName('ID').asinteger);
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;

procedure GeraArvoreAPartirDoTemplate(    SqlConnection : TSqlConnection; 
                                      Var IDRaiz : longint; 
                                          IDRaizTemplate : longint; 
                                          ConsideraArqNaLixeira : boolean = true);
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie from sistarq where id = :id ');
    Qry.ParamByName('ID').asinteger := IDRaizTemplate;
    Qry.open;
    if Qry.IsEmpty then
      raise exception.create('Sistema de arquivos default vazio');
    IDRaiz := InsereItemNaBase(SqlConnection,IDRaiz,
                               Qry.FieldByname('Tipo').asinteger,
                               Qry.FieldByName('Nome').asstring,
                               Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring,
                               Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring,
                               Qry.FieldByName('IN_CONTROLE_VERSAO').asstring,
                               Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring,
                               Qry.FieldByName('TE_OBSERVACAO_ARQUIVO').asstring,
                               Qry.FieldByName('NO_DESCRICAO').asstring,
                               Qry.FieldByName('CO_DOC_DOSSIE').asinteger,true);

    if not (ConsideraArqNaLixeira and (Qry.FieldByName('TIPO').asinteger = 3)) then
      GeraFilhosDoIDAPartirDoTemplate(Sqlconnection,
                                      IDRaiz,
                                      Qry.FieldByName('ID').asinteger,
                                      ConsideraArqNaLixeira);
    
  finally
    Qry.free;
  end;
end;

procedure GeraNovaArvoreDeDocumentos(    SqlConnection : TSqlConnection; 
                                     Var IDRaiz : longint; 
                                         IDTemplate : longint = -1;
                                         ConsideraArqNaLixeira : boolean = true);
begin
  GeraArvoreAPartirDoTemplate(SqlConnection,IDRaiz,IDTemplate,ConsideraArqNaLixeira); // -1 ID fixo para raiz do template
end;

procedure LeFilhosDoIDParaXml(SqlConnection : TSqlConnection; IDPai : longint; Node : TpXmlNode);
var
  Qry : TSQLQuery;
  Pasta : TpXmlNode;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie ');
    Qry.Sql.add('from sistarq where idpai = :id and id <> :id and tipo <> :tipo');
    Qry.ParamByName('Id').asinteger := IDPai;
    Qry.ParamByName('Tipo').asinteger := ord(ta_documento);
    Qry.open;
    while not Qry.Eof do begin
      Pasta := Node.addchild('Pasta');
      Pasta.Attributes['Nome'] := Qry.FieldByname('Nome').asstring;
      Pasta.Attributes['Tipo']:= Qry.FieldByname('Tipo').asstring;
      Pasta.Attributes['ID']:= Qry.FieldByname('ID').asstring;
      Pasta.Attributes['IN_CRIA_VERSAO_ATUALIZADA'] := Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring;
      Pasta.Attributes['IN_DOCUMENTO_OCULTO'] := Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring;
      Pasta.Attributes['IN_CONTROLE_VERSAO'] := Qry.FieldByName('IN_CONTROLE_VERSAO').asstring;
      Pasta.Attributes['IN_DOCUMENTO_SO_LEITURA'] := Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring;
      Pasta.Attributes['TE_OBSERVACAO_ARQUIVO'] := Qry.FieldByName('TE_OBSERVACAO_ARQUIVO').asstring;
      LeFilhosDoIDParaXml(SqlConnection,Qry.FieldByName('ID').asinteger,Pasta);
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;



procedure LeFilhosDoIDParaStr(SqlConnection : TSqlConnection; 
                              IDPai : longint; 
                              Var St : AnsiString);
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie ');
    Qry.Sql.add('from sistarq where idpai = :id and id <> :id and tipo <> :tipo');
    Qry.ParamByName('Id').asinteger := IDPai;
    Qry.ParamByName('Tipo').asinteger := ord(ta_documento);
    Qry.open;
    while not Qry.Eof do begin
      St:= St +'/'+Qry.FieldByname('Nome').asstring;
      LeFilhosDoIDParaStr(SqlConnection,Qry.FieldByName('ID').asinteger,St);
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;




procedure LeArvoreParaXml(SqlConnection : TSqlConnection; IDRaiz : longint; Node : TpXmlNode);
var
  Qry : TSQLQuery;
  Pasta : TpXmlNode;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie from sistarq where id = :id and tipo <> :tipo');
    Qry.ParamByName('ID').asinteger := IDRaiz;
    Qry.ParamByName('TIPO').asinteger := ord(ta_documento);
    Qry.open;
    if not Qry.IsEmpty then begin
      Pasta := Node.addchild('Pasta');
      Pasta.Attributes['Nome'] := Qry.FieldByname('Nome').asstring;
      Pasta.Attributes['Tipo']:= Qry.FieldByname('Tipo').asstring;
      Pasta.Attributes['ID']:= Qry.FieldByname('ID').asstring;
      Pasta.Attributes['IN_CRIA_VERSAO_ATUALIZADA'] := Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring;
      Pasta.Attributes['IN_DOCUMENTO_OCULTO'] := Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring;
      Pasta.Attributes['IN_CONTROLE_VERSAO'] := Qry.FieldByName('IN_CONTROLE_VERSAO').asstring;
      Pasta.Attributes['IN_DOCUMENTO_SO_LEITURA'] := Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring;
      Pasta.Attributes['TE_OBSERVACAO_ARQUIVO'] := Qry.FieldByName('TE_OBSERVACAO_ARQUIVO').asstring;
      LeFilhosDoIDParaXml(Sqlconnection,IDRaiz,Pasta);
    end;
  finally
    Qry.free;
  end;
end;

procedure LeArvoreParaStr(SqlConnection : TSqlConnection; IDRaiz : longint; var St : AnsiString);
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie from sistarq where id = :id and tipo <> :tipo');
    Qry.ParamByName('ID').asinteger := IDRaiz;
    Qry.ParamByName('TIPO').asinteger := ord(ta_documento);
    Qry.open;
    if not Qry.IsEmpty then begin
      st := st + Qry.FieldByName('NOME').asString;
      LeFilhosDoIDParaStr(Sqlconnection,IDRaiz,St);
    end;
  finally
    Qry.free;
  end;
end;



function EncontraNomeNoNivel(NodeTemplate,Node : TpXmlNode) : integer;
var
  i : integer;
begin
  result := -1;
  for i := 0 to Node.count-1 do
begin
    if (trim(uppercase(NodeTemplate.attributes['Nome'])) = trim(uppercase(Node[i].attributes['Nome']))) or
       ((NodeTemplate.Attributes['Tipo'] = inttostr(ord(ta_raiz))) and
        (Node[i].Attributes['Tipo'] = inttostr(ord(ta_raiz)))) or
       ((NodeTemplate.Attributes['Tipo'] = inttostr(ord(ta_lixeira))) and
        (Node[i].Attributes['Tipo'] = inttostr(ord(ta_lixeira)))) then begin
      result := i;
      break;
    end;
end;
end;

procedure GeraPastasDoIDAPartirDoTemplate(SqlConnection : TSqlConnection;
                                          IDPai,IDPaiTemplate : longint);
var
  Qry : TSQLQuery;
  IDRaiz : Longint;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo,');
    Qry.Sql.Add('       IN_CRIA_VERSAO_ATUALIZADA, IN_DOCUMENTO_OCULTO, IN_CONTROLE_VERSAO,');
    Qry.Sql.add('       IN_DOCUMENTO_SO_LEITURA,TE_OBSERVACAO_ARQUIVO,no_descricao,co_doc_dossie ');
    Qry.Sql.add('from sistarq where idpai = :id and id <> :id and tipo <> :tipo');
    Qry.ParamByName('Id').asinteger := idPaiTemplate;
    Qry.ParamByName('Tipo').asinteger := ord(ta_documento);
    Qry.open;
    while not Qry.Eof do begin
      IDRaiz := InsereItemNaBase(SqlConnection,IDPai,Qry.FieldByname('Tipo').asinteger,Qry.FieldByName('Nome').asstring,
                                 Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asstring,
                                 Qry.FieldByName('IN_DOCUMENTO_OCULTO').asstring,
                                 Qry.FieldByName('IN_CONTROLE_VERSAO').asstring,
                                 Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asstring,
                                 Qry.FieldByName('TE_OBSERVACAO_ARQUIVO').asstring);
      GeraPastasDoIDAPartirDoTemplate(SqlConnection,IDRaiz,Qry.FieldByName('ID').asinteger);
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;

procedure AtualizaArvorePeloTemplate(SqlConnection : TsqlConnection; Node, NodeTemplate : TpXmlNode);
var
  i,
  indice : integer;
  IDRaiz : longint;
begin
  for i := 0 to NodeTemplate.count-1 do begin
    indice := EncontraNomeNoNivel(NodeTemplate[i],Node);
    if indice >= 0 then
      AtualizaArvorePeloTemplate(SqlConnection,Node[Indice],NodeTemplate[i])
    else begin
      IDRaiz := InsereItemNaBase(SqlConnection,strToInt(Node.Attributes['ID']),
                                 strtoint(NodeTemplate[i].attributes['Tipo']),
                                 NodeTemplate[i].attributes['Nome'],
                                 NodeTemplate[i].attributes['IN_CRIA_VERSAO_ATUALIZADA'],
                                 NodeTemplate[i].attributes['IN_DOCUMENTO_OCULTO'],
                                 NodeTemplate[i].attributes['IN_CONTROLE_VERSAO'],
                                 NodeTemplate[i].attributes['IN_DOCUMENTO_SO_LEITURA'],
                                 NodeTemplate[i].attributes['TE_OBSERVACAO_ARQUIVO']);
      GeraPastasDoIDAPartirDoTemplate(Sqlconnection,IDRaiz,strToInt(NodeTemplate[i].Attributes['ID']));
    end;
  end;
end;

procedure AtualizaArvoreAPartirDoTemplate(SqlConnection : TSqlConnection; IDRaiz,IDTemplate : longint); overload;
var
  Xml,
  XmlTemplate : TpXml;
begin
  Xml := TpXml.create;
  XmlTemplate := TpXml.create;
  try
    Xml.DocumentElement.NodeName := 'ARVORE';
    XmlTemplate.DocumentElement.NodeName := 'ARVORE';
    LeArvoreParaXml(SqlConnection,IDTemplate,XmlTemplate.DocumentElement);
    if XmlTemplate.DocumentElement.count > 0 then begin
      LeArvoreParaXml(SqlConnection,IDRaiz,Xml.DocumentElement);
      if Xml.DocumentElement.count > 0 then
        AtualizaArvorePeloTemplate(SqlConnection,Xml.Documentelement,XmlTemplate.DocumentElement);
    end;
  finally
    Xml.free;
    XmlTemplate.free;
  end;
end;

procedure LeTemplate(SqlConnection : TSqlConnection;
                     IDTemplate : longint;
                     XmlTemplate : TpXml);
begin
  XmlTemplate.DocumentElement.NodeName := 'ARVORE';
  LeArvoreParaXml(SqlConnection,IDTemplate,XmlTemplate.DocumentElement);
end;

procedure AtualizaArvoreAPartirDoTemplate(SqlConnection : TSqlConnection;
                                          IDRaiz : longint;
                                          XmlTemplate : TpXml); overload;
var
  Xml : TpXml;
begin
  if XmlTemplate.DocumentElement.count > 0 then begin
    Xml := TpXml.create;
    try
      Xml.DocumentElement.NodeName := 'ARVORE';
      LeArvoreParaXml(SqlConnection,IDRaiz,Xml.DocumentElement);
      if Xml.DocumentElement.count > 0 then
        AtualizaArvorePeloTemplate(SqlConnection,Xml.Documentelement,XmlTemplate.DocumentElement);
    finally
      Xml.free;
    end;
  end;
end;

procedure AtualizaArvoreDeDocumentos(SqlConnection : TSqlConnection;
                                     IDRaiz : longint;
                                     Default : integer = -1);
begin
  AtualizaArvoreAPartirDoTemplate(SqlConnection,IDRaiz,Default); // -1 ID fixo para raiz do template
end;

function IDDoDocumento(SqlCOnnection : TSqlConnection; documento : string; IDPai : integer) : integer;
var
  Qry : TSqlQuery;
begin
  result := -1;
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Add('SELECT ID FROM SISTARQ');
    Qry.Sql.add('WHERE (IDPAI = :IDPai) and (TIPO = :Tipo)');
    Qry.Sql.add(' and NOME = :NOME');
    Qry.ParamByName('IDPai').asinteger := IDPai;
    Qry.ParamByName('tipo').asinteger := 2;
    Qry.ParamByName('nome').asstring := Documento;
    Qry.open;
    if not Qry.IsEmpty then
      result := Qry.FieldByName('ID').asinteger;
  finally
    Qry.free;
  end;
end;

procedure AtualizaSizes(SqlCOnnection : TSqlConnection; ID,versao,size,sizec : integer);
var
  Qry : TSqlQuery;
  sizeOri,sizeOriC : integer;
begin
  size := trunc((size /1024)+0.5);
  sizec := trunc((sizec /1024)+0.5);
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Add('SELECT NU_TAMANHO_ARQUIVO, NU_TAMANHO_COMPACTADO FROM CONTROLEVERSAO');
    Qry.Sql.add('WHERE (ID = :ID) and (VERSAO=:VERSAO)');
    Qry.ParamByName('ID').asinteger := ID;
    Qry.ParamByName('VERSAO').asinteger := VERSAO;
    Qry.open;
    if not Qry.IsEmpty then begin
      sizeOri := Qry.FieldByName('NU_TAMANHO_ARQUIVO').asinteger;
      sizeOriC := Qry.FieldByName('NU_TAMANHO_COMPACTADO').asinteger;

      if (sizeOri = 0) and (sizeOriC = 0) then begin
        Qry.Close;
        Qry.Sql.clear;
        Qry.sql.add('UPDATE CONTROLEVERSAO SET NU_TAMANHO_ARQUIVO=:NU_TAMANHO_ARQUIVO, NU_TAMANHO_COMPACTADO =:NU_TAMANHO_COMPACTADO ');
        Qry.Sql.add('WHERE (ID = :ID) and (VERSAO=:VERSAO)');
        Qry.ParamByName('ID').asinteger := ID;
        Qry.ParamByName('VERSAO').asinteger := VERSAO;
        Qry.ParamByName('NU_TAMANHO_ARQUIVO').asInteger := size;
        Qry.ParamByName('NU_TAMANHO_COMPACTADO').asInteger := sizec;
        Qry.execSql;
      end
      else if (sizeOri = 0) and (Size > 0)  then begin
        Qry.Close;
        Qry.Sql.clear;
        Qry.sql.add('UPDATE CONTROLEVERSAO SET NU_TAMANHO_ARQUIVO =:NU_TAMANHO_ARQUIVO ');
        Qry.Sql.add('WHERE (ID = :ID) and (VERSAO=:VERSAO)');
        Qry.ParamByName('ID').asinteger := ID;
        Qry.ParamByName('VERSAO').asinteger := VERSAO;
        Qry.ParamByName('NU_TAMANHO_ARQUIVO').asInteger := size;
        Qry.execSql;
      end
      else if (sizeOriC = 0) and (SizeC > 0)  then begin
        Qry.Close;
        Qry.Sql.clear;
        Qry.sql.add('UPDATE CONTROLEVERSAO SET NU_TAMANHO_COMPACTADO =:NU_TAMANHO_COMPACTADO ');
        Qry.Sql.add('WHERE (ID = :ID) and (VERSAO=:VERSAO)');
        Qry.ParamByName('ID').asinteger := ID;
        Qry.ParamByName('VERSAO').asinteger := VERSAO;
        Qry.ParamByName('NU_TAMANHO_COMPACTADO').asInteger := sizec;
        Qry.execSql;
      end;
    end;
  finally
    Qry.free;
  end;
end;

function SaveDocumentoToPdfFile(SqlConnection : TSqlConnection; ID : integer; Filename : TFileName;versao : integer = 0 ;
                                 Tamfonte: double = 5.0 ; Retrato: Boolean = false ; Titulo: String = '';PdfA : boolean = false): String;
var
  ext,
  FileNamePdf,
  FileNameErr: String;
begin
  SaveDocumentoToFile(SqlConnection,ID,Filename,versao);
  ext := upstr(ExtractFileExt(Filename));
  if Titulo = '' then Titulo := ExtractFileName(Filename);
  FileNamePdf := ChangeFileExt(FileName,'.pdf');
  FileNameErr := ChangeFileExt(FileName,'.erroconvpdf');
  if (Ext='.PDF') and (PdfA) then begin
    FileNamePdf := ChangeFileExt(FileName,'');
    FileNamePdf := FileNamePdf +'A';
    FileNamePdf := ChangeFileExt(FileNamePdf,'.pdf');
    scciio.ConvertePdfEmPdfA(FileName,FileNamePdf,FileNameErr);
  end else if Ext = '.PDF' then
    FileNamePdf := FileName //usa o nome original pois pode ser .pdf ou .PDF e faz diferença
  else if Ext='.TXT' then
    scciio.ConverteTxtEmPdf(FileName,FileNamePdf,FileNameErr,Tamfonte,Retrato,Titulo)
  else if Ext='.RTF' then
    scciio.ConverteRtfEmPdf(FileName,FileNameErr,PdfA)
  else if (Ext='.HTML') or (Ext='.HTM') then
    scciio.ConverteHtmlEmPdf(FileName,FileNamePdf,FileNameErr)
  else if (Ext='.PNG') or (Ext='.JPG') or (Ext='.JPEG') then
    scciio.ConverteImagemEmPdf(Filename,FileNamePdf,FileNameErr)
  else if (Ext<>'.PDF') then
    raise Exception.Create('Não foi possível converter formato ' + QuotedStr(Ext) + ' para PDF!');
    if not FileExists(FileNamePdf) then raise Exception.Create('Não foi possível converter o arquivo ' + QuotedStr(FileName) + ' para PDF!');
  if FileExists(FileNameErr) then deletefile(FileNameErr);
  Result := FileNamePdf;
end;

procedure SaveDocumentoToFile(SqlConnection : TSqlConnection; ID : integer; Filename : TFileName;versao : integer = 0);
var
  Qry : TSqlQuery;
  MemoryStream : TMemoryStream;
  FileStream : TFileStream;
  FilenameFS : ansistring;
  size,sizec : integer;
  sql : ansistring;
  TpGravacao: SmallInt;
begin
  sizec := 0;
  size  := 0;
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    if uppercase(Qry.SqlConnection.DriverName) = 'ORACLE' then begin
      sql := 'SELECT nu_copias,versao,dado,compactado,tp_gravacao';
      Sql := sql + ' FROM ';
      sql := sql + '(SELECT s.id,s.nu_copias,c.versao,c.dado,c.compactado,c.tp_gravacao,ROW_NUMBER() OVER (ORDER BY s.id,c.versao DESC) R from controleversao c,sistarq s';
      sql := sql + ' where (s.id = :id) and (c.id = s.id) ';
      if versao > 0 then
        sql := sql + ' and c.versao='+inttostr(versao);
      sql := sql + ')';
      sql := sql + 'WHERE R <= 1';
      Qry.sql.text := sql;
    end
    else if uppercase(Qry.SqlConnection.DriverName) = 'POSTGRES' then begin
      sql := 'select nu_copias,versao,dado,compactado,tp_gravacao '+
             'from controleversao c, sistarq s '+
             'where (s.id = :id) and (c.id = s.id) ';
      if versao > 0 then
        sql := sql + ' and (c.versao='+inttostr(versao)+')';
      sql := sql + ' order by versao desc LIMIT 1';
      Qry.sql.text := sql;
    end
    else begin
      if (uppercase(Qry.SqlConnection.DriverName) = 'OPENODBC') or (uppercase(Qry.SqlConnection.DriverName) = 'MSSQL') then
        sql := 'select top 1 '
      else
        sql := 'select first 1 ';
      Qry.Sql.Text := sql + ' nu_copias,versao,dado,compactado,tp_gravacao from controleversao c,sistarq s '+
                      'where (s.id = :id) and (c.id = s.id) ';

      if versao > 0 then
        Qry.Sql.Text := Qry.Sql.Text  + ' and (c.versao='+inttostr(versao)+')';

      Qry.Sql.Text := Qry.Sql.Text  + ' order by versao desc';
    end;
    Qry.params[0].asinteger := ID;
    Qry.open;
    if Qry.isempty then
      raise exception.create('Documento nao encontrado');
    TpGravacao := Qry.FieldByName('tp_gravacao').asinteger;
    if Qry.fieldbyname('Compactado').asstring = BooleanToSqlboolean(true) then begin
      MemoryStream := TMemoryStream.create;
      FileStream := TFileStream.create(filename,FmCreate);
      try
        if (TpGravacao = TPGravacao_FileSystem) or (TpGravacao = TPGravacao_AmazonS3) then begin
          FileNameFS := RetornaFileSystemName(ID,Qry.FieldByName('versao').asinteger);
          {$IFDEF FPC}
          if (TpGravacao = TPGravacao_AmazonS3) or (ScciConf.LocalArmazenaDocImgs = LocalArmazenamentoS3) then begin
            FileNameFS := LeArquivoAmazonS3(FileNameFS);
          end;
          {$ENDIF}
          if not FileExists(FileNameFS) then
            raise exception.create('Não foi possível encontrar o arquivo '+FileNameFS);
          MemoryStream.LoadFromFile(FileNameFS);
        end
        else
          TBlobField(Qry.fieldbyname('dado')).savetostream(MemoryStream);
        DescompactaStream(MemoryStream,FileStream);
        sizec := MemoryStream.size;
        size := FileStream.Size;
      finally
        MemoryStream.free;
        FileStream.free;
      end;
    end
    else begin
      if (TpGravacao = TPGravacao_FileSystem) or (TpGravacao = TPGravacao_AmazonS3) then begin
        FileNameFS := RetornaFileSystemName(ID,Qry.FieldByName('versao').asinteger);
        {$IFDEF FPC}
        if (TpGravacao = TPGravacao_AmazonS3) or (ScciConf.LocalArmazenaDocImgs = LocalArmazenamentoS3) then begin
          FileNameFS := LeArquivoAmazonS3(FileNameFS);
        end;
        {$ENDIF}
        if not FileExists(FileNameFS) then
          raise exception.create('Não foi possível encontrar o arquivo '+FileNameFS);
        if FileExists(filename) then
          if not DeleteFile(filename) then
            raise exception.create('Não foi possível sobrescrever o arquivo '+filename);
        if not FileCopy(FilenameFS,FileName) then
          raise exception.create('Não foi possível copiar o arquivo '+FileNameFS+' para '+FileName);
      end
      else
        TBlobField(Qry.fieldbyname('dado')).savetofile(filename);
      MemoryStream := TMemoryStream.create;
      try
        MemoryStream.LoadFromFile(FileName);
        size := MemoryStream.size;
      finally
        MemoryStream.free;
      end;
    end;
    AtualizaSizes(SqlCOnnection,ID,versao,size,sizec);
  finally
    Qry.free;
  end;
end;
function ValidaUsuarioDocumentoTemporario(
                                    SqlConnection : TSqlConnection;
                                    ID : integer;
                                    SessionKey: String): Boolean;
var
  Qry : TSqlQuery;
begin
  Result := false;
  if (trim(SessionKey) = '') or (ID <= 0)   then
    raise exception.create('SessionKey ou ID do Documento não informados!');
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.sql.add('SELECT ID, SESSIONKEY FROM SISTARQ_TEMPORARIO ');
    Qry.sql.add('WHERE ID = :ID AND SESSIONKEY = :SESSIONKEY');
    Qry.paramByName('ID').dataType := ftinteger;
    Qry.paramByName('SESSIONKEY').dataType := ftString;
    Qry.paramByName('ID').asInteger := ID;
    Qry.paramByName('SESSIONKEY').asString := sessionKey;
    Qry.open;
    if not Qry.isempty then Result := True;
  finally
    Qry.free;
  end;
end;

function SaveDocumentoTemporarioToFile(
                                      ID : integer;
                                      sessionKey : String;
                                      FilePath : String = '';
                                      versao : integer = 1): String;
var
  SqlConnection : TSqlConnection;
  FileName,FilePathName: String;
begin
  Result := '';
  FileName := '';
  FilePathName := '';
  try
    SqlConnection := GetSqlConnection(pegaDirTab);
    if ValidaUsuarioDocumentoTemporario(SqlConnection,ID,sessionKey)  then begin
      if trim(FilePath) = '' then FilePath := ExtractFilePath(makeTempFileName);
      FileName := NomeDocumento(SqlConnection,ID);
      FilePathName := FilePath + FileName;
      SaveDocumentoToFile(SqlConnection,ID,FilePathName,versao);
      Result := FilePathName;
    end;
  finally
  end;
end;
procedure SaveDocumentoTemporarioToStream(
                                    ID : integer;
                                    SessionKey: String;
                                    Versao: LongInt;
                                    Stream : TStream);
var
  Qry : TSqlQuery;
  ListaOut : TpMemory;
  TiposValidos: TStringList;
  Nome: ansistring;
begin
  Qry := TSQLQuery.create(nil);
  ListaOut := TpMemory.Create;
  TiposValidos := TStringList.Create;
  Nome := '';
  TiposValidos.add('.TXT');
  TiposValidos.add('.PDF');
  TiposValidos.add('.HTML');
  TiposValidos.add('.HTM');
  TiposValidos.add('.PNG');
  TiposValidos.add('.JPG');
  TiposValidos.add('.JPEG');
  try
    if ValidaUsuarioDocumentoTemporario(GetSqlConnection(PegaDirTab),ID,SessionKey) then begin
      Nome := NomeDocumento(GetSqlConnection(PegaDirTab),ID);
      if not TiposValidos.IndexOf(uppercase(extractfileext(nome))) > -1 then
        ListaOut.addval('DOW','T');
      ListaOut.addval('Nome',nome);
      ListaOut.addval('Tipo',extractfileext(nome));
      ListaOut.SaveToStreamWithSize(Stream);
      SaveDocumentoToStream(GetSqlConnection(PegaDirTab),ID,Stream,Nome,Versao);
    end;
  finally
    Qry.free;
    ListaOut.free;
  end; 
end;

procedure SaveDocumentoToStream(SqlConnection : TSqlConnection;
                                    ID : integer;
                                    Stream : TStream;
                                Var Nome : ansistring;
                                Var Versao : integer);
var
  Qry : TSqlQuery;
  MemoryStream : TMemoryStream;
  FileNameFS : TFileName;
  FileStream : TFileStream;
  size,sizec : integer;
begin
  sizec := 0;
  size  := 0;
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Text := 'select s.nu_copias,c.versao,c.dado,c.compactado,c.tp_gravacao,c.nome,s.nome as nomesistarq from controleversao c,sistarq s '+
                    'where (s.id = :id) and (c.id = s.id) '+
                    'order by versao desc';
    Qry.params[0].asinteger := ID;
    Qry.open;
    if Qry.isempty then
      raise exception.create('Documento nao encontrado');
    if (trim(Qry.FieldByName('Nome').asString) <> '') then
        Nome := trim(Qry.FieldByName('Nome').asString)
    else nome := trim(Qry.FieldByName('NomeSistArq').asString);

    versao := Qry.fieldbyname('versao').asinteger;
    if Qry.fieldbyname('Compactado').asstring = BooleanToSqlboolean(true) then begin
      MemoryStream := TMemoryStream.create;
      try
        if (Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_FileSystem) or
           (Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_AmazonS3) then begin
          FileNameFS := RetornaFileSystemName(ID,Qry.FieldByName('versao').asinteger);          
          {$IFDEF FPC}
          if (Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_AmazonS3) or 
             (ScciConf.LocalArmazenaDocImgs = LocalArmazenamentoS3) then begin
            FileNameFS := LeArquivoAmazonS3(FileNameFS);
          end;
          {$ENDIF}
          if not FileExists(FileNameFS) then
            raise exception.create('Não foi possível encontrar o arquivo '+FileNameFS);
          MemoryStream.LoadFromFile(FileNameFS);
        end
        else begin
          TBlobField(Qry.fieldbyname('dado')).savetostream(MemoryStream);
        end;
        DescompactaStream(MemoryStream,Stream);
        sizec := MemoryStream.size;
        size  := Stream.size;
      finally
        MemoryStream.free;
      end;
    end
    else begin
      if (Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_FileSystem) or
         (Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_AmazonS3) then begin
        FileNameFS := RetornaFileSystemName(ID,Qry.FieldByName('versao').asinteger);
        {$IFDEF FPC}
        if (Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_AmazonS3) or 
           (ScciConf.LocalArmazenaDocImgs = LocalArmazenamentoS3) then begin
          FileNameFS := LeArquivoAmazonS3(FileNameFS);
        end;
        {$ENDIF}
        if not FileExists(FileNameFS) then
          raise exception.create('Não foi possível encontrar o arquivo '+FileNameFS);
        FileStream := TFileStream.create(FileNameFS,FmOpenRead or fmShareDenyNone);
        try
          Stream.copyFrom(Filestream,0);
          size := Stream.size;
        finally
          FileStream.free;
        end;
      end
      else begin
        TBlobField(Qry.fieldbyname('dado')).savetostream(stream);
        size := Stream.size;
      end;
    end;
    AtualizaSizes(SqlCOnnection,ID,versao,size,sizec);
  finally
    Qry.free;
  end;
end;

procedure SaveDocumentoToStream(SqlConnection : TSqlConnection; ID : integer; Stream : TStream);
var
  Nome : ansistring;
  Versao : integer;
begin
  Nome := '';
  Versao := 0;
  SaveDocumentoToStream(SqlConnection,ID,Stream,Nome,Versao);
end;

procedure SaveVersaoToStream(SqlConnection : TSqlConnection; 
          ID, Versao : integer; Stream : TStream);
var
  Qry : TSqlQuery;
  MemoryStream : TMemoryStream;
  FileNameFS : TFileName;
  FileStream : TFileStream;
  size,sizec : integer;
begin
  sizec := 0;
  size  := 0;
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Text := 'select dado, compactado, tp_gravacao from controleversao where id = :id and versao = :versao';
    Qry.Params[0].asinteger := ID;
    Qry.Params[1].asinteger := Versao;
    Qry.open;
    if Qry.isempty then begin
      raise exception.create('Documento nao encontrado');
    end;
    if Qry.fieldbyname('Compactado').asstring = BooleanToSqlboolean(true) then begin
      MemoryStream := TMemoryStream.create;
      try
        if Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_FileSystem then begin
          FileNameFS := RetornaFileSystemName(ID,Versao);
          if not FileExists(FileNameFS) then
            raise exception.create('Não foi possível encontrar o arquivo '+FileNameFS);
          MemoryStream.LoadFromFile(FileNameFS);
        end
        else begin
          TBlobField(Qry.fieldbyname('dado')).savetostream(MemoryStream);
        end;
        DescompactaStream(MemoryStream,Stream);
        sizec := MemoryStream.size;
        size  := Stream.size;
      finally
        MemoryStream.free;
      end;
    end
    else begin
      if Qry.FieldByName('tp_gravacao').asinteger = TPGravacao_FileSystem then begin
        FileNameFS := RetornaFileSystemName(ID,Versao);
        if not FileExists(FileNameFS) then
          raise exception.create('Não foi possível encontrar o arquivo '+FileNameFS);
        FileStream := TFileStream.create(FileNameFS,FmOpenRead or fmShareDenyNone);
        try
          Stream.copyFrom(Filestream,0);
          size  := Stream.size;
        finally
          FileStream.free;
        end;
      end
      else begin
        TBlobField(Qry.fieldbyname('dado')).savetostream(stream);
        size  := Stream.size;
      end;
    end;
    AtualizaSizes(SqlCOnnection,ID,versao,size,sizec);
  finally
    Qry.free;
  end;
end;

function GeraIDPaiDocumentosContrato(SqlConnection : TSqlConnection; Ctr : TpCtr; UsaSimulacao : boolean = false): longint;
var
  MutDskAtv,
  MutDskFin,
  MutDskSim,
  MutDsk     : TpMutDsk;
  IDPaiDocumentos : longint;
begin
  MutDskAtv.Cad.Ctr := '';
  fillchar(MutDskAtv,sizeof(MutDskAtv),0);
  MutDskFin.Cad.Ctr := '';
  fillchar(MutDskFin,sizeof(MutDskFin),0);
  MutDskSim.Cad.Ctr := '';
  fillchar(MutDskSim,sizeof(MutDskSim),0);
  MutDsk.Cad.Ctr := '';
  fillchar(MutDsk,sizeof(MutDsk),0);
  if abriuCadMut then
    raise exception.create('Cadmut já está aberto');

  LockTxt('IdPaiDocumento.loc');
  try
  
    // Lê contrato na ativa e finalizados
    Le_Arq_Fis;
    Abre_Cad;
    Le_MutDsk(Ctr,MutDskAtv);
    Fecha_Cad;

    if DirectoryExists(PegaDirFin) then begin
      Le_arq_fin;
      Abre_Cad;
      Le_MutDsk(Ctr,MutDskFin);
      Fecha_cad;
    end
    else
      fillchar(MutDskFin,sizeof(TpMutDsk),0);
      
    if usaSimulacao then begin

      // O uso na simulação é exclusivo para contratos ainda não implantados sol. 48529
      if (MutdskAtv.cad.ctr > '') or (MutdskFin.Cad.ctr > '') then
        raise ECtrJaImplantadoException.create('Base de documentos na simulação não permitida para contrato já implantado');

      Le_arq_sim;
      Abre_Cad;
      Le_MutDsk(Ctr,MutDskSim);
      Fecha_cad;

      IDPaiDocumentos := 0;
      if MutDskSim.Cad.Ctr > '' then
        if MutDskSim.Cad.IDPaiDocumentos > 0 then begin

          IDPaiDocumentos := MutDskSim.Cad.IDPaiDocumentos;

          // Verifica se esse ID é válido
          if IDPaiDocumentos > 0 then
            if not ExisteID(SqlConnection,IDPaiDocumentos) then
              raise exception.create('Base de documentos do contrato inconsistente.');

        end
        else begin
          le_arq_sim;
          Abre_cad;
          try
            if AbriuCadmutXdb then begin
              procurareg(Cadmut,Ctr);
              if ok and existechave then begin
                LeReg(Cadmut,Mutdsk);
                if IDPaiDocumentos = 0 then
                  GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos,-1,false{ConsideraArqNaLixeira});

                MutDsk.Cad.IDPaiDocumentos := IDPaiDocumentos;
                GravaReg(Cadmut,MutDsk);
              end;
              posicionareg(Cadmut,limbo);
            end
            else if AbriuCadmutSql then begin
              if IDPaiDocumentos = 0 then
                GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos,-1,false{ConsideraArqNaLixeira});
              SqlConnectionCadmut.ExecuteDirect('update cadmut set cad_IDPaiDocumentos='+
                                                inttostr(IDPaiDocumentos)+
                                                ' where CO_CONTRATO='+
                                                quotedstr(CtrToSqlCtr(Ctr))+
                                                ' and co_base='+inttostr(ContratoDsk.CoBase));
              ContratoDsk.resetcache;
            end;
          finally
            fecha_cad;
          end;
        end;
        
    end
    else begin

      // Se a base estiver diferente na ativa e finalizados, dar erro
      if (MutDskAtv.Cad.Ctr > '') and (MutdskFin.cad.Ctr > '') and
         (MutDskAtv.Cad.IDPaiDocumentos > 0) and (MutDskFin.Cad.IDPaiDocumentos > 0) and
         (MutDskAtv.Cad.IDPaiDocumentos <> MutDskFin.Cad.IDPaiDocumentos) then
        raise exception.create('Base de documentos do contrato na produção diferente da base no FCVS.');

      // Considera o primeiro que tem o ID preenchido
      IDPaiDocumentos := 0;
      if (MutDskAtv.Cad.Ctr > '') and (MutDskAtv.Cad.IDPaiDocumentos > 0) then
        IDPaiDocumentos := MutDskAtv.Cad.IDPaiDocumentos;

      if (MutDskFin.Cad.Ctr > '') and (MutDskFin.Cad.IDPaiDocumentos > 0) then
        IDPaiDocumentos := MutDskFin.Cad.IDPaiDocumentos;

      // Verifica se esse ID é válido
      if IDPaiDocumentos > 0 then
        if not ExisteID(SqlConnection,IDPaiDocumentos) then
          raise exception.create('Base de documentos do contrato inconsistente.');

      // Atualiza nas duas bases, o mesmo ID
      if (MutDskAtv.Cad.Ctr > '') then
        le_arq_fis
      else
        le_arq_fin;
      if DirectoryExists(PegaDirCor) then begin
        abre_cad;
        if AbriuCadmutXdb then begin
          procurareg(Cadmut,Ctr);
          if ok and existechave then begin
            LeReg(Cadmut,Mutdsk);
            if IDPaiDocumentos = 0 then
              GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos);
            MutDsk.Cad.IDPaiDocumentos := IDPaiDocumentos;
            GravaReg(Cadmut,MutDsk);
          end;
          posicionareg(Cadmut,limbo);
        end
        else if AbriuCadmutSql then begin
          if IDPaiDocumentos = 0 then
            GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos);
          SqlConnectionCadmut.ExecuteDirect('update cadmut set cad_IDPaiDocumentos='+
                                            inttostr(IDPaiDocumentos)+
                                            ' where CO_CONTRATO='+
                                            quotedstr(CtrToSqlCtr(Ctr))+
                                            ' and co_base='+inttostr(ContratoDsk.CoBase));

          ContratoDsk.resetcache;
        end;
        fecha_cad;
      end;

      if (MutDskAtv.Cad.Ctr > '') and (MutDskFin.Cad.Ctr > '') then begin
        Le_arq_fin;
        abre_cad;
        if AbriuCadmutXdb then begin
          procurareg(Cadmut,Ctr);
          if ok and existechave then begin
            LeReg(Cadmut,Mutdsk);
            if IDPaiDocumentos = 0 then
              GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos);
            MutDsk.Cad.IDPaiDocumentos := IDPaiDocumentos;
            GravaReg(Cadmut,MutDsk);
          end;
          posicionareg(Cadmut,limbo);
        end
        else if AbriuCadmutSql then begin
          if IDPaiDocumentos = 0 then
            GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos);
          SqlConnectionCadmut.ExecuteDirect('update cadmut set cad_IDPaiDocumentos='+
                                            inttostr(IDPaiDocumentos)+
                                            ' where CO_CONTRATO='+
                                            quotedstr(CtrToSqlCtr(Ctr))+
                                            ' and co_base='+inttostr(ContratoDsk.CoBase));
          ContratoDsk.resetcache;
        end;
        fecha_cad;
      end;
    end;
  finally
    UnLockTxt;
  end;
  result := IDPaiDocumentos;
end;

function GeraIDPaiDocumentosImovel(SqlConnection : TSqlConnection; Empreend : longint; CodImv : string): longint;
var
  IDPaiDocumentos : longint;
  ChaveImv : TpChaveImv;
  RegImv : TpCadImv;
begin

  if abriuImv then
    raise exception.create('Cadimv já está aberto');

  LockTxt('IdPaiDocumento.loc');
  try

    // Lê contrato na ativa e finalizados
    Le_Arq_Fis;
    Abre_Cad;
    RegImv.CodImv := '';
    fillchar(RegImv,sizeof(RegImv),0);
    ChaveImv.Empreend := 0;
    fillchar(ChaveImv,sizeof(TpChaveImv),0);
    ChaveImv.Empreend := Empreend;
    ChaveImv.CodImv := CodImv;
    Le_Imovel(ChaveImv,RegImv);
    if RegImv.codimv = '' then
      raise exception.create('Imóvel inexistente.');
    IDPaiDocumentos := RegImv.IDPaiDocumentos;
    Fecha_Cad;

    // Verifica se esse ID é válido
    if IDPaiDocumentos > 0 then begin
      if not ExisteID(SqlConnection,IDPaiDocumentos) then
        raise exception.create('Base de documentos do imóvel inconsistente.');
    end
    else begin
      le_arq_fis;
      abre_cad;
      Le_Imovel(ChaveImv,RegImv);
      if RegImv.CodImv > '' then begin
        if IDPaiDocumentos = 0 then
          GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos,-3);
        RegImv.IDPaiDocumentos := IDPaiDocumentos;
        Grava_Imovel(Regimv);
      end;
      fecha_cad;
    end;
  finally
    UnLockTxt;
  end;
  result := IDPaiDocumentos;
end;

function GeraIDPaiDocumentosEmp(SqlConnection : TSqlConnection; Empreend : longint): longint;
var
  IDPaiDocumentos : longint;
  RegEmp : TpTabEmp;
begin
  RegEmp.Empreend := 0;
  fillchar(RegEmp,sizeof(RegEmp),0);
  if abriuEmp then
    raise exception.create('tabemp já está aberto');

  LockTxt('IdPaiDocumento.loc');
  try

    // Lê contrato na ativa e finalizados
    Le_Arq_Fis;
    Abre_Cad;
    LeEmpr(Empreend,RegEmp);
    if  RegEmp.Empreend = 0 then
      raise exception.create('Empreendimento inexistente.');
    IDPaiDocumentos := RegEmp.IDPaiDocumentos;
    Fecha_Cad;

    // Verifica se esse ID é válido
    if IDPaiDocumentos > 0 then begin
      if not ExisteID(SqlConnection,IDPaiDocumentos) then
        raise exception.create('Base de documentos do empreendimento inconsistente.');
    end
    else begin
      le_arq_fis;
      abreTabEmp;
      LeEmpr(Empreend,RegEmp);
      if RegEmp.Empreend > 0 then begin
        if IDPaiDocumentos = 0 then
          GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos,-3);
        RegEmp.IDPaiDocumentos := IDPaiDocumentos;
        GravaEmpr(RegEmp);
      end;
      fechaTabEmp;
    end;
  finally
    UnLockTxt;
  end;
  result := IDPaiDocumentos;
end;



function GeraIDPaiDocumentosPretendente(SqlConnection : TSqlConnection; Inscricao : string): longint;
var
  IDPaiDocumentos : longint;
  Qry : TSqlQuery;
  Transaction : TTransactionDesc;
  EstavaEmTransacao : Boolean;
begin
  LockTxt('IdPaiDocumento.loc');
  try
    Qry := TSqlQuery.create(nil);
    try
      EstavaEmTransacao := SqlConnection.InTransaction;
      Qry.SqlConnection := SqlConnection;
      if not EstavaEmTransacao then 
      begin
        Transaction.TransactionID := 2000;
        Transaction.IsolationLevel := xilREADCOMMITTED;
        SqlConnection.StartTransaction(Transaction);
      end;
      try
        Qry.sql.add('Select CO_IDPAIDOCUMENTOS from PRETENDENTE where NU_PRETENDENTE=:inscricao');
        Qry.Parambyname('inscricao').asstring := Inscricao;
        Qry.open;
        if Qry.isempty then
          raise exception.create('Pretendente inexistente.');
        IDPaiDocumentos := Qry.FieldByName('CO_IDPAIDOCUMENTOS').asinteger;
        Qry.close;

        // Verifica se esse ID é válido
        if IDPaiDocumentos > 0 then begin
          if not ExisteID(SqlConnection,IDPaiDocumentos) then
            raise exception.create('Base de documentos do Pretendente inconsistente.');
        end
        else begin
          GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos,-5);
          Qry.sql.clear;
          Qry.sql.add('update PRETENDENTE set CO_IDPAIDOCUMENTOS=:idpaidocumentos where NU_PRETENDENTE=:inscricao');
          Qry.parambyname('idpaidocumentos').asinteger := IDPaiDocumentos;
          Qry.parambyname('inscricao').asstring := inscricao;
          Qry.ExecSql;
        end;
        if not EstavaEmTransacao then
          SqlConnection.Commit(Transaction);
      except
        if not EstavaEmTransacao then 
          SqlConnection.Rollback(Transaction);
        raise;
      end;
    finally
      Qry.free;
    end;
  finally
    UnLockTxt;
  end;
  result := IDPaiDocumentos;
end;

function TestaIDPaiDocumentosPretendente(SqlConnection : TSqlConnection; Inscricao : string): longint;
var
  IDPaiDocumentos : longint;
  Qry : TSqlQuery;
begin
  { A lógica é a mesma do GeraIDPaiDocumentosPretendente, no entanto,
    nesta rotina não quero gerar o ID, caso não exista, então
    não quero gerar lock ou transação }
  IDPaiDocumentos := -1;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    try
      Qry.sql.add('Select CO_IDPAIDOCUMENTOS from PRETENDENTE where NU_PRETENDENTE=:inscricao');
      Qry.Parambyname('inscricao').asstring := Inscricao;
      Qry.open;
      if Qry.isempty then
        raise exception.create('Pretendente inexistente.');
      IDPaiDocumentos := Qry.FieldByName('CO_IDPAIDOCUMENTOS').asinteger;
      Qry.close;

      // Verifica se esse ID é válido
      if IDPaiDocumentos > 0 then begin
        if not ExisteID(SqlConnection,IDPaiDocumentos) then
          raise exception.create('Base de documentos do Pretendente inconsistente.');
      end
      else
        IDPaiDocumentos := -1;
    except
      on e : exception do begin
        raise;
      end;
    end;
  finally
    Qry.free;
  end;
  result := IDPaiDocumentos;
end;

function GeraIDPaiDocumentosTarefa(SqlConnection : TSqlConnection; Tarefa : integer): longint;
var
  IDPaiDocumentos : longint;
  Qry : TSqlQuery;
  Transaction : TTransactionDesc;
  EstavaEmTransacao : Boolean;
begin
  LockTxt('IdPaiDocumento.loc');
  try
    Qry := TSqlQuery.create(nil);
    try
      EstavaEmTransacao := SqlConnection.InTransaction;
      Qry.SqlConnection := SqlConnection;
      if not EstavaEmTransacao then
      begin
        Transaction.TransactionID := 2000;
        Transaction.IsolationLevel := xilREADCOMMITTED;
        SqlConnection.StartTransaction(Transaction);
      end;
      try
        Qry.sql.add('Select CO_IDPAIDOCUMENTOS from OCORRENCIA_SISAT where NU_OCORRENCIA=:Tarefa');
        Qry.Parambyname('Tarefa').asinteger := Tarefa;
        Qry.open;
        if Qry.isempty then
          raise exception.create('Tarefa inexistente.');
        IDPaiDocumentos := Qry.FieldByName('CO_IDPAIDOCUMENTOS').asinteger;
        Qry.close;

        // Verifica se esse ID é válido
        if IDPaiDocumentos > 0 then begin
          if not ExisteID(SqlConnection,IDPaiDocumentos) then
            raise exception.create('Base de documentos da Tarefa inconsistente.');
        end
        else begin
          GeraNovaArvoreDeDocumentos(SqlConnection,IDPaiDocumentos,-9);
          Qry.sql.clear;
          Qry.sql.add('update OCORRENCIA_SISAT set CO_IDPAIDOCUMENTOS=:idpaidocumentos where NU_OCORRENCIA=:Tarefa');
          Qry.parambyname('idpaidocumentos').asinteger := IDPaiDocumentos;
          Qry.parambyname('Tarefa').asinteger := Tarefa;
          Qry.ExecSql;
        end;
        if not EstavaEmTransacao then
          SqlConnection.Commit(Transaction);
      except
        if not EstavaEmTransacao then
          SqlConnection.Rollback(Transaction);
        raise;
      end;
    finally
      Qry.free;
    end;
  finally
    UnLockTxt;
  end;
  result := IDPaiDocumentos;
end;

procedure verificaExistencia(FileName : String;
                            var Existe : Boolean);
var
  Qry : TSqlQuery;
begin
  Qry    := TSqlQuery.create(nil);
  try
    Qry.SQLConnection    := GetSqlConnection(pegaDirTab);;
    Qry.Sql.Add('SELECT * FROM SISTARQ WHERE NOME = :NOME');
    Qry.Params[0].AsString := FileName;
    Qry.open;
    if not Qry.Eof then begin
      Existe := true;
    end;
  finally
    Qry.close;
  end;
end;

function validaPropriedadesDoc(FileName : String;
                               var Existe : Boolean;
                               IdPai : Integer):string;
var
  Qry : TSqlQuery;
  IN_CRIA_VERSAO_ATUALIZADA,
  IN_DOCUMENTO_SO_LEITURA   : String;
begin
  Result := '';
  Qry    := TSqlQuery.create(nil);
  try
    Qry.SQLConnection    := GetSqlConnection(pegaDirTab);
    Qry.Sql.Add('SELECT * FROM SISTARQ WHERE NOME = :NOME AND IDPAI = :IDPAI');
    Qry.Params[0].AsString := FileName;
    Qry.Params[1].AsInteger := IdPai;
    Qry.open;
    if not Qry.Eof then begin
      IN_CRIA_VERSAO_ATUALIZADA := Qry.FieldByName('IN_CRIA_VERSAO_ATUALIZADA').asString;
      IN_DOCUMENTO_SO_LEITURA := Qry.FieldByName('IN_DOCUMENTO_SO_LEITURA').asString;
      if (IN_CRIA_VERSAO_ATUALIZADA = 'S') then Result := Result + ' VERSAO';
      if (IN_DOCUMENTO_SO_LEITURA  = 'S') then Result := Result + ' LEITURA';
      Existe := true;
    end;
  finally
    Qry.close;
  end;
end;

function BuscaIdPaiArqNaBase(Nome : String;
                             IdPai : Integer) : boolean;
var
  Qry : TSqlQuery;
  begin
    Qry    := TSqlQuery.create(nil);
  try
    Qry.SQLConnection :=  GetSqlConnection(pegaDirTab);
    Qry.Sql.Add('SELECT IDPAI FROM SISTARQ WHERE NOME = :NOME AND IDPAI = :IDPAI');
    Qry.Params[0].AsString := Nome;
    Qry.Params[1].AsInteger := IdPai;
    Qry.open;
    if not Qry.Eof then
      Result :=  true
    else Result := false;
  finally
    Qry.close;
  end;
end;


function BuscaIdArqNaBase(Nome : String; 
                          IdPai : Integer) : integer;
var
  Qry : TSqlQuery;
begin
  Result := 0;
  Qry    := TSqlQuery.create(nil);
  try
    Qry.SQLConnection :=  GetSqlConnection(pegaDirTab);
    Qry.Sql.Add('SELECT ID FROM SISTARQ WHERE NOME = :NOME AND IDPAI = :IDPAI');
    Qry.Params[0].AsString := Nome;
    Qry.Params[1].AsInteger := IdPai;
    Qry.open;
    if not Qry.Eof then 
      Result :=  Qry.FieldByName('ID').asInteger;
  finally
    Qry.close;
  end;
end;

function InsereArquivoVersao(Sqlconnection : TSqlConnection;
                       IDPai : integer; Nome : string; FileName : TFileName;
                       No_Descricao : str255 = ''; CO_Doc_Dossie : longint = 0;
                       Co_Tipo_Arquivo : longint = 0;
                       Co_Identificacao : longint = 0;
                       NomeAntigo: string = ''): integer;
var
  propriedades : string;
  Existe,
  IdPaiBase : boolean;
begin
  Existe := false;
  if fileexists(Filename) then begin
    if NomeAntigo > '' then begin
      IdPaiBase := BuscaIdPaiArqNaBase(NomeAntigo,IdPai);
      propriedades := validaPropriedadesDoc(NomeAntigo,Existe,IdPai);
    end else begin
      IdPaiBase := BuscaIdPaiArqNaBase(Nome,IdPai);
      propriedades := validaPropriedadesDoc(Nome,Existe,IdPai);
    end;

    if (Existe) and (IdPaiBase) and (NomeAntigo>'') then result := BuscaIdArqNaBase(NomeAntigo,IdPai)
    else if (Existe) and (IdPaiBase) then result := BuscaIdArqNaBase(Nome,IdPai)
    else result := InsereItemNaBase(SqlConnection,IDPai,2,Nome,NO_Descricao,CO_Doc_Dossie,Co_Tipo_Arquivo,Co_Identificacao);
    InsereVersaoBinario(SqlConnection,result,0,FileName,Nome);
    if NomeAntigo>'' then AlteraNomeDoc (result,Nome);
  end
  else
    raise exception.create('Arquivo inexstente');
end;

function InsereArquivo(Sqlconnection : TSqlConnection;
                       IDPai : integer; Nome : string; FileName : TFileName;
                       No_Descricao : str255 = ''; CO_Doc_Dossie : longint = 0;
                       Co_Tipo_Arquivo : longint = 0;
                       Co_Identificacao : longint = 0): integer;
begin
  if fileexists(Filename) then begin
    result := InsereItemNaBase(SqlConnection,IDPai,2,Nome,NO_Descricao,CO_Doc_Dossie,Co_Tipo_Arquivo,Co_Identificacao);
    InsereVersaoBinario(SqlConnection,result,0,FileName);
  end
  else
    raise exception.create('Arquivo inexstente');
end;

function InsereStream(Sqlconnection : TSqlConnection;
                      IDPai : integer; Nome : string; Stream : TStream;
                      NO_Descricao : str255 = ''; CO_Doc_Dossie : longint = 0;
                      Co_Tipo_Arquivo : longint = 0;
                      Co_Identificacao : longint = 0): integer;
begin
  result := InsereItemNaBase(SqlConnection,IDPai,2,Nome,NO_Descricao,CO_Doc_Dossie,Co_Tipo_Arquivo,Co_Identificacao);
  InsereVersaoBinario(SqlConnection,result,0,Stream);
end;

procedure LeDocumentoDaPastaParaODisco(SqlConnection : TSqlconnection; Pasta,Nome : string; FileName : TFileName);
var
  Id,
  IdPasta : longint;
begin
  IdPasta := LeIDDoDiretorio(SqlConnection,Pasta);
  if IdPasta < 0 then
      raise exception.create('Pasta '+quotedStr(Pasta)+' inexistente');
  ID := IDDoDocumento(SqlConnection,Nome,IdPasta);
  if ID < 0 then
      raise exception.create('Arquivo '+quotedstr(Pasta+'\'+Nome)+' inexistente');
  SaveDocumentoToFile(SqlConnection,ID,FileName);
end;


procedure LeDocumentoDaPastaParaODiscoWeb(SqlConnection : TSqlconnection; Pasta,Nome : string; FileName : TFileName;var achou : boolean);
var
  Id,
  IdPasta : longint;
begin
  achou := false;
  IdPasta := LeIDDoDiretorio(SqlConnection,Pasta);
  if IdPasta >= 0 then
      achou := true;
  if achou then begin
    ID := IDDoDocumento(SqlConnection,Nome,IdPasta);
    if ID >= 0 then
        achou := true
    else achou := false;
   if achou then
    SaveDocumentoToFile(SqlConnection,ID,FileName);
  end;
end;


function EncontraPasta(SqlConnection : TSqlConnection; NomePasta : string; IDPai : integer; Var Achou : boolean) : integer;
var
  Qry : TSqlQuery;
begin
  result := 0;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.add('select id,nome from sistarq where idpai = '+inttostr(IDPai)+' and tipo = 1');
    Qry.open;
    achou := false;
    while not Qry.Eof and not achou do begin
      achou := uppercase(Qry.FieldByName('Nome').asstring) = uppercase(NomePasta);
      if achou then
        result := Qry.FieldByName('ID').asinteger;
      Qry.next;
    end;
    Qry.close;
  finally
    Qry.free;
  end;
end;

function EncontraPastaPeloNome(SqlConnection : TSqlConnection; 
                               NomePasta : string) : integer;
var
  Qry : TSqlQuery;
  contador : integer;
begin
  result := 0;
  contador := 0;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.add('select id,nome from sistarq where tipo = 1 and nome like '+QuotedStr(NomePasta));
    Qry.open;
    while not Qry.Eof do begin
        result := Qry.FieldByName('ID').asinteger;
        inc(contador);
        Qry.next;
    end;
    if contador > 1 then result := -1; // mais de elemento que satisfaÃ§a a bsca, necessÃ¡rio refinar
    if contador = 0 then result := -2; // nao encontrado
    Qry.close;
  finally
    Qry.free;
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

function LeArqsXml(Sqlcon : TsqlConnection;nome,pasta : string;var Stream : TMemoryStream ):boolean;
var id,idpai : integer;
    Achou : boolean;
begin
  Achou := false;
  Stream.clear;
  result := false;
  idPai := EncontraPasta(SqlCon,'Configurações',0{raiz do módulo de documentos global},Achou);
  if Achou then begin
    idPai := EncontraPasta(SqlCon,pasta,idPai,Achou);
    if Achou then begin
        id := IDDoDocumento(SqlCon, nome, IDPai);
        if id > 0 then begin
          SaveDocumentoToStream(SqlCon,ID,Stream);
         Stream.position := 0;
         result := true;
        end;
    end;
  end;
end;

function LeArquivo(var Stream : TmemoryStream;Filename : TFileName) : string;
var
  PathOficial,
  PathCliente : string;
begin
  if not LeArqsXml(GetSqlConnection(pegaDirAtv),fileName,'xmltelas_cliente',Stream) then begin
     if not LeArqsXml(GetSqlConnection(pegaDirAtv),fileName,'xmltelas',Stream) then begin
       PathOficial := PegaDirArqs+PathDelim+'xmltelas'+PathDelim;
       PathCliente := PegaDirArqs+PathDelim+'xmltelas_cliente'+PathDelim;
       if Fileexists(PathCliente + Filename) then
         result := PathCliente + Filename
       else
         result := PathOficial + Filename;
     end else begin
        result := '';
     end
  end else begin
        result := '';
  end;
end;

function LeArquivoInterface(var Stream : TmemoryStream;Filename : TFileName) : string;
var
  PathOficial,
  PathCliente : string;
begin
  if not LeArqsXml(GetSqlConnection(pegaDirAtv),fileName,'xmlinterfaces_cliente',Stream) then begin
     if not LeArqsXml(GetSqlConnection(pegaDirAtv),fileName,'xmlinterfaces',Stream) then begin
       PathOficial := PegaDirArqs+PathDelim+'xmlinterfaces'+PathDelim;
       PathCliente := PegaDirArqs+PathDelim+'xmlinterfaces_cliente'+PathDelim;
       if Fileexists(PathCliente + Filename) then
         result := PathCliente + Filename
       else
         result := PathOficial + Filename;
     end else begin
        result := '';
     end
  end else begin
        result := '';
  end;
end;

function GeraPath2(SqlConnection : TSqlConnection; ID : integer;ExibeGlobais : Boolean) : string;
var
  idpai,
  iditem : integer;
  Qry : TSqlQuery;
begin
  idpai := ID;
  iditem := idpai + 1; // apenas para ser diferente e iniciar o loop
  result := '';
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add( 'SELECT nome,idpai,id,in_exibe_pasta FROM SISTARQ');
    Qry.SQL.Add( 'WHERE ID = :ID');
    while idpai <> iditem do begin
      Qry.parambyname('ID').asinteger := IDPai;
      Qry.Open;
      if Qry.IsEmpty then begin
        result := '';
        break;  // situação de erro, só deveria sair ao achar o nível inicial.
                // melhor não gerar um path
      end
      else begin
        if ExibeGlobais then
          if  (Qry.fieldByname('IN_EXIBE_PASTA').asString <> 'S') then begin
             result := '';
             break;
          end;

        idpai := Qry.FieldByName('idpai').asinteger;
        iditem := Qry.FieldByName('id').asinteger;
        if idpai <> iditem then
          if result > '' then
            result := Qry.FieldByname('nome').asstring + '\' + result
          else
            result := Qry.FieldByname('nome').asstring;
      end;
      if uppercase(SQLConnection.Drivername) <> 'OPENODBC' then
        Qry.Close
      // sai quando achar o nó raiz, que ocorre quando idpai=iditem
    end;
  finally
    Qry.free;
  end;
end;



function GeraPath(SqlConnection : TSqlConnection; ID : integer) : string;
var
  idpai,
  iditem : integer;
  Qry : TSqlQuery;
begin
  idpai := ID;
  iditem := idpai + 1; // apenas para ser diferente e iniciar o loop
  result := '';
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add( 'SELECT nome,idpai,id FROM SISTARQ');
    Qry.SQL.Add( 'WHERE ID = :ID');
    while idpai <> iditem do begin
      Qry.parambyname('ID').asinteger := IDPai;
      Qry.Open;
      if Qry.IsEmpty then begin
        result := '';
        break;  // situação de erro, só deveria sair ao achar o nível inicial.
                // melhor não gerar um path
      end
      else begin
        idpai := Qry.FieldByName('idpai').asinteger;
        iditem := Qry.FieldByName('id').asinteger;
        if idpai <> iditem then
          if result > '' then
            result := Qry.FieldByname('nome').asstring + '\' + result
          else
            result := Qry.FieldByname('nome').asstring;
      end;
      if uppercase(SQLConnection.Drivername) <> 'OPENODBC' then
        Qry.Close
      // sai quando achar o nó raiz, que ocorre quando idpai=iditem
    end;
  finally
    Qry.free;
  end;
end;


function GeraIdRaiz(SqlConnection : TSqlConnection;
                    ID : integer;
                    list : Thashedstringlist) : integer;
var
  idpai,
  iditem : integer;
  Qry : TSqlQuery;
begin
  idpai := ID;
  iditem := idpai + 1; // apenas para ser diferente e iniciar o loop
  result := 0;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add( 'SELECT nome,idpai,id FROM SISTARQ');
    Qry.SQL.Add( 'WHERE ID = :ID');
    while idpai <> iditem do begin
      Qry.parambyname('ID').asinteger := IDPai;
      Qry.Open;
      if List.indexof(IntStr(idpai)) > -1 then raise exception.create('Este arquivo esta em recursividade. ID='+intstr(id));
      list.add(intStr(idpai));

      if Qry.IsEmpty then begin
        break;  // situação de erro, só deveria sair ao achar o nível inicial.
                // melhor não gerar um path
      end
      else begin
        idpai := Qry.FieldByName('idpai').asinteger;
        iditem := Qry.FieldByName('id').asinteger;
        if idpai <> iditem then
          result := Qry.FieldByname('idpai').asInteger;
      end;
      if uppercase(SQLConnection.Drivername) <> 'OPENODBC' then
        Qry.Close
      // sai quando achar o nó raiz, que ocorre quando idpai=iditem
    end;
  finally
    Qry.free;
  end;
end;


function GeraIdRaiz2(SqlConnection : TSqlConnection;
                    ID : integer;
                    list : Thashedstringlist;
                    var lst : text) : integer;
var
  idpai,
  iditem : integer;
  Qry : TSqlQuery;
begin
  idpai := ID;
  iditem := idpai + 1; // apenas para ser diferente e iniciar o loop
  result := 0;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add( 'SELECT nome,idpai,id FROM SISTARQ');
    Qry.SQL.Add( 'WHERE ID = :ID');
    while idpai <> iditem do begin
      Qry.parambyname('ID').asinteger := IDPai;
      Qry.Open;
      if List.indexof(IntStr(id)) > -1 then begin
         list.add(intStr(idpai));
         writeln(lst,'ID='+intstr(id)+'-'+Qry.fieldByname('nome').asString);
         break;
      end;
      list.add(intStr(idpai));

      if Qry.IsEmpty then begin
        break;  // situação de erro, só deveria sair ao achar o nível inicial.
                // melhor não gerar um path
      end
      else begin
        idpai := Qry.FieldByName('idpai').asinteger;
        iditem := Qry.FieldByName('id').asinteger;
        if idpai <> iditem then
          result := Qry.FieldByname('idpai').asInteger;
      end;
      if uppercase(SQLConnection.Drivername) <> 'OPENODBC' then
        Qry.Close
      // sai quando achar o nó raiz, que ocorre quando idpai=iditem
    end;
  finally
    Qry.free;
  end;
end;




function ObtemIDPelaHierarquia(SqlConnection       : TSqlConnection;
                               IDpai,CodHierarquia : integer;
                               Inclui              : Boolean = True): integer;
var
  path : string;
  nomepasta : string;
  Achou : boolean;
  i,IDEncontrado : integer;
begin
  NomePasta := '';
  Path := GeraPath(SqlConnection,CodHierarquia);
  if path = '' then
    raise exception.create('Não foi possível encontrar hierarquia configurada');
  i := 1;
  nomepasta := trim(Palavra(path,i,'\',#255,#255));
  result := IDPai;
  Achou := true; // assume que existe
  while NomePasta > '' do begin
    if Achou then begin
      IDEncontrado := EncontraPasta(SqlConnection,nomepasta,result,Achou);
      if Achou then result := IDEncontrado;
    end;
    if (not achou) and Inclui then
      result := InsereItemNaBase(SqlConnection,result,1,NomePasta);
    inc(i);
    nomepasta := trim(Palavra(path,i,'\',#255,#255));
  end;
end;

procedure LeDocumentosXmlDoDisco(Dir : string; Root : TpXmlNode; Raiz : boolean = true);
var
  DirXml : TpXmlNode;
  sr : TSearchRec;
  i : integer;
  Temp : TpXmlNode;
begin
  if DirectoryExists(dir) then begin
    if Raiz then begin
      DirXml := Root.addchild('ITEM');
      DirXml.attributes['Tipo'] := inttostr(ord(ta_raiz));
      DirXml.attributes['Nome'] := 'Documentos';
    end
    else
      DirXml := Root;
    if FindFirst(Dir+PathDelim+'*', faAnyFile, sr) = 0 then try
      repeat
        if (sr.name <> '..') and (sr.name <> '.') and
           (copy(trim(sr.name),1,1) <> '.') then begin
          if (sr.Attr and faDirectory) <> 0 then begin
            temp := DirXml.addchild('ITEM');
            Temp.attributes['Tipo'] := inttostr(ord(ta_pasta));
          end
          else begin
            temp := DirXml.addchild('ITEM');
            Temp.attributes['Tipo'] := inttostr(ord(ta_documento));
          end;
          Temp.attributes['Nome'] := sr.name;
          Temp.attributes['filename'] := Dir + PathDelim + sr.name;
        end;
      until FindNext(sr) <> 0;
    finally
      FindClose(sr);
    end;
    for i := 0 to DirXml.count-1 do
      if (DirXml[i].Attributes['Tipo'] = inttostr(ord(ta_pasta))) or
         (DirXml[i].Attributes['Tipo'] = inttostr(ord(ta_raiz))) then
        LeDocumentosXmlDoDisco(DirXml[i].attributes['filename'],DirXml[i],false);
  end;
end;

procedure LeTodosFilhosDoIDParaXml(SqlConnection : TSqlConnection; IDPai : longint; Node : TpXmlNode);
var
  Qry : TSQLQuery;
  Item : TpXmlNode;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo');
    Qry.Sql.add('from sistarq where idpai = :id and id <> :id');
    Qry.ParamByName('Id').asinteger := IDPai;
    Qry.open;
    while not Qry.Eof do begin
      Item := Node.addchild('Item');
      Item.Attributes['Nome'] := Qry.FieldByname('Nome').asstring;
      Item.Attributes['Tipo']:= Qry.FieldByname('Tipo').asstring;
      Item.Attributes['ID']:= Qry.FieldByname('ID').asstring;
      if Qry.FieldByname('Tipo').asinteger in [ord(ta_pasta),ord(ta_raiz)] then
        LeTodosFilhosDoIDParaXml(SqlConnection,Qry.FieldByName('ID').asinteger,Item);
      Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;

procedure LeTodaArvoreParaXml(SqlConnection : TSqlConnection; IDRaiz : longint; Node : TpXmlNode);
var
  Qry : TSQLQuery;
  Item : TpXmlNode;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Nome, Tipo');
    Qry.Sql.add('       from sistarq where id = :id');
    Qry.ParamByName('ID').asinteger := IDRaiz;
    Qry.open;
    if not Qry.IsEmpty then begin
      Item := Node.addchild('Item');
      Item.Attributes['Nome'] := Qry.FieldByname('Nome').asstring;
      Item.Attributes['Tipo']:= Qry.FieldByname('Tipo').asstring;
      Item.Attributes['ID']:= Qry.FieldByname('ID').asstring;
      if Qry.FieldByname('Tipo').asinteger in [ord(ta_pasta),ord(ta_raiz)] then
        LeTodosFilhosDoIDParaXml(Sqlconnection,IDRaiz,Item);
    end;
  finally
    Qry.free;
  end;
end;

function EncontraItemDiscoNoNivel(NodeTemplate,Node : TpXmlNode) : integer;
var
  i : integer;
begin
  result := -1;
  for i := 0 to Node.count-1 do begin
    if ((Node[i].Attributes['Tipo'] = NodeTemplate.Attributes['Tipo']) and
        (uppercase(NodeTemplate.attributes['Nome']) = uppercase(Node[i].attributes['Nome']))) or
       ((NodeTemplate.Attributes['Tipo'] = inttostr(ord(ta_raiz))) and
        (Node[i].Attributes['Tipo'] = inttostr(ord(ta_raiz)))) then begin
      result := i;
      break;
    end;
  end;
end;

procedure IncluiItemsDoIDAPartirDoXmlDisco(Sqlconnection : TSqlConnection; IDRaiz : longint; NodeTemplate : TpXmlNode);
var
  i : integer;
  ID : longint;
begin
  for i := 0 to NodeTemplate.count-1 do begin
    ID := InsereItemNaBase(SqlConnection,IDRaiz,
                           strtoint(NodeTemplate[i].attributes['Tipo']),
                           NodeTemplate[i].attributes['Nome']);
    if NodeTemplate[i].attributes['Tipo'] = inttostr(ord(ta_documento)) then
      InsereVersaoBinario(SqlConnection,ID,0,NodeTemplate[i].attributes['filename'])
    else if NodeTemplate[i].attributes['Tipo'] = inttostr(ord(ta_pasta)) then
      IncluiItemsDoIDAPartirDoXmlDisco(Sqlconnection,ID,NodeTemplate[i]);
  end;
end;

procedure AtualizaNivelPeloXmlDisco(SqlConnection : TsqlConnection; Node, NodeTemplate : TpXmlNode);
var
  i,
  indice : integer;
  ID : longint;
begin
  for i := 0 to NodeTemplate.count-1 do begin
    indice := EncontraItemDiscoNoNivel(NodeTemplate[i],Node);
    if indice >= 0 then
      AtualizaNivelPeloXmlDisco(SqlConnection,Node[Indice],NodeTemplate[i])
    else begin
      ID := InsereItemNaBase(SqlConnection,strToInt(Node.Attributes['ID']),
                             strtoint(NodeTemplate[i].attributes['Tipo']),
                             NodeTemplate[i].attributes['Nome']);
      if NodeTemplate[i].attributes['Tipo'] = inttostr(ord(ta_documento)) then
        InsereVersaoBinario(SqlConnection,ID,0,NodeTemplate[i].attributes['filename'])
      else if NodeTemplate[i].attributes['Tipo'] = inttostr(ord(ta_pasta)) then
        IncluiItemsDoIDAPartirDoXmlDisco(Sqlconnection,ID,NodeTemplate[i]);
    end;
  end;
end;

procedure AtualizaDocumentosPeloXmlDisco(SqlConnection : TSqlConnection; XmlTemplate : TpXml);
var
  Xml : TpXml;
begin
 if XmlTemplate.documentelement.count > 0 then begin
    Xml := TpXml.create;
    try
      Xml.documentElement.nodename := 'HIERARQUIA';
      LeTodaArvoreParaXml(SqlConnection,0,Xml.DocumentElement);
      AtualizaNivelPeloXmlDisco(SqlConnection,Xml.DocumentElement,XmlTemplate.DocumentElement);
    finally
      Xml.free;
    end;
  end;
end;
function LimpaTagsRTF(const texto: string): string;
var
  i: Integer;
  resultado: string;
  c: Char;
  ultimoEraEspaco: Boolean;
begin
  resultado := '';
  ultimoEraEspaco := False;
  i := 1;
  
  while i <= Length(texto) do
  begin
    c := texto[i];
    
    // Remove chaves { e }
    if (c = '{') or (c = '}') then
        begin
            Inc(i);
      continue;
    end;
    
    //Remove comandos RTF (começam com \) 
    if c = '\' then
    begin
      Inc(i);  // Pula a barra
      
      // ===== Trata Unicode escapado: \u227\''e3 =====
      if (i <= Length(texto)) and (texto[i] = 'u') then
      begin
        Inc(i); // Pula 'u'
        // Pula número unicode
        if (i <= Length(texto)) and (texto[i] = '-') then
          Inc(i);
        while (i <= Length(texto)) and (texto[i] in ['0'..'9']) do
          Inc(i);
        // Pula escape opcional \''xx
        if (i <= Length(texto)) and (texto[i] = '\') then
        begin
          Inc(i);
          if (i+1 <= Length(texto)) and (texto[i] = '''') and (texto[i+1] = '''') then
          begin
            Inc(i, 2); // Pula ''
            // Pula caracteres hex
      while (i <= Length(texto)) and 
            (texto[i] in ['a'..'z','A'..'Z','0'..'9']) do
        Inc(i);
          end;
        end;
        continue;
      end;
      
      // ===== Trata escape de caractere especial: \' =====
      if (i <= Length(texto)) and (texto[i] = '''') then
      begin
        Inc(i); // Pula '
        // Pula os dois caracteres hex
        if (i+1 <= Length(texto)) then
          Inc(i, 2);
        continue;
      end;
      
      // ===== Comandos RTF normais (ex: \rtlch, \fs24, \par) =====
      // Pula APENAS letras do nome do comando
      while (i <= Length(texto)) and 
            (texto[i] in ['a'..'z','A'..'Z']) do
        Inc(i);
      
      // Pula sinal negativo se houver
      if (i <= Length(texto)) and (texto[i] = '-') then
        Inc(i);
      
      // Pula dígitos do parâmetro
      while (i <= Length(texto)) and (texto[i] in ['0'..'9']) do
        Inc(i);
      
      // Pula espaço após comando (faz parte do comando)
      if (i <= Length(texto)) and (texto[i] = ' ') then
        Inc(i);
      
      continue;
    end;
    
    // Ignora quebras de linha e tabs do arquivo RTF (nao sao conteudo)
    if c in [#9, #10, #13] then begin
      Inc(i);
      continue;
    end;

    // Normaliza espacos
    if c = ' ' then
    begin
      if not ultimoEraEspaco then
      begin
        resultado := resultado + ' ';
        ultimoEraEspaco := True;
      end;
      Inc(i);
      continue;
    end;
    
    // ===== Caractere normal - adiciona =====
    resultado := resultado + c;
    ultimoEraEspaco := False;
    Inc(i);
  end;
  
  Result := Trim(resultado);
end;

procedure ListaVariaveis(Texto : ansistring; 
                         FileName : string; 
                         LstVariaveisDocumento : Tstringlist;
                         PadraoCorpWeb : boolean = false;
                         NaoAddRepetida : boolean = false);
var
  st : ansistring;
  fieldname : ansistring;
  i : integer;
  repeticao : integer;
begin
  if(PadraoCorpWeb) then begin
    repeticao := 0;
    st := Texto;
    while pos('<<',st) > 0 do begin
      fieldname := copy(st,pos('<<',st)+2,length(st));
      fieldname := copy(fieldname,1,pos('>>',fieldname)-1);
      fieldname := LimpaTagsRTF(fieldname);
      fieldname := uppercase(trim(fieldname));
      LstVariaveisDocumento.Add(fieldname);
      st := copy(st,pos('<<',st)+2,length(st));
      st := copy(st,pos('>>',st)+2,length(st));
    end;
  end 
  else if (uppercase(extractfileext(FileName)) = '.HTM') or
     (uppercase(extractfileext(FileName)) = '.HTML') then begin
    st := Texto;
    while pos('%[',st) > 0 do begin
      fieldname := copy(st,pos('%[',st)+2,length(st));
      fieldname := copy(fieldname,1,pos(']',fieldname)-1);
      LstVariaveisDocumento.Add(fieldname);
      st := copy(st,pos('%[',st)+2,length(st));
      st := copy(st,pos(']',st)+1,length(st));
    end;
  end
  else begin
    st := Texto;
    while pos('{MERGEFIELD',st) > 0 do begin
      fieldname := copy(st,pos('{MERGEFIELD',st)+11,length(st));
      fieldname := copy(fieldname,1,pos('}',fieldname)-1);
      fieldname := stringreplace(fieldname,'\'+''''+'20',' ',[rfReplaceAll]);
      fieldname := stringreplace(fieldname,'"','',[rfReplaceAll]);
      LstVariaveisDocumento.add(trim(fieldname));
      st := copy(st,pos('{MERGEFIELD',st)+11,length(st));
      st := copy(st,pos('}',st)+1,length(st));
    end;
  end;
  for i := 0 to LstVariaveisDocumento.count-1 do
    LstVariaveisDocumento[i] := uppercase(LstVariaveisDocumento[i]);
end;

function NomeVarRtf(Linha: AnsiString): AnsiString;
var
  posmerge : integer;
begin
  result := '';
  posMerge := pos('MERGEFIELD',linha);
  if posMerge > 0 then begin
   result := copy(Linha,posmerge+11,length(linha));
   result := trim(copy(result,1,pos('}',result)-1));
  end;
  result := StringReplace(Result,'.','_',[rfReplaceAll]);
end;



procedure TrocaVariavelParaCorpWeb(Filename : AnsiString);
var
  st : ansistring;
  fieldname : ansistring;
  lst,lst2 : text;
  campo,lin : ansiString;
  
  posini,posfin : integer;
begin
 assign(lst,Filename);
 assign(lst2,Filename+'.tmp');
 reset(lst);
 rewrite(lst2);
 st := '';
 while not Eof(lst) do begin
  readln(lst,st);
  lin := '';
  while  pos('{MERGEFIELD',st) > 0 do begin
    posini :=  pos('{MERGEFIELD',st);
    if posini > 0 then begin
      fieldname := copy(st,pos('{MERGEFIELD',st)+11,length(st));
      fieldname := copy(fieldname,1,pos('}',fieldname)-1);
      posfin :=   31+(Length(fieldname)); 
      campo := Copy(St,PosIni-18,PosFin);
      st := StringReplace(st,campo,
                         '<<'+trim(FieldName)+'>>',[rfReplaceAll]);
      st := StringReplace(st,'{\*\wpfldparam{'+FieldName+'}}','',[rfReplaceAll]);
    end;
  end;
  st := StringReplace(st,'{\*\wpfldparam{%}}','',[rfReplaceAll]);
  while   pos('{\fldrslt{[',st) > 0 do begin
    posini :=  pos('{\fldrslt{[',st);
    if posini > 0 then begin
      fieldname := copy(st,pos('{\fldrslt{[',st)+11,length(st));
      fieldname := copy(fieldname,1,pos(']',fieldname)-1);
      posfin :=   15+Length(fieldname); 
      campo := Copy(St,PosIni,PosFin);
      st := StringReplace(st,campo,'',[rfReplaceAll]);
      st := StringReplace(st,fieldname+']}}}','',[rfReplaceAll]);
    end;
  end;
  lin := st;
  writeln(lst2,lin);
 end;
 close(lst);
 close(lst2);
 shell('cp '+Filename+'.tmp '+Filename);
end;


procedure AdicionaParametro(DataSet : TDataSet; Campos,MetaDados : TpMemory; Var QtdeCampos : integer;TrocaTextPorMemo : boolean = false);
var
  formato : TFormatoVariavelTelaDocumento;
  DtZero : Tdata;
  TratouCampo : boolean;
  Aux : tpMemory;
  Tamanho,
  TamanhoExibir : integer;
  Lista :Tstrings;
  Linhas : integer;
begin
  DtZero.dia :=0;
  fillchar(DtZero,sizeof(Tdata),0);
  Formato := TFormatoVariavelTelaDocumento(Dataset.fieldbyname('CO_TELA_FORMATO').asinteger);
  Tratoucampo := true;
  Case formato of
    frmtvarteladoc_data : begin
                           inc(QtdeCampos);
                           MetaDados.addCampoData(DataSet.Fieldbyname('CO_CAMPO_EXIBE').asstring,
                                                  DtZero,DataSet.Fieldbyname('NO_TELA_NOME').asstring,
                                                  QtdeCampos,true);
                         end;
    frmtvarteladoc_moeda : begin
                            inc(QtdeCampos);
                            MetaDados.AddCampoReal(DataSet.Fieldbyname('CO_CAMPO_EXIBE').asstring,
                                                   0,14,2,DataSet.Fieldbyname('NO_TELA_NOME').asstring,
                                                   QtdeCampos,true);
                        end;
    frmtvarteladoc_numero : begin
                             inc(QtdeCampos);
                             MetaDados.AddCampoReal(DataSet.Fieldbyname('CO_CAMPO_EXIBE').asstring,
                                                    0,16-DataSet.Fieldbyname('NU_TELA_DECIMAIS').asinteger,
                                                    DataSet.Fieldbyname('NU_TELA_DECIMAIS').asinteger,
                                                    DataSet.Fieldbyname('NO_TELA_NOME').asstring,
                                                    QtdeCampos,true);
                           end;
    frmtvarteladoc_texto : begin
                            inc(QtdeCampos);
                            Tamanho := DataSet.Fieldbyname('NU_TELA_TAMANHO').asinteger;
                            TamanhoExibir := Tamanho;
                            if TamanhoExibir > 50 then
                              TamanhoExibir := 50;
                            if (TrocaTextPorMemo)  then begin
                               
                               if tamanho > 200 then
                                 Linhas := 200
                               else linhas := 22;
                               Lista :=TstringList.create;
                               MetaDados.AddCampoMemo(DataSet.Fieldbyname('CO_CAMPO_EXIBE').asstring,
                                                     Lista,
                                                     400,
                                                     Linhas,
                                                     DataSet.Fieldbyname('NO_TELA_NOME').asstring,
                                                     QtdeCampos,
                                                     True,'',tamanho,linhas > 22);
                               lista.free;
                            end else
                             MetaDados.AddCampoString(DataSet.Fieldbyname('CO_CAMPO_EXIBE').asstring,
                                                     '',DataSet.Fieldbyname('NO_TELA_NOME').asstring,
                                                     Tamanho,
                                                     TamanhoExibir,
                                                     QtdeCampos,true);                          end;
    else
      TratouCampo := false;
  end;
  if tratouCampo then begin
    aux := Tpmemory.create;
    try
      datasettomemory(DataSet,'',Aux);
      Campos.addrep(DataSet.Fieldbyname('CO_CAMPO_EXIBE').asstring,Aux);
    finally
      aux.free;
    end;
  end;
end;

procedure LeTelaParametros(SqlConnection : TSqlConnection;
                           texto : ansistring;
                           Filename: string;
                           Buffer : TpMemory;
                           TrocaTextPorMemo : boolean = false);
var
  LstVariaveisDocumento : TStringlist;
  Qry : TSqlQuery;
  Campos,
  MetaDados : Tpmemory;
  i,
  QtdeCampos : integer;
begin
  QtdeCampos := 0;
  LstVariaveisDocumento := TStringlist.create;
  Campos := TpMemory.create;
  MetaDados := TpMemory.create;
  Qry := TSqlQuery.create(nil);
  try
    ListaVariaveis(Texto,FileName,LstVariaveisDocumento);
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.add('select * from campo_editor where (co_campo_exibe = :campo) and  not (NO_TELA_NOME IS NULL)');
    Qry.Params[0].DataType := ftString;
    Qry.prepared := true;
    try
      for i := 0 to LstVariaveisDocumento.count-1 do begin
        Qry.parambyname('campo').asstring := LstVariaveisDocumento[i];
        Qry.open;
        try
          if not Qry.IsEmpty then
            AdicionaParametro(Qry,Campos,MetaDados,QtdeCampos,TrocaTextPorMemo);
        finally
          if uppercase(SQLConnection.Drivername) <> 'OPENODBC' then  
            Qry.close;
        end;
      end;
    finally
      Qry.prepared := false;
    end;
    Buffer.addrep('TelaParametros',MetaDados);
    Buffer.addrep('ConfiguracaoDosCampos',Campos);
  finally
    MetaDados.free;
    Campos.free;
    LstVariaveisDocumento.free;
  end;
  Buffer.Addbool('TemParametros',QtdeCampos > 0);
end;

function CompactaStream(Original, Compactado : TStream) : boolean;
var
  ZStream : TCompressionStream;
begin
  ZStream := TCompressionStream.Create(clMax,Compactado);
  try
    ZStream.copyfrom(Original,0);
  finally
    ZStream.free; // Escreve o final do arquivo compactado em Compactado
  end;
  compactado.position := 0;
  result := Compactado.size < Original.size;
end;

procedure DescompactaStream(Original, DesCompactado : TStream);
var
  DStream : TDeCompressionStream;
  i : Integer;
  Buf : array[0..1023]of Byte;
begin
  Original.position := 0;
  Buf[0] := 0;
  fillchar(Buf,sizeof(Buf),0);
  DStream := TDeCompressionStream.Create(Original);
  try
    repeat
       i := DStream.Read(Buf, SizeOf(Buf));
       if i <> 0 then Descompactado.Write(Buf, i);
    until i <= 0;

  finally
    DStream.free;
  end;
end;

procedure ExcluiUmArquivo(SqlConnection : TSqlConnection; ID : integer);
var
  Qry : TSqlQuery;
  FileList : TStringlist;
  FileNameFS : TFileName;
  sr : TSearchRec;
  i : integer;
  TD : TTransactionDesc;
  EstavaEmTransacao : boolean;
begin
  Qry := TSqlQuery.create(nil);
  FileList := TStringlist.create;
  try
    EstavaEmTransacao := SqlConnection.InTransaction;
    Qry.SqlConnection := SqlConnection;
    if not EstavaEmTransacao then begin
      TD.TransactionID := 1;
      TD.IsolationLevel := xilReadCommitted;
      SqlConnection.StartTransaction(TD);
    end;
    try
      Qry.Sql.Text := 'delete from CONTROLEVERSAO where id = :id';
      Qry.Params[0].asinteger := ID;
      Qry.ExecSql;

      Qry.Sql.Text := 'delete from sistarq '+
                      'where id = :id';
      Qry.Params[0].asinteger := ID;
{$IFDEF FPC}
      Qry.ExecSql; // execsql não retorna número de registro alterados no fpc
{$ELSE}
      if Qry.ExecSql <> 1 then
        raise exception.create('Erro na exclusao');
{$ENDIF}
      FileNameFS := RetornaFileSystemName(ID,0);
      FileNameFS := ChangeFileExt(FileNameFS,'.*');
      if FindFirst(FileNameFS, 0, sr) = 0 then begin
        repeat
          FileList.add(IncludeTrailingPathDelimiter(ExtractFilePath(FileNameFS)) + sr.Name);
        until FindNext(sr) <> 0;
        FindClose(sr);
      end;
      for i := 0 to FileList.count-1 do
        DeleteFile(FileList[i]);
      if not EstavaEmTransacao then SqlConnection.Commit(TD);
    except
      if not EstavaEmTransacao then SqlConnection.rollback(TD);
      raise;
    end;
  finally
    FileList.free;
    Qry.free;
  end;
end;

procedure ExcluiFilhosDoID(SqlConnection : TSqlConnection; IDRaiz : integer; ExcluiLixeira : boolean = true);
var
  Qry : TSQLQuery;
  Pastas,
  Arquivos : TStringlist;
  i : integer;
begin
  Pastas := TStringlist.create;
  Arquivos := TStringlist.create;
  try

    Qry := TSQLQuery.create(nil);
    try
      Qry.SqlConnection := SqlConnection;
      Qry.SQL.Add('select Id, Tipo');
      Qry.Sql.add('from sistarq where idPai = :id');
      Qry.Sql.add('and id <> idpai');
      Qry.ParamByName('ID').asinteger := IDRaiz;
      Qry.open;
      while not Qry.Eof do begin
        if Qry.FieldByname('Tipo').asinteger in [ord(ta_pasta),ord(ta_lixeira)] then begin
          if (Qry.FieldByname('Tipo').asinteger <> ord(ta_lixeira)) or ExcluiLixeira then
            Pastas.add(inttostr(Qry.FieldByname('ID').asinteger));
        end
        else
          Arquivos.add(inttostr(Qry.FieldByname('ID').asinteger));
        Qry.next;
      end;
    finally
      Qry.free;
    end;

    for i := 0 to Arquivos.count-1 do
      ExcluiUmArquivo(SqlConnection,valint(Arquivos[i]));

    for i := 0 to Pastas.count-1 do begin
      ExcluiFilhosDoID(SqlConnection,valint(Pastas[i]));
      SqlConnection.ExecuteDirect('delete from sistarq where id='+inttostr(valint(Pastas[i])));
    end;

  finally
    Pastas.free;
    Arquivos.free;
  end;
end;

procedure ExcluiArvoreDocumentos(SqlConnection : TSqlConnection; IDRaiz : integer);
var
  Qry : TSQLQuery;
  Exclui : boolean;
begin
  Exclui := false;

  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.SQL.Add('select Id, Tipo');
    Qry.Sql.add('from sistarq where id = :id');
    Qry.ParamByName('ID').asinteger := IDRaiz;
    Qry.open;
    if not Qry.IsEmpty then
//      Exclui := Qry.FieldByname('Tipo').asinteger = ord(ta_raiz);
      Exclui := true;
  finally
    Qry.free;
  end;

  if Exclui then begin
    ExcluiFilhosDoID(SqlConnection,IDRaiz);
    SqlConnection.ExecuteDirect('delete from sistarq where id='+inttostr(IDRaiz));
  end;
end;

function ForcaPathDocumento(SqlConnection : TSqlConnection; IdPai : integer; Path : ansistring) : integer;
var
  pasta : ansistring;
  IdPasta : integer;
begin
  pasta := trim(path);
  if pasta > '' then
    pasta := palavra(Path,2,'/',#255,#255);
  if Pasta = '' then
    result := IdPai
  else begin
    IdPasta := LeIDdoDiretorio(SqlConnection,Pasta,IdPai);
    if IdPasta = -1 then
      IdPasta := InsereItemNaBaseSqlConnection(SqlConnection,IdPai,ord(ta_pasta),pasta);
    delete(Path,1,length(pasta)+1);
    result := ForcaPathDocumento(SqlConnection,IdPasta,Path);
  end;
end;

function LeIDdoItem(SqlConnection : TSqlConnection; 
                    Nome : string; 
                    idpai : integer;
                    BuscaComCaseSensitive : boolean = false): integer;
var
  Qry : TSQLQuery;
begin
  Qry := TSQLQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.Add('SELECT ID,NOME FROM SISTARQ');
    Qry.Sql.add('WHERE (IDPAI = :idpai)');
    Qry.ParamByName('idpai').asinteger := idpai;
    Qry.open;
    result := -1;
    while not Qry.Eof and (result < 0) do begin
      if ((not BuscaComCaseSensitive) and 
          (uppercase(Nome) = uppercase(Qry.FieldByName('NOME').asstring))) or
         (BuscaComCaseSensitive and (Nome = Qry.FieldByName('NOME').asstring)) then
          result := Qry.FieldByName('ID').asinteger;
       Qry.Next;
    end;
  finally
    Qry.free;
  end;
end;


function LeIDDoPath(SqlConnection : TSqlConnection; 
                    Path : ansistring; 
                    IDPai : integer;
                    BuscaComCaseSensitive : boolean = false): longint;
var
  resto,
  nome : ansistring;
  IDPasta : integer;
begin
  result := -1;
  Nome := palavra(path,2,'/',#255,#255);
  if NumPalavras(path,'/',#255,#255) < 2 then
    result := LeIDDoItem(SqlConnection,Nome,IDPai,BuscaComCaseSensitive)
  else begin
    IDPasta := LeIDdoDiretorio(SqlConnection,Nome,IDPai);
    if IDPasta >= 0 then begin
       resto := Path;
       delete(resto,1,length(Nome)+1);
        result := LeIDDoPath(SqlConnection,Resto,IDPasta,BuscaComCaseSensitive);
    end;
   end;
end;

function ExtensaoDocumentoID(SqlConnection : TSqlconnection; ID : integer) : string;
var
  Qry : TSqlQuery;
begin
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.Sql.text := 'select nome from sistarq where id = :id';
    Qry.parambyname('ID').asinteger := ID;
    Qry.open;
    if Qry.Isempty then
      raise exception.create('Documento não encontrado');
    result := uppercase(ExtractFileExt(Qry.FieldByName('Nome').asstring));
  finally
    Qry.free;
  end;
end;

procedure LeDocumento(ID : Integer; var ListaOut : TscciMemory);
Var
  Qry            : TSqlQuery;
  path           : string;
begin
  Qry := TSqlQuery.Create(nil);
  Try
    scislib.AbreConexao;

    //  Define campos a serem recuperados.
    Qry.SQL.Add( 'SELECT * FROM SISTARQ');
    Qry.SQL.Add( 'WHERE ID = :ID');
    Qry.SqlConnection := scislib.SCISConnection;
    Qry.ParamByName('ID').asinteger := ID;
    Qry.Open;
    if qry.isempty then
      raise exception.create('Documento não encontrado')
    else begin
      DataSetToMemory(Qry,'sistarq.',ListaOut);
      {$IFDEF XE}
      {$ELSE}
      //apesar da coluna ser blob o valor esta gravado como stringstream, e no DataSetToMemory ele le
      //como blob e devolve o valor errado. Vamos simplesmente remover do listaOut e adicionar de novo
      ListaOut.DeleteVal('sistarq.TE_OBSERVACAO_ARQUIVO');
      ListaOut.addval('TE_OBSERVACAO_ARQUIVO',Qry.fieldByName('TE_OBSERVACAO_ARQUIVO').asString);
      {$ENDIF}
      Path := GeraPath(scislib.SCISConnection,Qry.FieldByName('co_hierarquia_documento').asinteger);
      ListaOut.addval('sistarq.NO_HIERARQUIA_DOCUMENTO',Path);
    end;
    scislib.FechaConexao;
  Finally
    Qry.Free;
  end;
end;

Function GravarPropriedades (ID : integer;
                             Propaga : boolean;
                             CO_HIERARQUIA_DOCUMENTO,
                             TE_OBSERVACAO_ARQUIVO,
                             IN_CONTROLE_VERSAO,
                             IN_CRIA_VERSAO_ATUALIZADA,
                             IN_DOCUMENTO_OCULTO,
                             IN_DOCUMENTO_SO_LEITURA,
                             IN_EXIBE_PASTA : String;
                             IN_CONTROLE_ASSINATURA : string = 'F';
                             IN_TIPO_ASSINATURA : integer = 0;
                             QT_REPRESENTANTES_ASSIN : integer = 0) : String;
Var
    Qry       : TSqlQuery;
    TD        : TTransactionDesc;
    {$IFDEF XE}
      stream : tstringstream;
    {$ENDIF}
begin
    Qry      := TSqlQuery.create(nil);
    scislib.AbreConexao;
    try
        Qry.SqlConnection := SCISConnection;
        //  Define campos a serem recuperados.
        Qry.SQL.Add( 'UPDATE SISTARQ SET');
        Qry.SQL.Add( 'IN_CONTROLE_VERSAO = ' +
                     QuotedStr(IN_CONTROLE_VERSAO) + ',');
        Qry.SQL.Add( 'IN_CRIA_VERSAO_ATUALIZADA = ' +
                     QuotedStr(IN_CRIA_VERSAO_ATUALIZADA) + ',');
        Qry.SQL.Add( 'IN_DOCUMENTO_OCULTO = ' +
                     QuotedStr(IN_DOCUMENTO_OCULTO) + ',');
        Qry.SQL.Add( 'IN_DOCUMENTO_SO_LEITURA = ' +
                     QuotedStr(IN_DOCUMENTO_SO_LEITURA) + ',');
        Qry.SQL.Add( 'IN_EXIBE_PASTA = ' +
                     QuotedStr(IN_EXIBE_PASTA) + ',');
        Qry.SQL.Add('IN_CONTROLE_ASSINATURA = '+
                     QuotedStr(IN_CONTROLE_ASSINATURA) + ',');
        Qry.SQL.Add('IN_TIPO_ASSINATURA = '+
                     IntToStr(IN_TIPO_ASSINATURA) + ',');
        Qry.SQL.Add('QT_REPRESENTANTES_ASSIN = '+
                     IntToStr(QT_REPRESENTANTES_ASSIN) + ',');

        Qry.SQL.Add( 'TE_OBSERVACAO_ARQUIVO = :TE_OBSERVACAO_ARQUIVO,');
        if strtoint(CO_HIERARQUIA_DOCUMENTO) > 0 then
          Qry.SQL.Add(' CO_HIERARQUIA_DOCUMENTO = '+CO_HIERARQUIA_DOCUMENTO)
        else
          Qry.SQL.Add(' CO_HIERARQUIA_DOCUMENTO = NULL');
        Qry.SQL.Add( 'WHERE ID = ' + IntToStr ( ID ));

        {$IFDEF XE}
        Stream := TStringStream.create(TE_OBSERVACAO_ARQUIVO);
        try
          Stream.Position := 0;
          Qry.Params[0].DataType := ftBlob;
          Qry.Params[0].loadfromstream(stream,ftblob);
        finally
          Stream.free;
        end;
        {$ELSE}
          Qry.Params[0].DataType := ftBlob;
          Qry.Params[0].asBlob := BytesOf( TE_OBSERVACAO_ARQUIVO);
        {$ENDIF}
        
        if uppercase(SCISConnection.DriverName) <> 'OPENODBC' then 
        begin
          TD.TransactionID := ID;
          TD.IsolationLevel := xilReadCommitted;
          scislib.SCISConnection.StartTransaction(TD);
        end;
        try
            Qry.ExecSql;
            if  Propaga then begin
                Qry.SQL.Clear;
                Qry.SQL.Add( 'UPDATE SISTARQ SET');
                Qry.SQL.Add( 'IN_CONTROLE_VERSAO = ' +
                             QuotedStr(IN_CONTROLE_VERSAO) + ',');
                Qry.SQL.Add( 'IN_CRIA_VERSAO_ATUALIZADA = ' +
                             QuotedStr(IN_CRIA_VERSAO_ATUALIZADA) + ',');
                Qry.SQL.Add( 'IN_DOCUMENTO_OCULTO = ' +
                             QuotedStr(IN_DOCUMENTO_OCULTO) + ',');
                Qry.SQL.Add( 'IN_EXIBE_PASTA = ' +
                     QuotedStr(IN_EXIBE_PASTA) + ',');
                Qry.SQL.Add('IN_CONTROLE_ASSINATURA = '+
                     QuotedStr(IN_CONTROLE_ASSINATURA) + ',');
                Qry.SQL.Add('IN_TIPO_ASSINATURA = '+
                     IntToStr(IN_TIPO_ASSINATURA) + ',');
                Qry.SQL.Add('QT_REPRESENTANTES_ASSIN = '+
                     IntToStr(QT_REPRESENTANTES_ASSIN) + ',');

                Qry.SQL.Add( 'IN_DOCUMENTO_SO_LEITURA = ' +
                             QuotedStr(IN_DOCUMENTO_SO_LEITURA));

                Qry.SQL.Add( 'WHERE IDPAI = ' + IntToStr ( ID ));
                Qry.SQL.Add( 'AND   TIPO = 2');
                Qry.ExecSql;
            end;

            if uppercase(SCISConnection.drivername) <> 'OPENODBC' then
              scislib.SCISConnection.Commit(TD);
            Result := 'T';
        except
            on e : exception do begin
                Result := 'Ocorreu o seguinte erro ao atualizar ' +
                          'as propriedades - ' + e.message;
                if uppercase(SCISConnection.drivername) <> 'OPENODBC' then
                  scislib.SCISConnection.rollback(TD);
            end;

        end;

    Finally
        Qry.Close;
        Qry.Free;
        scislib.FechaConexao;
    end;
end;

function ExisteCtr(Ctr : TpCtr):boolean;
var
  wExisteCtr : boolean;
  MutDsk : TpMutDsk;

begin
  MutDsk.Cad.Ctr := '';
  fillchar(MutDsk,sizeof(MutDsk),0);
  Le_Arq_Fis;
  Abre_Cad;
  Le_MutDsk(Ctr,MutDsk);
  wExisteCtr := MutDsk.Cad.Ctr <> '';
  Fecha_Cad;

  Le_Arq_Fin;
  Abre_Cad;
  Le_MutDsk(Ctr,MutDsk);
  wExisteCtr := wExisteCtr or (MutDsk.Cad.Ctr <> '');
  Fecha_Cad;
  result := wExisteCtr;
end;

procedure LeArvore (IDRaiz : Integer; 
                   Grupo,
                   CtrDocumentos : String;
                   SomenteDiretorios : Boolean;
                   var Arvore : Tpxml);
var
  Id     : Integer;
begin
  scislib.AbreConexao;
  if Grupo > '' then
     Id := BuscaGrupoDoc(grupo,'Não foi possível encontrar pasta '+Grupo)
  else
    id := IDRaiz;
  if (id = 0) and (CtrDocumentos > '') then
    if ExisteCtr(CtrDocumentos) then
      id := GeraIDPaiDocumentosContrato(scislib.SCISConnection,CtrDocumentos)
    else
      raise exception.create('Contrato inexistente');
  MontaRaiz(Arvore.DocumentElement,id,true,SomenteDiretorios);
  Scislib.FechaConexao;
end;

procedure LePasta(StreamIn, StreamOut : TStream);
var
  ListaIn,
  Listaout     : TScciMemory;
  Pasta        : TpXml;
  Id     : Integer;
  leGlobal : boolean;
  Qry : TSqlQuery;
  teste : tstringstream;
begin
  Listain  := TScciMemory.Create;
  ListaOut := TScciMemory.Create;
  Pasta    := TpXml.create;
  Qry := TSqlQuery.create(nil);
  teste := tstringstream.create('');
  try
    ListaIn.LoadFromStream(StreamIn);
    teste.copyfrom(streamIn,0);
    teste.position := 0;

    scislib.AbreConexao;
    id := ListaIn.readint('id');
    if Listain.readbool('CriticaSeEhRaiz') then begin
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.Sql.add('select id from sistarq where id=:id and idpai=:id');
      Qry.parambyname('id').asinteger := id;
      qry.open;
      if qry.isempty then
        raise exception.create('Base de documentos inconsistente.');
      qry.close;
    end;

    // somente atualização automática para documentos de contrato.
    if Listain.readval('AtualizaPelaHierarquia') = '-1' then
      AtualizaArvoreDeDocumentos(scislib.SCISConnection,id,-1);
    leGlobal:= ListaIn.readbool('LeGlobal');
    
    MontaRaiz(LeGlobal,
              Pasta.DocumentElement,
              id,
              false,
              Listain.readbool('SomenteDiretorios'),
              ListaIn.Readbool('SomenteDiretoriosIncluiLixeira'),
              ListaIn.Readbool('ControlaAcesso'),
              ListaIn.Readbool('EhEvp'));

    Scislib.FechaConexao;
    ListaOut.AddVal('Pasta',Pasta.DocumentElement.code);
    ListaOut.addbool('resp',true);
    ListaOut.SaveToStream(StreamOut);
  finally
    Qry.free;
    Pasta.free;
    ListaIn.Free;
    ListaOut.Free;
  end;
end;

procedure RegistraLogExcDocumento(ListaIn : TScciMemory;NomeArq : string);
var
  Qry : TSqlQuery;
  XmlLog : TpXml;
  Inscricao : string;
  NuOperacao : string;
  msg : string;
  Caminho : string;

begin
  NuOperacao := '';
  Caminho := 'Lixeira';
  msg := 'Exclusão Permanente do Documento ';
  Inscricao := ListaIn.readval('Inscricao');
  XmlLog := TpXml.create;
  Qry := TSqlQuery.create(nil);
  try
    if inscricao > '' then begin
      Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
      Qry.Sql.add('SELECT NU_OPERACAO FROM OPERACAO_CREDITO');
      Qry.Sql.add('WHERE NU_PRETENDENTE='+QuotedStr(Inscricao));
      Qry.open;
      if not Qry.isEmpty then
        NuOperacao := intstr(Qry.FieldByName('NU_OPERACAO').asInteger);
      Qry.close;

      Qry.Sql.clear;
      Qry.Sql.add('SELECT NOME FROM SISTARQ');
      Qry.Sql.add('WHERE id='+intstr(ListaIn.readint('id')));
      Qry.open;
      if not Qry.isEmpty then
        NomeArq := Qry.FieldByName('NOME').asString;
      Qry.close;

      XmlLog.documentElement.nodename := 'LOG';
      XmlLog.DocumentElement.addchild('Operacao').nodevalue := NuOperacao;
      XmlLog.DocumentElement.addchild('Caminho/Nome').nodevalue := Caminho+'\'+NomeArq;
      XmlLog.DocumentElement.addchild('Pretendente').nodevalue := Inscricao;

      uloglib.GeraLog(logaplic_ExcDocumentosOriginacao,logseveridade_aviso,
                      PegaUsuario,msg,
                      ''{complemento},XmlLog,inscricao);
    end;
  finally
    XmlLog.free;
    Qry.free;
  end;
end;

procedure RegistraLogErro( msg : ansistring; inscricao : string; logaplic : TLogAplic);
var
  XmlLog : TpXml;
begin
  XmlLog := TpXml.create;
  try
    XmlLog.documentElement.nodename := 'LOG';
    XmlLog.DocumentElement.addchild('MsgErro').nodevalue := msg;

    if inscricao > '' then
      uloglib.GeraLog(logaplic,logseveridade_erro,
                      PegaUsuario,msg,
                      ''{complemento},XmlLog,inscricao);
  finally
    XmlLog.free;
  end;
end;

procedure ExcluiItem (StreamIn, StreamOut : TStream);
var
  ListaIn,
  Listaout : TScciMemory;
  Qry : TSqlQuery;
  QryA: TSqlQuery;
  FileList : TStringlist;
  FileNameFS : TFileName;
  sr : TSearchRec;
  i : integer;
  TD : TTransactionDesc;
  DateMobile : string;
  NomeArq : string;
begin
  NomeArq := '';
  try

  Listain  := TScciMemory.Create;
  ListaOut := TScciMemory.Create;
  try

    try
      ListaIn.LoadFromStream(StreamIn);
      
      DateMobile := Listain.readval('DateMobile');
      if DateMobile > '' then
        DateMobile := 'Data Mobile='+DateMobile;

      if trim(DateMobile) > '' then
        SysLogMobile.Inicio('excluiitem',DateMobile);
      
      scislib.AbreConexao;

      Qry := TSqlQuery.create(nil);
      QryA:= TSqlQuery.create(nil);
      FileList := TStringlist.create;
      try
        QryA.SqlConnection := SCISConnection;
        QryA.Sql.add('SELECT NOME FROM SISTARQ');
        QryA.Sql.add('WHERE id='+intstr(ListaIn.readint('id')));
        QryA.open;
        if not QryA.isEmpty then
          NomeArq := QryA.FieldByName('NOME').asString;
        QryA.close;

        Qry.SqlConnection := SCISConnection;
        TD.TransactionID := 1;
        TD.IsolationLevel := xilReadCommitted;
        SCISConnection.StartTransaction(TD);
        try

          if trim(DateMobile) > '' then
            SysLogMobile.Inicio('excluindo da base','id='+listain.readval('id'));

          Qry.Sql.Text := 'delete from CONTROLEVERSAO where id = :id';
          Qry.Params[0].asinteger := ListaIn.readint('ID');
          Qry.ExecSql;

          Qry.Sql.Text := 'delete from sistarq '+
                          'where id = :id';
          Qry.Params[0].asinteger := ListaIn.readint('ID');

{$IFDEF FPC}
          Qry.ExecSql;
{$ELSE}
          if Qry.ExecSql <> 1 then
            raise exception.create('Erro na exclusao');
{$ENDIF}

          if trim(DateMobile) > '' then
            SysLogMobile.Fim('excluindo da base');

          if trim(DateMobile) > '' then
            SysLogMobile.Inicio('excluindo do filesystem');

          FileNameFS := RetornaFileSystemName(ListaIn.readint('ID'),0);
          FileNameFS := ChangeFileExt(FileNameFS,'.*');
          if FindFirst(FileNameFS, 0, sr) = 0 then begin
            repeat
              FileList.add(IncludeTrailingPathDelimiter(ExtractFilePath(FileNameFS)) + sr.Name);
            until FindNext(sr) <> 0;
            FindClose(sr);
          end;
          for i := 0 to FileList.count-1 do
            DeleteFile(FileList[i]);
            
          if trim(DateMobile) > '' then
            SysLogMobile.Fim('excluindo do filesystem');

          SCISConnection.Commit(TD);
        except
          SCISConnection.rollback(TD);
          raise;
        end;
      finally
        FileList.free;
        Qry.free;
        QryA.free;
      end;
      scislib.FechaConexao;
      RegistraLogExcDocumento(ListaIn,NomeArq);

      ListaOut.addbool('resp',true);
    except
      on e : exception do begin
        if listain.readbool('GeraLogErro') then
          RegistraLogErro( ListaIn.readval('MsgLogErro')+' '+e.message,
                           ListaIn.readval('Inscricao'),
                           TLogAplic(ListaIn.readint('LogAplic')));
        raise;
      end;
    end;

    ListaOut.SaveToStream(StreamOut);
  finally
    ListaIn.Free;
    ListaOut.Free;
  end;
  if trim(DateMobile) > '' then
    SysLogMobile.Fim('excluiitem');
    
  except
    on e : exception do begin
      if trim(DateMobile) > '' then
        SysLogMobile.escreve(e.message);
      raise;
    end;
  end;

end;

procedure InsereItemBinario (StreamIn, StreamOut : TStream);
var
  ListaIn,
  Listaout : TScciMemory;
  Stream : TMemoryStream;
  ID : longint;
  TD: TTransactionDesc;
  Filename : Tfilename;
  FileStream : TFileStream;
  Nome : Ansistring;
  Xml : TpXml;
  extfile,lstext : Ansistring;
begin
  Listain  := TScciMemory.Create;
  ListaOut := TScciMemory.Create;
  Stream   := TMemoryStream.create;
  Xml      := TpXml.Create;
  try
    ListaIn.LoadFromStream(StreamIn);
    scislib.AbreConexao;
    TD.TransactionID := 1;
    TD.IsolationLevel := xilReadCommitted;
    scislib.SCISConnection.StartTransaction(TD);
    try
      Nome := ListaIn.readval('NOME');
      extfile := UpperCase(StringReplace(ExtractFileExt(nome),'.','',[rfReplaceAll]));
      lstext := UpperCase(GetEnv('EXTUPLPERMITIDO'));
      if (trim(lstext) <> '') and  (pos(extfile,lstext) <= 0) then raise exception.create('Tipo de arquivo não permitido.');


      ID := InsereItemNaBaseESeqNome( ListaIn.readint('IDPAI'),
                                      ListaIn.readint('TIPO'),
                                      Nome,
                                      ListaIn.ReadVal('IN_EXIBE_PASTAS'),
                                      Listain.readbool('SequenciaNome'));
      ListaOut.addval('Nome',Nome);
      if ListaIn.readint('TIPO') = ord(ta_Documento) then begin
        if ListaIn.readint('IDCopiar') > 0 then begin
          filename := makeTempFileName;
          FileStream := TFileStream.create(filename,fmcreate);
          try
            SaveDocumentoToStream(SCISConnection,ListaIn.readint('IDCopiar'),FileStream);
          finally
            FileStream.free;
          end;
          ListaOut.addint('VERSAO',InsereVersaoBinario(ID,0,filename));
          DeleteFile(filename);
        end
        else if ListaIn.readbool('ComStream') then begin
          FileStream := TFileStream.create(filename,FmCreate);
          try
            ListaIn.readstream('Stream',FileStream);
          finally
            FileStream.free;
          end;
          ListaOut.addint('VERSAO',InsereVersaoBinario(ID,0,filename));
          DeleteFile(FileName);
        end
        else
          ListaOut.addint('VERSAO',InsereVersao(ID,0,''));
        Xml.DocumentElement.Nodename := 'xml';
        Xml.add('Nome').asString := NomeDocumento(SCISConnection, ID);
        Xml.add('Pasta').asString := GeraPath(SCISConnection, ID);
        GeraLog(logaplic_AltModuloDocumentos,logseveridade_Aviso,PegaUsuario,'Inclusão de Documento','',
                Xml, SCISConnection);
      end;
      scislib.SCISConnection.Commit(TD);
    except
      scislib.SCISConnection.rollback(TD);
      raise;
    end;
    ListaOut.Addint('ID',ID);
    scislib.FechaConexao;
    ListaOut.addbool('resp',true);
    ListaOut.SaveToStream(StreamOut);
  finally
    ListaIn.Free;
    ListaOut.Free;
    Stream.free;
    Xml.free;
  end;
end;

procedure AlteraNome (StreamIn, StreamOut : TStream);
var
  ListaIn,
  Listaout : TScciMemory;
  Xml      : TpXml;
begin
  Listain  := TScciMemory.Create;
  ListaOut := TScciMemory.Create;
  Xml      := TpXml.Create;
  try
    ListaIn.LoadFromStream(StreamIn);
    Xml.add('NomeAntigo').asString := NomeDocumento(GetSqlConnection(PegaDirTab), ListaIn.ReadInt('ID')); 
    AlteraNomeDoc(ListaIn.ReadInt('ID'), ListaIn.readVal('Nome'));
    Xml.add('NomeNovo').asString := ListaIn.readVal('Nome');
    Xml.add('Pasta').asString := GeraPath(GetSqlConnection(PegaDirTab),ListaIn.ReadInt('ID')); 
    ListaOut.addbool('resp',true);
    ListaOut.SaveToStream(StreamOut);
    Xml.DocumentElement.Nodename := 'xml';
    GeraLog(logaplic_AltModuloDocumentos,logseveridade_Aviso,PegaUsuario,'Alteração do Nome','',
            Xml, GetSqlConnection(PegaDirTab));
  finally
    Xml.Free;
    ListaIn.Free;
    ListaOut.Free;
  end;
end;


function TestaeCriaPasta(pasta : AnsiString; IdPai : Integer = 0):integer;
var
  id : integer;
begin
  id :=  EncontraPastaPeloNome(GetSqlConnection(PegaDirTab),Pasta);
  
  if id <=0 then begin
    ID := InsereItemNaBaseSqlConnection(GetSqlConnection(PegaDirTab),
                                   idPai,
                                   1,
                                   Pasta,
                                   True); 
 end;
 result := id;
end; 

function adicionaArquivoSistArq(NomeArquivo, NomePasta: string):integer;
var
  id,
  idPai,
  idSistArq : integer;
  ErrorLog: TStringList;
  LogFileName: string;
begin
  result := 0;
  LogFileName := 'sistArq_log.txt'; 
  ErrorLog := TStringList.Create;
  id := TestaECriaPasta(NomePasta);
  idPai := TestaECriaPasta(NomePasta,Id);  
  try
    try
      idSistArq := InsereArquivo(GetSqlConnection(PegaDirTab), IdPai, ExtractFileName(NomeArquivo), NomeArquivo);
      if idSistArq > 0 then
        Result := idSistArq;
    except
      on E: Exception do
      begin
        if FileExists(LogFileName) then
          ErrorLog.LoadFromFile(LogFileName); // Carrega o conteúdo existente do arquivo de log
        ErrorLog.Add('Erro ao adicionar ao adicionar ao SistArq o arquivo:  ' + ExtractFileName(NomeArquivo) + '. ' + E.Message);
        ErrorLog.SaveToFile(LogFileName); // Salva o conteúdo atualizado do arquivo de log
      end;
    end;
  finally
    ErrorLog.Free;
  end;
end; 

function atualizaDocumentoEmSpcSerasa(idAndamentoSerasa, idSistArq : integer; arquivoCrit : string):boolean;
var
QryUpdate : TSqlQuery;
ErroStream: TFileStream;

begin
  QryUpdate := TSqlQuery.create(nil);
  ErroStream := TFileStream.Create(arquivoCrit, fmOpenRead);
  try
    QryUpdate.SQLConnection := GetSqlConnection(pegaDirAtv);
    QryUpdate.SQL.Add('UPDATE ANDAMENTO_SPC_SERASA');    
    QryUpdate.SQL.Add('SET ERRO = :erro, ARQUIVOSAIDA = :arquivosaida');
    QryUpdate.SQL.Add('WHERE ID = :id AND STATUS <> 1');
    QryUpdate.ParamByName('erro').LoadFromStream(ErroStream, ftBlob);
    QryUpdate.ParamByName('id').AsInteger := idAndamentoSerasa;         
    QryUpdate.ParamByName('arquivosaida').asstring := intToStr(idSistArq);  
    QryUpdate.ExecSQL;
    result := true;          
  finally
    QryUpdate.Free;
    ErroStream.Free;
  end;
end;

{$IFDEF FPC}
procedure ObtemArquivosExternosDoJasper(FileNameJasper : ansistring; Files : Tstrings);
var
  FileStream : TFileStream;
  StringStream : TStringStream;
  Re : TRegExpr;
  pc : pchar;
  st : ansistring;
begin
  if FileExists(FilenameJasper) then begin
    FileStream := TFileStream.create(FilenameJasper,FmOpenRead);
    StringStream := TStringStream.create('');
    try
      StringStream.copyfrom(FileStream,0);
      StringStream.position := 0;
      re := TRegExpr.Create('"[^"]+\.(png|PNG|jpg|JPG|jpeg|JPEG|gif|GIF|bmp|BMP|jasper)"');
      if re.Exec(StringStream.datastring) then begin
        pc := Pchar(re.Match[0]);
        st := AnsiExtractQuotedStr(pc,'"');
        Files.add(st);
        while re.ExecNext do begin
          pc := Pchar(re.Match[0]);
          st := AnsiExtractQuotedStr(pc,'"');
          Files.add(st);
        end;  
      end;    
    finally
      FileStream.free;
      StringStream.free;
    end;  
  end;  
end;
{$ENDIF}

function ObtemIDS (Operacao : Integer;
                   Caminho: String;
                   BuscaComCaseSensitive : boolean = false):Integer;
var

    IdPai,Id     : Longint;
begin
  IDPai := GeraIDPaiDocumentosPretendente(GetSqlConnection(PegaDirAtv),IntStr2(operacao,9));
  Caminho := StringReplace(Caminho,'\\','/',[rfReplaceAll]);
  Caminho := StringReplace(Caminho,'\','/',[rfReplaceAll]);

  if (Caminho = '') or (Caminho[1] <> '/') then
    Caminho := '/' + Caminho;

  id := LeIDdoPath(GetSqlConnection(PegaDirAtv),Caminho,IdPai,BuscaComCaseSensitive);
  result := id;
end;

function UtilizaScciEmDocker:boolean;
var
  Ini : TMemIniFile;
begin
  Ini := TMemIniFile.create(PegaDirAtv + pathdelim + 'launcherenv.ini');
  try
    result := lib1.strToBool(Ini.readString('ENVIRONMENT','UTILIZASCCIEMDOCKER',''));
  finally
    Ini.free;
  end;
end;

function LeEntradaSpcSerasa (SqlConnection: TSqlConnection; 
                             NomeArq: AnsiString; 
                             CaminhoSistarq: AnsiString = ''):AnsiString;
var
  caminho : AnsiString;
  idPasta,
  idSistarq : integer;
begin
  caminho := extractFilePath(NomeArq);
  if (not UtilizaScciEmDocker) then //configuracao launcherenv
    result := NomeArq
  else begin
    if caminhoSistarq > '' then
      caminho := caminhoSistarq;
    idPasta := LeIdDoPath(SqlConnection, caminho, 0);
    idSistarq := IdDoDocumento(SqlConnection, ExtractFileName(NomeArq), idPasta);
    if (idSistarq <= 0) and (CaminhoSistarq = '') then begin
      caminho := pathdelim + 'Configurações'+pathdelim+'Arquivos'+pathdelim+'SPC';
      idPasta := LeIdDoPath(SqlConnection, caminho, 0);
      idSistarq := IdDoDocumento(SqlConnection, ExtractFileName(NomeArq), idPasta);
    end;
    if (idSistarq <= 0) and (CaminhoSistarq = '') then begin
      caminho := pathdelim + 'Configurações'+pathdelim+'Arquivos'+pathdelim+'SERASA';
      idPasta := LeIdDoPath(SqlConnection, caminho, 0);
      idSistarq := IdDoDocumento(SqlConnection, ExtractFileName(NomeArq), idPasta);
    end;
    if idSistarq > 0 then begin
      result := MakeTempFileName;
      SaveDocumentoToFile(SqlConnection, idSistarq, result);
    end
    else if FileExists(NomeArq) then
      result := NomeArq
    else
      raise exception.create('Não foi possível encontrar o arquivo ' + NomeArq + '.');
  end;
end;

function InsereArquivoEDeletaOriginal(SqlConnection : TSqlConnection; 
                                       Caminho, FileName : AnsiString; 
                                       NomeNoSistarq : AnsiString = ''):Integer;
var
  idPasta: integer;
begin
  result := -1;
  if UtilizaScciEmDocker and fileExists(FileName) then begin
    if NomeNoSistarq = '' then
      NomeNoSistarq := extractFileName(FileName);
    idPasta := ForcaPathDocumento(SqlConnection, 0, caminho);
    result := InsereArquivoVersao(SqlConnection, idPasta, NomeNoSistarq, FileName);
    deleteFile(FileName);
  end;
end;

procedure InsereArquivosLista(SqlConnection : TSqlConnection; 
                              Caminho, ArquivoArqs : AnsiString);
var
  ListaArqs : TStringlist;
  i : integer;
begin
  ListaArqs := TStringlist.create;
  try
    ListaArqs.LoadFromFile(ArquivoArqs);
    for i := 0 to listaArqs.count - 1 do begin
      InsereArquivoEDeletaOriginal(SqlConnection, Caminho, listaArqs[i]);
    end;
  finally
    ListaArqs.free;
  end;
end;

function ProcuraArquivoCaminho(NomeArq, Caminho: AnsiString):integer;
var
  idPasta: integer;
  SqlConnection : TSqlConnection;
begin
  SqlConnection := GetSqlConnection(PegaDirtab);
  idPasta := LeIdDoPath(SqlConnection, caminho, 0);
  result := IdDoDocumento(SqlConnection, NomeArq, idPasta);
end;

function ProcuraSaidaSpcSerasa(var filename: AnsiString):boolean;
var
  NomeArq : AnsiString;
  i,
  idSistarq : Integer;
  listaDiretorios : array[0..5] of string;
begin
  //procura o arquivo em varios diretórios do SPC ou SERASA no sistarq
  listaDiretorios[0] := pathDelim+'Configurações'+pathdelim+'Arquivos'+pathdelim+'SPC';
  listaDiretorios[1] := pathDelim+'Configurações'+pathdelim+'Arquivos'+pathdelim+'SPC'+Pathdelim+'Retorno';
  listaDiretorios[2] := pathDelim+'Configurações'+pathdelim+'Arquivos'+pathdelim+'SERASA';
  listaDiretorios[3] := pathDelim+'Configurações'+pathdelim+'Arquivos'+pathdelim+'SERASA'+Pathdelim+'Retorno';
  listaDiretorios[4] := pathDelim+'Enviado ao SPC';
  listaDiretorios[5] := pathDelim+'Enviado ao SERASA';
  result := fileexists(fileName);
  if not result then begin
    nomeArq := ExtractFileName(filename);
    for i := 0 to length(listaDiretorios) -1 do begin
      idSistArq := ProcuraArquivoCaminho(NomeArq, listaDiretorios[i]);
      if idSistArq > 0 then begin
        //se achou define o result e sai do loop
        fileName := listaDiretorios[i] + pathdelim + nomeArq;
        result := true;
        break;
      end;
    end;
  end;
end;

initialization

finalization
  if assigned(gQryCopiaBinarioDocumento) then
    FreeAndNil(gQryCopiaBinarioDocumento);
end.
