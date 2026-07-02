program launcher;
{$IFDEF FPC}
{$DEFINE UseCThreads}
{$H-}
{$P+}
{$ELSE}
{$APPTYPE CONSOLE}
{$ENDIF}
uses
{$IFDEF FPC}
 cmem,cthreads,
{$ENDIF}
{$IFDEF KYLIX}
 Libc,
{$ENDIF}
{$IFDEF MSWINDOWS}
 Windows,ActiveX, IdWinSock, 
{$ENDIF}

{$IFDEF FPC} process, sockets, users, crypth,IdStack,IdStackConsts,IdGlobal,
 IdContext,pwd,shadow,IdCustomTCPServer,
 IdSocketHandle,unix, BaseUnix,strutils,
 synacrypt,synacode,synautil,IdThreadSafe,
{$ELSE}
 IdThreadMgrPool, Types,IdBaseComponent,IdTCPServer,synautil,synacode,
{$ENDIF}
{$IFDEF LINUX}
 punix, libcaptcha,
{$ENDIF}
 md5lib,SysUtils,Classes,IdComponent,IdException,
 SyncObjs,pIniFiles,pdb,pcrypt;

type

{$IFDEF FPC}
   TidPeerThread = TIdContext; 
   TMyProc = class(TProcess)
    private
      fd0, fd1,
      UserId, GroupID : integer;
      MyAThread : TidPeerThread;
    public
   end;
{$ENDIF}
  ECCP = class(Exception);
  ELOGINEXTERRO = class(exception);
  ECCP_Proto = class(Exception);


  TChar = set of char;
  TLauncherIni = class
    private
      FIniFile : TMemIniFile;
      FVirtualDir : TIdThreadSafeStringList;
      FGlobalEnv: TIdThreadSafeStringList;
      FNoDelay : boolean ;
      FMaxConn : longint;
      FChaveComum : TIdThreadSafeString;
      FIVComum : TIdThreadSafeString;
      FMultiReadExclusiveWriteSynchronizer : TMultiReadExclusiveWriteSynchronizer;
    public
      function VirtualPathToFisical(VirtualPath:AnsiString):AnsiString;
      constructor create;
      destructor destroy; override;
      procedure refresh;
      property ChaveComum : TIdThreadSafeString read FChaveComum ;
      property IVComum : TIdThreadSafeString read FIVComum ;
      property GlobalEnv : TIdThreadSafeStringList read FGlobalEnv;
      property NoDelay : boolean read FNoDelay;
      property MaxConn : longint read FMaxConn write FMaxConn;
      procedure BeginRead;
      procedure EndRead;
      procedure BeginWrite;
      procedure EndWrite;
  end;

  TSection = class
    private
      fUser,
      fSection_key : TIdThreadSafeString;
      fStatus : ansichar;
      fCaptcha : TIdThreadSafeString;
      flastlogin : TIdThreadSafeDateTime;
      fIPAcesso : TIdThreadSafeString;
      fInLogin,
      fInBloqueadoCaptcha : boolean;
      fContErroLogin : integer;
      
    public
      property Status: ansichar read fstatus write fstatus;
      property USer: TIdThreadSafeString read fuser write fUser;
      property SectionKey : TIdThreadSafeString read fsection_key write fSection_key;
      property Captcha : TIdThreadSafeString read fCaptcha write fCaptcha;
      property LastLogin : TIdThreadSafeDateTime read flastlogin write flastlogin;
      property IPAcesso : TIdThreadSafeString read fIPAcesso write fIPAcesso;
      property InLogin: boolean read fInLogin write fInLogin;
      property InBloqueadoCaptcha : boolean read fInBloqueadoCaptcha write fInBloqueadoCaptcha;
      property ContErroLogin : integer read fContErroLogin write fContErroLogin;
      constructor create;
      destructor destroy; override;
  end;

  TBaseUser = class
    private
      fuser,
      fhome,
      fPasswd : TIdThreadSafeString;
{$IFDEF LINUX}
      fAvisaMudaSenha,
      fViraInativaSenha,
      fExpiraSenha,
      fUltMudancaSenha : integer;
{$ENDIF}
      fMaxMudaSenha,
      fMinMudaSenha : integer;
      fDTValSenha,
      fUltAltSenha : TIdThreadSafeDateTime;
      fMustChange : boolean;
      fUserActive : boolean;
      fUserTentativasE : integer;
      fSenha1 : TIdThreadSafeString;            // Ultimas Senha  1
      fSenha2 : TIdThreadSafeString;            //  2
      fSenha3 : TIdThreadSafeString;            //  3
      fSenha4 : TIdThreadSafeString;            //  4
      fSenha5 : TIdThreadSafeString;            //  5
      fUltimoUso : TIdThreadSafeDateTime;
      fSectionTimeOut  : Integer;
    public
      constructor create(Usuario:AnsiString);
      destructor destroy; override;
      function SenhaOK(Senha:AnsiString):boolean;virtual; abstract;
      function TestPasswdDate:boolean;virtual; abstract;
      function TestMaxPass:boolean;virtual; abstract;
      function TestPasswdChange:boolean;virtual; abstract;
      procedure GetEnv(Env,GlobalEnv:TIdThreadSafeStringList); virtual; abstract;
      function SenhaUsada ( pw : string) : boolean; virtual; abstract;
      function LimiteDiasSenha( diasexpira : integer ) : boolean ; virtual; abstract;
      function SectionTimedOut : boolean;


      property user         : TIdThreadSafeString read fuser ;
      property home         : TIdThreadSafeString read fhome;
      property Passwd       : TIdThreadSafeString read fPasswd        write  fPAsswd;
      property MaxSenha     : integer    read fMaxMudaSenha  write  fMaxMudaSenha  ;
      property MinSenha     : integer    read fMinMudaSenha  write  fMinMudaSenha  ;
      property DtValSenha   : TIdThreadSafeDateTime read fDTValSenha    write  fDTValSenha ;
      property UltAltSenha  : TIdThreadSafeDateTime read fUltAltSenha   write  fUltAltSenha  ;
      property MustChange   : boolean read fMustChange write fMustChange ;
      property UserActive   : boolean read fUserActive write fUserActive;
      property UserTentativasE : integer read fUserTentativasE write fUserTentativasE;
      property Senha1       : TIdThreadSafeString read fSenha1 write fSenha1;
      property Senha2       : TIdThreadSafeString read fSenha2 write fSenha2;
      property Senha3       : TIdThreadSafeString read fSenha3 write fSenha3;
      property Senha4       : TIdThreadSafeString read fSenha4 write fSenha4;
      property Senha5       : TIdThreadSafeString read fSenha5 write fSenha5;
      property SectionTimeOut : integer read fSectionTimeOut write fSectionTimeOut;
      property UltimoUso    : TIdThreadSafeDateTime read fUltimoUso write fUltimoUso;

  end;


  TDBUser = class ( TBaseUser )
  private
      fDriverName : TIdThreadSafeString;
  public 
      constructor create(Usuario:AnsiString);
      destructor destroy; override;

      function SenhaOK(Senha:AnsiString):boolean; override;
      function TestPasswdDate:boolean; override;
      function TestMaxPass:boolean; override;
      function TestPasswdChange:boolean;override;
      procedure GetEnv(Env,GlobalEnv:TIdThreadSafeStringList); override;
      function SenhaUsada ( pw : string) : boolean;override;
      function LimiteDiasSenha( diasexpira : integer ) : boolean ; override;
      property DriverName : TIdThreadSafeString read fDriverName write fDriverName ;
  end;

  TWSDBUser = class ( TBaseUser )
  private
  public 
      function SenhaOK(Senha:AnsiString):boolean; override;
      function TestPasswdDate:boolean; override;
      function TestMaxPass:boolean; override;
      function TestPasswdChange:boolean;override;
      procedure GetEnv(Env,GlobalEnv:TIdThreadSafeStringList); override;
      function SenhaUsada ( pw : string) : boolean;override;
      function LimiteDiasSenha( diasexpira : integer ) : boolean ; override;
  end;

  TLinuxUser = class(TBaseUser)
    private
      fshell : TIdThreadSafeString;
    public
      constructor create(Usuario:AnsiString);
      destructor destroy; override;
      procedure GetEnv(Env,GlobalEnv:TIdThreadSafeStringList); override;
      property shell : TIdThreadSafeString read fshell;
      function SenhaOK(Senha:AnsiString):boolean; override;
      function SenhaUsada ( pw : string) : boolean;override;
      function LimiteDiasSenha( diasexpira : integer ) : boolean ; override;
      function TestPasswdDate:boolean; override;
      function TestMaxPass:boolean;override;
      function TestPasswdChange:boolean;override;
  end;
 
  TLauncherEnv = class { Gerencia a configuração das bases de dados }
    private
      FTemCaptcha : boolean;
      FTemIni : boolean;
      FPath : TIdThreadSafeString;
      FIniFileEnvironment,
      FIniFileUser,
      FIniFileElastic: TIdThreadSafeStringList;
      FMultiReadExclusiveWriteSynchronizer : TMultiReadExclusiveWriteSynchronizer;
      FOwner,
      FGroup : Integer;
      FSeg_sistema,
      FLoginErrStr,
      FLoginStr,
      FLogoffStr,
      FLogPassStr,
      FSeg_servico,
      FSeg_identificacao,
      FDBStr : TIdThreadSafeString;
      FSeg_PermiteRedefinirSenha : TIdThreadSafeBoolean;
      fMinCaracPass : integer;  // Qtd minima de caract. da senha = sem mínimo
      fCaracPass : TIdThreadSafeString;      // Requer q a senha tenha letras enum = nao
      fMinAlfaPass : integer;   // Qtd minima de letras = sem mínimo
      fMinAlfaMaisPass : integer; // Qtd minima de maiusculas = sem mínimo
      fMinNumPass : integer;    // Qtd minima de numeros = sem mínimo
      fCarMinEspPass : integer; // Qtd minima de caracteres especiais
      fDiasExpira : integer;    // Quantidade de dias para expirar a senha
      fMaxTentativasErroCaptcha,
      fMaxTentativasErro : integer;
      fFazRodizio : boolean;       // Indica se tem ou nao rodizio de senhas ( senha1..5 ausentes no launcherenv.ini )
      fMaxRepPass,
      fMaxSeqPass : integer;
      fLOGIN_ERR_DELAY: Integer;
      FACESSOSSIMULTANEOS : longint;
      FVerificaSectionKeyBD : boolean; // Indica se deve ou nao procurar a chave de seçao no banco de dados apos uma falha no teste de senha ok
      function FMeminiFileReadString(st1,st2,def:AnsiString):AnsiString;
    public
      FPasswdList : TIdThreadSafeStringList;
      FSectionList:  TIdThreadSafeStringList;    ////////////////////////VOLTAR PARA CIMA!!!!
      constructor create(Path:string);
      destructor destroy; override;
      function GetSection(User_section:String):TSection;
      function GetUser( User: string ) : TBaseUser;
      procedure GetEnv(Env,GlobalEnv :TIdThreadSafeStringList);
      property LoginErrStr: TIdThreadSafeString read fLoginErrStr;
      property LoginStr: TIdThreadSafeString read fLoginStr;
      property LogoffStr : TIdThreadSafeString  read fLogoffStr;
      property LogPassStr : TIdThreadSafeString  read fLogpassStr;
      property TemCaptcha: Boolean read FTemCaptcha;
      property TemIni: Boolean read FTemIni;
      property Owner : Integer read FOwner;
      property Group : Integer read FGroup;
      property RealPath  : TIdThreadSafeString read FPath;
      property ACESSOSSIMULTANEOS: longint read FACESSOSSIMULTANEOS write FACESSOSSIMULTANEOS;
      property VerificaSectionKeyBD : boolean read FVerificaSectionKeyBD write FVerificaSectionKeyBD;
{$IFDEF FPC}
      function LoadDBUsers(usuario : string) : TDBUser ;
{$ELSE}
      procedure LoadDBUsers(usuario:string);
{$ENDIF}
      procedure SetGlobalVars(User : TBaseUser);
      procedure GravaSenhaBD(usuario,senha:string);
      procedure LimpaSenhas;
      procedure GravaExpiracao(usuario:string);
      procedure GravaSenhaErrada(usuario:string;erros:integer);
      function SegurancaWS : boolean;
      function RevalidaWSLogin(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer; 
                             Usuario:string; var  Senha: ansistring;var ult_login : tdatetime; QtMaxLogin : integer = 0) : char;
      function LeSegurancaWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer; 
                             Usuario:string; var  Senha: ansistring; QTDMAXLOGIN : integer; wIP : string) : char;
      function TrocaSenhaWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer; 
                             Usuario:string; var  Senha: Ansistring;
                             NovaSenha : string;wtoken : string;Var pErro : string): char;
      function EmailPasswordWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring; CPF: string;Var pErro : string): char;


      property MinCaracPass : Integer read fMinCaracPass write fMinCaracPass;
      property MinAlfaPass  : integer read fMinAlfaPass write fminAlfaPass;
      property MinAlfaMaisPass : integer read fMinAlfaMaisPass write fMinAlfaMaisPass;
      property CarMinEspPass : integer read fCarMinEspPass write fCarMinEspPass;
      property Servico : TIdThreadSafeString  read FSeg_servico write FSeg_servico;
      property PermiteRedefinirSenha : TIdThreadSafeBoolean  read FSeg_PermiteRedefinirSenha write FSeg_PermiteRedefinirSenha;
      property Sistema : TIdThreadSafeString  read FSeg_sistema write FSeg_sistema;
      property MinNumPass : integer read fMinNumPass write fMinNumPass;
      property CaracPass    : TIdThreadSafeString read fCaracPass write fCaracPass;
      property DiasExpira   : integer read fDiasExpira write fDiasExpira;
      property MaxTentativasErro : integer read fMaxTentativasErro;
      property MaxTentativasErroCaptcha : integer read fMaxTentativasErroCaptcha;
      property FazRodizio: boolean read fFazRodizio;
      property MaxRepPass: integer read fMaxRepPass write fMaxRepPass;
      property MaxSeqPass: integer read fMaxSeqPass write fMaxSeqPass;
      procedure LimpaCache(User:String);
      procedure BeginRead;
      procedure EndRead;
      procedure BeginWrite;
      procedure EndWrite;
      function  GetItem (i : integer): string;
      function  Count : integer;
      function VerificaSessionKeyExpirada(usuario, senha : string):boolean;
      property LOGIN_ERR_DELAY: integer read fLOGIN_ERR_DELAY write fLOGIN_ERR_DELAY;
  end;


  TLauncherEnvList = class { Gerencia uma lista em memoria de objetos TLauncherEnv }
  private
    FLista : TIdThreadSafeStringList;
    FMultiReadExclusiveWriteSynchronizer : TMultiReadExclusiveWriteSynchronizer;
    FReset : boolean;
  public 
    constructor create;
    destructor destroy; override;
    function GetLauncherEnv(Path:String):TLauncherEnv;
    function Count : integer;
    function GetItem( i : integer): string;

    procedure Clear;
    procedure BeginRead;
    procedure EndRead;
    procedure BeginWrite;
    procedure EndWrite;
    property Reset:boolean read FReset write FReset;

  end;


  TDisplayMessageEvent = procedure(const Message:String) of object;
{$IFDEF FPC}
  TCCPServer = class(TIdCustomTCPServer)
{$ELSE}
  TCCPServer = class(TIdTCPServer)
{$ENDIF}
    protected
      FOnDisplayMessage : TDisplayMessageEvent;
      LauncherEnvList : TLauncherEnvList;
      function AlteraSenha(Usuario:ansistring; var Senha :ansistring) : boolean;
      function ProgramExecute(Usuario : string; var senha : ansistring; 
                              ParmExtra : string ; Path, Programa:String; 
                              Env : TIdThreadSafeStringList;
                              LoginStr,LogOffStr,LogPassStr : string;
                              AThread :  TidPeerThread;
                              WSLogin      : boolean = false; // É WebService
                              UserID:Integer=0; GroupId:Integer=0; 
 			      SenhaAntiga:Boolean=false;
                              wSenhaAntiga:integer=-999;
                              NovoModoOp : boolean = false; 
                              wtoken : string = '';
                              Criptografa : boolean = false;
                              Salt : string = '';
                              wsistema : string = '';
                              wPermiteRedefinirSenha : boolean = false;
                              wOrigem : string = ''):boolean;
    public
//      function MyDoExecute(AThread: TIdPeerThread):boolean ;  override;
      procedure MyDoExecute(AThread: TIdPeerThread) ;
      procedure DoDisplayMessage(Message:String);
{$IFDEF FPC}
      constructor Create(AOwner: TComponent); 
{$ELSE}
      constructor Create(AOwner: TComponent); override;
{$ENDIF}
//      procedure HandleError(T:TIdContext;E:Exception);
      procedure ExecLog(Athread :TidPeerThread;Env:TIdThreadSafeStringList;UserId,GroupID : integer;LogStr,ParmExtra:string; Session_Key : string = '');
      destructor destroy; override;
    published
      property OnDisplayMessage:TDisplayMessageEvent read FOnDisplayMessage write FOnDisplayMessage;
  end;

  TServer= class(Tobject)
  private
    { Private declarations }
    uilock : TCriticalSection ;
    procedure DisplayMessage(const Msg: string);
  public
    CCPServer1: TCCPServer;
    { Public declarations }
    constructor create;
    destructor destroy; override;
    procedure run(porta : integer);
  end;

{$IFDEF MSWINDOWS}
function CreateEnvBlock(const NewEnv: TStrings; 
const IncludeCurrent: Boolean;
  const Buffer: Pointer; 
  const BufSize: Integer): Integer; forward;
{$ENDIF}


AES_MODE = (CFB,ECB,CBC,OFB );
{---------------------------------------------------------------------------}
const
//     IDX_READ_PIPE = 0;
//     IDX_WRITE_PIPE = 1;
//     MAXBUF = 160000;
     RSLT_HDR    = #$F1;
     RSLT_HDR_ST = #$F2;
     SRV_HDR     = #$F3;
//     PASS_HDR    = #$F4;
//     METD_HDR_Z  = #$F7;
//     METD_HDR_K_Z= #$F8;
//     DATA_HDR_Z  = #$F9;
//     METD_HDR    = #$FA;
//     DATA_HDR   = #$FB;
//     METD_HDR_K  = #$FC;
     EXCEPT_HDR  = #$FD;
     SRV_HDR_CRYPT = #$FE;
     SRV_WS_OK        = ord('W');
     SRV_WS_NOK       = ord('X');
     SRV_WS_NOPASS    = ord('Y');
     SRV_OK           = ord('T');
     SRV_PING_REPLY   = ord('P');
     SRV_NOK          = ord('F');
     SRV_NOK_CAPTCHA  = ord('D');
     SRV_NOK_NOPASS   = ord('B');
     SRV_NOK_EXPIRED  = ord('E');
     SRV_NOK_CHANGE   = ord('M');
     SRV_NOK_MUSTCHANGE=ord('C');
     SRV_NOK_INACTIVE = ord('I');
     SRV_NOK_ACESSO   = ord('A');
     SRV_NOK_BLOCK    = ord('L');
     SRV_NOK_MSG      = ord('G');
     SRV_EXPIRED      = ord('J');
     SRV_NOK_QTACESSO = ord('Q');
     MinsPerDay       = 24 * 60; 
     TAMBUFOBJETO     = 8192;
{$IFDEF MSWINDOWS}
  ENVDELIM = ';';
{$ELSE}
  ENVDELIM = ':';
{$ENDIF}
     MAXSTR = 1024;
{$IFDEF LINUX}
type
  TPtrStr = array [1..MAXSTR] of pchar;
{$ENDIF}
var
{$IFDEF FPC}
  CritSecEnv,CritSec : TCriticalSection;
  PodeLiberar : longint; // Para controle da liberação ( semaforo )
{$ENDIF}
  LauncherIni : TLauncherIni;
  Server : TServer;
  FimLoop : boolean;
  Porta : integer;
  TemLog : boolean;
  SaidaPadrao : boolean;
  listenerfd : integer;
  Deletando : boolean = false;

function GeraCaptcha : ansistring; forward;
procedure writeres(AThread : TidPeerThread;retorno : longint); forward;
procedure writeres_st(AThread : TidPeerThread;st : ansistring); forward;
procedure SetAmbiente(Ambiente:TIdThreadSafeStringList); forward; overload;
{$IFDEF LINUX}
procedure SetAmbiente(Ambiente:TIdThreadSafeStringList; var stamb : TPtrStr); forward; overload;
{$ENDIF}
function expande(wAmbVar : string) : String; forward; overload;
function expande(wAmbVar : string;  Env : TIdThreadSafeStringList) : String; forward; overload;
procedure expande(Env : TIdThreadSafeStringList); forward; overload; //Expande todo o ambiente
procedure WriteLog(st:string); forward;
function decrypt(st : ansistring) : ansistring;      forward;


//============================================================================//
                        { Rotinas Comuns }

constructor TSection.create;
begin
  inherited;
  fUser := TIdThreadSafeString.Create;
  fSection_key := TIdThreadSafeString.Create;
  fCaptcha:= TIdThreadSafeString.Create;
  flastlogin := TIdThreadSafeDateTime.Create;
  fIPAcesso := TIdThreadSafeString.Create;
end;

destructor TSection.destroy;
begin
  fUser.free;
  fSection_key.free;
  fCaptcha.free;
  flastlogin.free;
  fIPAcesso.free;
  inherited;
end;

function TestTimeBetweenCalls(minutesToTest:longint) : boolean;
const
  T1 : double = 0;
  T2 : double = 0;
begin
  result := false;
  if minutesToTest = 0 then // reset counters
  begin
    t1 := now;
    t2 := now;
  end
  else begin
  if T1 = 0 then t1 := now;
    T2 := now;
    if((T2-T1)*100000 > 60 * minutesToTest ) then // 10 miniutos rele o localtime
    begin
      result := true;
      t1 := now;
      t2 := now;
    end;
  end;
end;

{$IFDEF MSWINDOWS}
function SenhaSeq ( senha : string; maxseq : integer): boolean ;
var i ,
    contrep: integer;
begin
  i := 1;
  contrep := 0;
  while (i <= length(senha) - 1) and (contrep < maxseq -1) do
  begin
    if ord(senha[i])+1 = ord(senha[i+1]) then inc(contrep) else contrep := 0;
    inc(i);
  end;
  result := contrep =( maxseq -1);
end;

function SenhaRep ( senha : string; maxrep : integer): boolean ;
var i ,
    contrep: integer;
begin
  i := 1;
  contrep := 0;
  while (i <= length(senha) - 1) and (contrep < maxrep-1) do
  begin
    if senha[i] = senha[i+1] then inc(contrep) else contrep := 0;
    inc(i);
  end;
  result := contrep = (maxrep -1);
end;

procedure ContaCaractersSenha(senha : string; Var NNum, Nalfa, Nesp, NMaiusculas : integer);
const
     CARACESP = [ '#','$','%','*','@','?','!', ';' , '{', '}', '|', '[', ']', '+', '-', '/', '\', '>','<' , '.','(', ')' ,'&', ':'];
var
  i : integer;
begin
  NNum := 0;
  NAlfa := 0;
  NEsp := 0;
  NMaiusculas := 0;
  for i := 1 to length(senha) do begin
    if senha[i] in ['0'..'9'] then inc(NNum)
    else begin
      if senha[i] in CARACESP then inc(NEsp)
      else begin
        if senha[i] in ['A'..'Z'] then inc(NMaiusculas);
        inc(NAlfa);
      end;
    end;
  end;
end;



procedure Validasenha(Senha : string; MinCarac, MinAlfaPass, MinAlfaMaisPass,MinNumPass,MaxRepPass, MaxSeqPass : integer; CaracPass : string; CarMinEspPass : integer);
var
  Msgs : Tstringlist;
  Msg : ansistring;
  i : integer;
  TemRep,TemSeq : boolean;
  NNum,
  Nalfa,
  Nesp,
  NMaiusculas : integer;
begin
  NNum := 0;
  NAlfa:= 0;
  NEsp := 0;
  NMaiusculas := 0;
  CaracPass := uppercase(CaracPass);
  Msgs := TStringlist.create;
  try
    if MinCarac > 0 then
      Msgs.add('conter no mínimo '+inttostr(MinCarac)+' caracteres');
    if CaracPass = 'SIM' then begin
      if (MinAlfaPass > 0) and (MinNumPass > 0) then
        Msgs.add('ser formada por letras e números');
      if MinAlfaPass > 0 then
        Msgs.add('ter o mínimo de '+inttostr(MinAlfaPass)+' letra(s)');
      if MinAlfaMaisPass > 0 then
        Msgs.add('ter pelo menos '+inttostr(MinAlfaMaisPass)+' letra(s) maiúscula(s)');
      if MinNumPass > 0 then
        Msgs.add('ter o mínimo de '+inttostr(MinNumPass)+' dígito(s)');
      if CarMinEspPass > 0 then
        if CarMinEspPass = 1 then
          Msgs.add('ter o pelo menos um caracter especial')
        else
          Msgs.add('ter o mínimo de '+inttostr(CarMinEspPass)+' caracteres especiais');
    end;
    TemRep := SenhaRep(Senha,MaxRepPass);
    if TemRep then Msgs.add('A senha não deve conter mais que '+InttoStr(MaxRepPass)+' caracteres repetidos ');
    TemSeq := SenhaSeq(Senha,MaxSeqPass);
    if TemSeq then Msgs.add('A senha não deve conter mais que '+InttoStr(MaxSeqPass)+' caracteres em sequência ');
    if Msgs.count > 0 then begin
      if not TemRep and  not TemSeq then Msg := 'A senha deve ';
      if Msgs.count > 1 then begin
        for i := 0 to Msgs.count-2 do begin
          if i > 0 then
            Msg := msg + ', ';
          Msg := Msg + Msgs[i];
        end;
        Msg := Msg + ' e '+msgs[Msgs.count-1];
      end
      else
        Msg := Msg + msgs[Msgs.count-1];
      if (CaracPass = 'SIM') and (CarMinEspPass=0) then
        Msg := Msg + '. Também podem ser utilizados os caracteres especiais existentes no teclado';
    end
    else
      Msg := 'Senha inválida';
  finally
    Msgs.free;
  end;

  ContaCaractersSenha(senha,NNum, Nalfa, Nesp, NMaiusculas);
  if (length(Senha) < MinCarac) or TemRep or TemSeq or
     ((CaracPass = 'SIM') and ((NAlfa<MinAlfaPass) or (NMaiusculas < MinAlfaMaisPass) or (NNum < MinNumPass) or (NEsp < CarMinEspPass))) then
    raise Exception.Create(Msg);
end;


{$ENDIF}

{$IFDEF FPC}

{
function aescrypt(key,iv,buf : string;modo : AES_MODE = CFB ) : string;
var
  aes : tsynaaes;
begin
  result := '';
  aes := tsynaaes.create(key);
  aes.SetIV(PadString(iv,16,#0));
  try
    case  modo of
      CBC : result := aes.EncryptCBC(PadString(buf,succ(length(buf) div 16) * 16,#0));
      CFB : result := aes.EncryptCFBblock(buf);
      ECB : result := aes.EncryptECB(buf); // 16 bytes
    end;
  finally 
    aes.free;
  end;
end;
}
function aesdecrypt(key , iv , buf : ansistring; modo : AES_MODE = CFB ) : ansistring;
var
  aes : tsynaaes;
begin
  result := '';
  iv := PadString(iv,16,#0);
  aes := tsynaaes.create(key);
  aes.SetIV(iv);
  try
    case  modo of
      CBC : result := aes.DeCryptCBC(buf);
      CFB : result := aes.DeCryptCFBblock(buf);
      ECB : result := aes.DeCryptECB(buf); // 16 bytes
    end;
  finally 
    aes.free;
  end;
end;
{$ENDIF}

function Mod1(st,modf : string) : string;
begin
  modf := copy(modf,1,8);
  result := copy(st,1,2) + modf[1] +
            copy(st,4,1) + modf[2] +
            copy(st,6,1) + modf[3] +
            copy(st,8,1) + modf[4] +
            copy(st,10,1) + modf[5] +
            copy(st,12,1) + modf[6] + 
            copy(st,14,1) + modf[7] + 
            copy(st,16,1) + modf[8] + 
            copy(st,18,length(st));
end;

{
function Mod2(st,modf : string) : string;
begin
  modf := copy(modf,1,8);
  result := copy(st,1,5) + modf[1] +
            copy(st,7,2) + modf[2] +
            copy(st,11,2) + modf[3] +
            copy(st,14,2) + modf[4] +
            copy(st,17,2) + modf[5] +
            copy(st,20,2) + modf[6] + 
            copy(st,23,2) + modf[7] + 
            copy(st,26,2) + modf[8] + 
            copy(st,29,length(st));
end;
}

function GeraCaptcha : ansistring;
begin
{$IFDEF FPC}
  result :=  copy(inttostr((fpGetPid * (trunc(time*1000000) mod 1000) +  trunc(time*1000000) mod 100000) mod 1000000),1,7);
{$ELSE}
  result :=  copy(inttostr((GetPid * (trunc(time*1000000) mod 1000) +  trunc(time*1000000) mod 100000) mod 1000000),1,7);
{$ENDIF}
end;



{$IFDEF FPC}
function tiraaspas(st : string) : string;
begin
  if (st <> '') and (st[1] = '"')  then
    result := ExtractDelimited(2,st,['"'])
  else result := ExtractDelimited(1,st,[':']);
end;

function splitpair(pair : ansistring; out pvar,pvalue : ansistring ) : integer;
var ps : integer;
begin
  result := 0;
  pvar := '';
  pvalue := '';
  if pair <> '' then
  begin
    if pair[1] = ':' then
    begin
      result := 2;
    end
    else begin
      ps := pos('=',pair);
      if ps > 0 then
      begin
        pvar := copy(pair,1,ps-1);
        pvalue := tiraaspas(copy(pair,ps+1,length(pair)));
        result := ps + 4 + length(pvalue);
        if pair[ps+1] <> '"' then result := result - 2;
      end
      else begin
        pvar := ExtractDelimited(1,pair,[':']);
        result := length(pair) + 2 ;
      end;
    end;
  end;
end;
{$ELSE}
procedure splitpair(pair : string; out pvar,pvalue : string );
var ps : integer;
begin
  pvar := '';
  pvalue := '';
  ps := pos('=',pair);
  if ps > 0 then
  begin
      pvar := copy(pair,1,ps-1);
      pvalue := copy(pair,ps+1,length(pair));
  end
  else pvar := pair;
end;
{$ENDIF}

function GetPath(Path : string; len: integer; var Pos : integer) : string;
begin
  result := '';
  while (pos <= len) and (path[pos] = ENVDELIM) do inc(pos);
  while (pos <= len) and (path[pos] <> ENVDELIM) do
  begin
    result := result + path[pos];
    inc(pos);
  end;
end;

function TemPerm ( Prog : string ) : boolean;
begin
  result := false;
  {$IFDEF FPC}
  if fpAccess(Prog,X_OK) = 0 then result := true;
  {$ENDIF}
end;

function ExecPath(PATH,Pgm : string) : ansistring;
var
pos, len : integer;
wpath : string;
begin
  result := '';
  pos := 1;
  len := length(PATH);
  wpath := GetPath(PATH,len,pos);
  while  wpath > '' do
  begin
{$IFDEF LINUX}
    if FileExists(wpath+PathDelim+Pgm) then
    begin
      result := wpath+PathDelim+Pgm;
      break;
    end;
{$ELSE}
    if FileExists(wpath+PathDelim+Pgm+'.exe') then
    begin
      result := wpath+PathDelim+Pgm+'.exe';
     break;
    end;
{$ENDIF}    
    wpath := GetPath(PATH,len,pos);
  end;
end;

procedure WriteLog(st:string);
var f : text;
begin
    if TemLog then
    begin
      try
        assign (f,'/var/log/launcher.'+inttostr(GetPid)+'.log');
        try
          if not FileExists('/var/log/launcher.'+inttostr(GetPid)+'.log') then rewrite(f)
          else  append(f);
          writeln(f,st);
        finally
          close(f);
        end;
      except 
      end;
    end 
    else if SaidaPadrao then 
           try
             st := st + #10;__write(1,st[1],length(st));;
           except 
           end;
end;						
						
function DBINIT(nomebase,driver,user,pass:string; HostName : string = '127.0.0.1'):TSqlConnection;
var 
        DB : TSqlConnection;
{$IFDEF MSWINDOWS}
        WinDir : pchar;
{$ENDIF}
begin
{$IFDEF FPC}
  result := nil;
{$ENDIF}
  try
        DB := TSqlConnection.Create(nil);
        if driver = 'ORACLE' then
	begin
          DB.ConnectionName := 'ORACLEConnection';
          DB.DriverName := 'ORACLE';
{$IFDEF LINUX}
          DB.VendorLib := 'libclntsh.so';
          DB.LibraryName := 'libsqloda.so';
{$ELSE}
          DB.VendorLib := 'OCI.DLL';
     	  DB.LibraryName := 'dbexpoda.dll';
{$ENDIF}
          DB.GetDriverFunc := 'getSQLDriverORA';
 	end
        else if driver = 'ORANET' then
        begin
          DB.ConnectionName := 'ORACLEConnection';
          DB.DriverName := 'ORACLE';
{$IFDEF LINUX}
          DB.VendorLib := 'libclntsh.so';
          DB.LibraryName := 'libsqloda.so';
{$ELSE}
          DB.VendorLib := 'OCI.DLL';
     	  DB.LibraryName := 'dbexpoda.dll';
{$ENDIF}
          DB.GetDriverFunc := 'getSQLDriverORANET';
        end
        else if driver = 'MYSQL' then
        begin
          DB.ConnectionName := 'MySQLConnection';
          DB.DriverName := 'MySQL';
{$IFDEF LINUX}
          DB.VendorLib := 'libmysqlclient.so.10.0.0';
      	  DB.LibraryName := 'libsqlmy.so';
{$ELSE}
          getmem(WinDir,81);
          GetSystemDirectory(WinDir,80);
          DB.VendorLib := WinDir+'\myqslclient.dll';
          DB.LibraryName := WinDir+'\libsqlmy.dll';
          if not FileExists (DB.VendorLib) then raise Exception.Create('Arquivo inexistente : '+DB.VendorLib);
          if not FileExists (DB.LibraryName) then raise Exception.Create('Arquivo inexistente : '+DB.LibraryName);
          freemem(WinDir,81);
{$ENDIF}
          DB.GetDriverFunc := 'getSQLDriverMYSQL';
	  DB.Params.Add('HostName='+HostName);
        end
        else if driver = 'ODBC' then
        begin
          DB.ConnectionName := 'ODBConnection';
          DB.DriverName := 'OpenOdbc';
{$IFDEF LINUX}
          DB.VendorLib := '';
          DB.LibraryName := '';
{$ELSE}
          getmem(WinDir,81);
          GetSystemDirectory(WinDir,80);
          DB.VendorLib := WinDir+'\ODBC32.DLL';
          DB.LibraryName := WinDir+'\dbxoodbc.dll';
          DB.Params.Values['BlobSize'] := '-1';
          DB.Params.Values['RowsetSize'] := '20';
          DB.Params.Values['Trim Char'] := '1';
          DB.Params.Values['Custom String'] := 'coNetPacketSize=8192;coLockMode=17;coBlobChunkSize=40960';

          if not FileExists (DB.VendorLib) then raise Exception.Create('Arquivo inexistente : '+DB.VendorLib);
          if not FileExists (DB.LibraryName) then raise Exception.Create('Arquivo inexistente : '+DB.LibraryName);
          freemem(WinDir,81);
{$ENDIF}
          DB.GetDriverFunc := 'getSQLDriverODBC';
        end
        else if driver = 'POSTGRES' then
        begin
          DB.ConnectionName := 'PQConnection';
          DB.DriverName := 'POSTGRES';
	  DB.VendorLib := 'libpq.so';
	  DB.LibraryName := 'libpq.so';
	  DB.Params.Add('HostName='+HostName);
	  DB.GetDriverFunc := 'getSQLDriverPq';
        end
        else if driver = 'MSSQL' then
        begin
          DB.ConnectionName := 'MSSQLConnection';
          DB.DriverName := 'MSSQL';
{$IFDEF LINUX}
          DB.VendorLib := '';
          DB.LibraryName := '';
          DB.Params.Add('HostName='+HostName);	  
{$ELSE}
          DB.VendorLib := 'sqloledb.dll';
          DB.LibraryName := 'dbexpsda.dll';
          CoInitialize(nil);
	  DB.Params.Add('HostName='+HostName);
          DB.LoginPrompt := false;
          DB.Params.Values['BlobSize'] := '-1';
{$ENDIF}
          DB.GetDriverFunc := 'getSQLDriverSQLServer';
        end
    	else begin
          if (trim(HostName)<> '') 
          //  nd (HostName <> '127.0.0.1') and (HostName <> 'localhost')  // Tem que setar diretamente, mesmo ser root tem que funcioanar como serviço.
          then 
            DB.Params.Add('HostName='+HostName);	  
          DB.ConnectionName := 'INTERBASEConnection';
          DB.DriverName := 'INTERBASE';
{$IFDEF LINUX}
          DB.VendorLib := 'libgds.so.0';
          DB.LibraryName := 'libsqlida.so';
          DB.GetDriverFunc := 'getSQLDriverInterBase';
{$ELSE}
          getmem(WinDir,81);
          GetSystemDirectory(WinDir,80);
          DB.VendorLib := WinDir+'\GDS32.DLL';
          DB.LibraryName := WinDir+'\dbexpint.dll';
          if not FileExists (DB.VendorLib) then raise Exception.Create('Arquivo inexistente : '+DB.VendorLib);
          if not FileExists (DB.LibraryName) then raise Exception.Create('Arquivo inexistente : '+DB.LibraryName);
          freemem(WinDir);
          DB.GetDriverFunc := 'getSQLDriverINTERBASE';
{$ENDIF}
        end;
        DB.Params.add('Database='+NomeBase);
        if (driver = 'MYSQL') or (driver = 'POSTGRES') then DB.Params.add('User_Name='+User)
        else DB.Params.add('User_Name='+UpperCase(User));
        DB.Params.add('Password='+Pass);
{$IFDEF FPC}
//        critsec.acquire;
{$ENDIF}	
	try
          DB.connected := true;
          result := DB;
	finally
{$IFDEF FPC}
//	  critsec.release;	   
{$ENDIF}	
        end;  
  except
    on e: exception do
    begin
      if assigned(db) then freeandnil(db);
      writelog('  ==== Erro de Conexao  ao BANCO DE DADOS !!!');
      raise Exception.Create('Erro na Conexao '+e.message);
    end;
  end;
end;
 
function pegaval(var st:string):longword; { pega valor separado por espaço de }
                                        { tras pra frente em uma string }
var i : int64;
begin
{
  i := length(st);
  while  (i > 1) and (st[i] <> ' ') do dec(i);
  result := strtoint(copy(st,i,length(st)));
  delete(st,i,length(st));
}
  i := pos(' ',st);
  try
    if i <= 0 then i := length(st);
    result := strtoint64(copy(st,1,i-1));
  except
    result := 0;
  end;
  delete(st,1,i);
  while copy(st,1,1) = ' ' do  delete(st,1,1);
end;

function CalcIdle : integer;
var f : text;
    st : string;
    Tot,idle1,idle2,sys1,sys2,user1,user2 : int64;
begin
  try
    assign(f,'/proc/stat');
    reset(f);
    readln(f,st);
    close(f);
    pegaval(st);
    user1 := pegaval(st);
    pegaval(st);
    sys1 := pegaval(st);
    idle1 := pegaval(st);

    sleep(100);

    assign(f,'/proc/stat');
    reset(f);
    readln(f,st);
    pegaval(st);
    user2 := pegaval(st);
    pegaval(st);
    sys2 := pegaval(st);
    idle2 := pegaval(st);
    close(f);
    Tot := (idle2-idle1) + (sys2-sys1) + (user2-user1);
    if tot > 0 then
      result := (idle2-idle1)*100 div tot
    else result := 0;
  except
    result := 0;
  end;
end;

{$IFDEF LINUX}
procedure tratadebug(l: LongInt); cdecl;
var i,j : integer;
begin
    if (TemLog or SaidaPadrao) and assigned(Server) then
    begin
      WriteLog(' Listas de usuarios : '+inttostr(Server.CCPServer1.LauncherEnvList.count));
      for i := 0 to Server.CCPServer1.LauncherEnvList.count -1 do
      begin
        WriteLog('Ambiente : '+Server.CCPServer1.LauncherEnvList.GetItem(i)+' com ' + inttostr((Server.CCPServer1.LauncherEnvList.GetLauncherEnv(Server.CCPServer1.LauncherEnvList.GetItem(i)) As TLauncherEnv).count) + ' usuarios');

        for j := 0 to (Server.CCPServer1.LauncherEnvList.GetLauncherEnv(Server.CCPServer1.LauncherEnvList.GetItem(i)) As TLauncherEnv).count - 1 do
         WriteLog(Server.CCPServer1.LauncherEnvList.GetLauncherEnv(Server.CCPServer1.LauncherEnvList.GetItem(i)).GetItem(j));
      end;
    end;
    TemLog := not TemLog;
end;

procedure tratahup(l: LongInt); cdecl;
begin
{$IFDEF FPC}
  try
    TestTimeBetweenCalls(0);
    writelog('Sinal HUP recebido');
    if assigned(Server.CCPServer1.LauncherEnvList) then
      Server.CCPServer1.LauncherEnvList.Reset := true;
  except 
    WriteLog('Erro ao renovar o ambiente ( hup )');
  end;
  if Server.CCPServer1.MaxConnections > 0 then
    Server.CCPServer1.MaxConnections := LauncherIni.MaxConn;
  fpsignal(SIGHUP,@tratahup);
{$ELSE}
  writelog('Relendo a configuração');
  if assigned(LauncherIni) then
    LauncherIni.Refresh;
  if assigned(Server) then
    Server.CCPServer1.LauncherEnvList.Clear;
  if Server.CCPServer1.MaxConnections > 0 then
    Server.CCPServer1.MaxConnections := LauncherIni.MaxConn;
  signal(SIGHUP,tratahup);
{$ENDIF}
end;
{$ENDIF}

procedure trataquit(l: LongInt); cdecl;
begin
        writelog('Saindo por sinal QUIT');
        FimLoop := true;
end;

procedure trataterm(l: LongInt); cdecl;
begin
        writelog('Saindo por sinal TERM');
        FimLoop := true;
end;


procedure trataint(l: LongInt); cdecl;
begin
        writelog('Saindo por sinal INT');
        FimLoop := true;
end;

{$IFNDEF FPC}

procedure tratakill(l: LongInt); cdecl;
begin
        writelog('Saindo por sinal KILL');
        FimLoop := true;
end;
{$ENDIF}

function decrypt(st:ansistring):ansistring;
var
  i : integer;
begin
  result := '';
  i := 1;
  while (i < length(st)) do
  begin
    result := result + chr(ord(st[i]) - ord('a') + ((ord(st[i+1]) - ord('a') )shl 4));
    inc(i,2);
  end;
end;


//============================================================================//
    {TLauncherIni - Leitura da configuração inicial do /etc/launcher.conf}

function TLauncherIni.VirtualPathToFisical(VirtualPath:AnsiString):AnsiString;
var
  found : boolean;
  i : integer;
  len : integer;
begin
  BeginRead;
  try
    Result := '';
    i := 0;
    found := false;
    if copy(VirtualPath,1,1) = PathDelim then delete(VirtualPath,1,1);
    while (i < FVirtualDir.Count) and not found do
    begin
      len := length(FVirtualDir.Names[i]);
      if (copy(VirtualPath,1,len) = FVirtualDir.Names[i]) and
         (copy(VirtualPath,len+1,1) = PathDelim ) then
      begin
        Found := true;
        Result := FVirtualDir.Values[FVirtualDir.Names[i]] + copy(VirtualPath,len+1,MaxInt);
      end;
      inc(i);   
    end; 
  finally
    EndRead;
  end;
end;

constructor TLauncherIni.create;
begin
  inherited;
  FMultiReadExclusiveWriteSynchronizer := TMultiReadExclusiveWriteSynchronizer.Create;
  FVirtualDir := TIdThreadSafeStringList.Create;
  FGlobalEnv:= TIdThreadSafeStringList.Create;
  FChaveComum := TIdThreadSafeString.Create;
  FIVComum := TIdThreadSafeString.Create;
  FIniFile := nil;
  FNoDelay := false;
  FMaxConn := 0;
  Refresh;
end;

destructor TLauncherIni.destroy; 
begin
  freeAndNil(FMultiReadExclusiveWriteSynchronizer);
  freeAndNil(FIniFile);
  freeandNil(FGlobalEnv);
  freeAndNil(FVirtualDir);
  freeAndNil(FChaveComum);
  freeAndNil(FIVComum);
  inherited;
end;

procedure TLauncherIni.Refresh;
var
  i       : integer;
  DirPath : AnsiString;
  wvirtualdir,wGlobalEnv : TstringList;
{$IFNDEF LINUX}
  WinDir  : pchar;
{$ENDIF}
begin
  BeginWrite;
  wvirtualdir:= TStringList.Create;
  wGlobalEnv := TStringList.Create;
  try
    critsecenv.acquire;
    if assigned(FIniFile) then FIniFile.free;
    if FileExists('launcher.conf') then
      FIniFile := TMemIniFile.Create('launcher.conf')
    else
    begin
{$IFDEF LINUX}
      if FileExists('/etc/launcher.conf') then
        FIniFile := TMemIniFile.Create('/etc/launcher.conf')
      else WriteLog( 'launcher.conf nao encontrado em : /etc');
{$ELSE}
      getmem(WinDir,81);
      GetSystemDirectory(WinDir,80);
      if FileExists(windir+'\launcher.conf') then
        FIniFile := TMemIniFile.Create(windir+'\launcher.conf')
      else WriteLog('launcher.conf nao encontrado em : '+windir);
      freemem(WinDir);
{$ENDIF}
    end;
    FVirtualDir.Clear;
    Finifile.ReadSectionValues('DIRETORIOS',wvirtualdir);
    fvirtualdir.Assign(wvirtualdir);

    for i := 0 to FVirtualDir.Count -1 do
    begin
      DirPath := FVirtualDir.Values[FVirtualDir.Names[i]];
{$IFNDEF LINUX}  // para evitar warning
      if PathDelim <> '/' then
        DirPath := StringReplace(DirPath,'/',PathDelim,[rfReplaceAll]);
{$ENDIF}
      if (copy(DirPath,1,1) <> PathDelim) and (copy(DirPath,2,2) <> ':'+PathDelim) then 
        DirPath := PathDelim  + DirPath;
      FVirtualDir.Values[FVirtualDir.Names[i]] := DirPath;
    end;
    FGlobalEnv.Clear;
    Finifile.ReadSectionValues('ENV',wglobalenv);  // Leitura das variaveis de ambiente globais.
    fglobalenv.assign(wglobalEnv);
    if FGlobalEnv.Values['TMP'] = '' then FGlobalEnv.Add('TMP=/var/tmp');
    FNoDelay :=  FGlobalEnv.Values['NODELAY'] = '1';
    FChaveComum.Value :=  FGlobalEnv.Values['CHAVE_COMUM'];
    if FChaveComum.Value = '' then FChaveComum.Value :=  'iDajpt6RujmyZhxM7kbVVI==';
    FIVComum.Value :=  FGlobalEnv.Values['IV_COMUM'];
    if FIVComum.Value = '' then FIVComum.Value :=     '8qzYJ7ULNNU6sle9nDAuQg==';
    FMaxConn := 0;
    try 
      if FGlobalEnv.Values['MAXCONN'] <> '' then FMaxConn := strtoint(FGlobalEnv.Values['MAXCONN']) ;
    except 
    end;
//  SetAmbiente( FGlobalEnv); // inserido na lista ENV que posteriormente é setada
  finally
    Critsecenv.release;
    EndWrite;
    freeandnil(wvirtualdir);
    freeandnil(wglobalenv);
  end;
end;

procedure TLauncherIni.BeginRead;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.BeginRead;
{$ENDIF}
end;

procedure TLauncherIni.EndRead;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.EndRead;
{$ENDIF}
end;

procedure TLauncherIni.BeginWrite;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.BeginWrite;
{$ENDIF}
end;

procedure TLauncherIni.EndWrite;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.EndWrite;
{$ENDIF}
end;

//============================================================================//
{TLauncherEnvList - Lista de ambientes indexada pelo path}

constructor TLauncherEnvList.create;
begin
  inherited;
  Flista := TIdThreadSafeStringList.Create;
  FLista.OwnsObjects := true;
  Flista.CaseSensitive := true;
  Flista.Sorted := true;
  FReset := false;
  FMultiReadExclusiveWriteSynchronizer := TMultiReadExclusiveWriteSynchronizer.Create;
end;

procedure TLauncherEnvList.Clear;
var
  i : integer;
begin
  if assigned(FLista) then 
    Flista.Clear;
end;

destructor TLauncherEnvList.destroy;
begin
  try
    BeginWrite; 
    Clear;  
    FLista.free;
  finally
    EndWrite; 
    FMultiReadExclusiveWriteSynchronizer.Free; 
  end;
  inherited;
end;

function TLauncherEnvList.GetLauncherEnv(Path:String):TLauncherEnv;
var
  Index : Integer;
begin
{$IFDEF FPC}
  result := nil;
{$ENDIF}
  BeginRead;
  CritSec.Acquire;
  try
    if FLista.Find(Path,Index) then { Já existe na lista }
      Result := FLista.Objects[Index] as TLauncherEnv
    else
    begin
        if FLista.Find(Path,Index) then {é necessário pesquisar outra vez, porque outra thread pode ter criado}
          Result := FLista.Objects[Index] as TLauncherEnv
        else
        try
          Result := TLauncherEnv.Create(Path);
{$IFNDEF FPC}
          if not Result.SegurancaWS then Result.LoadDBUsers('');
{$ENDIF}
          BeginWrite;
          try 
            FLista.AddObject(trim(Path),result);
          finally
            EndWrite;
          end;
        except 
          Result := Nil;
	  raise ECCP_Proto.Create('Erro ao Ler configurações do usuário');
	end;;
    end;
  finally
    CritSec.Release;
    EndRead;
  end;
end;

procedure TLauncherEnvList.BeginRead;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.BeginRead;
{$ENDIF}
end;

procedure TLauncherEnvlist.EndRead;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.EndRead;
{$ENDIF}
end;

procedure TLauncherEnvList.BeginWrite;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.BeginWrite;
{$ENDIF}
end;

procedure TLauncherEnvList.EndWrite;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.EndWrite;
{$ENDIF}
end;

function TLauncherEnvList.Count : integer;
begin
  result := Flista.Count;
end;

function TLauncherEnvList.GetItem( i : integer): string;
begin
  result := FLista[i];
end;

//============================================================================//
                          {TLauncherEnv}

constructor TLauncherEnv.create(Path:string);
{$IFDEF FPC}
var
  StatBuffer: stat;
  LMemIniFile: TMemIniFile;
  wenv: TStringList;
{$ELSE}
{$IFDEF LINUX}
var StatBuffer: TStatBuf;
{$ENDIF}
{$ENDIF}
begin
  inherited create;
  
  FPath := TIdThreadSafeString.Create;
  FSeg_sistema := TIdThreadSafeString.Create;
  FLoginErrStr := TIdThreadSafeString.Create;
  FLoginStr := TIdThreadSafeString.Create;
  FLogoffStr := TIdThreadSafeString.Create;
  FLogPassStr := TIdThreadSafeString.Create;
  FSeg_servico := TIdThreadSafeString.Create;
  FSeg_identificacao := TIdThreadSafeString.Create;
  FDBStr := TIdThreadSafeString.Create;
  FSeg_PermiteRedefinirSenha := TIdThreadSafeBoolean.Create;
  fCaracPass := TIdThreadSafeString.Create;
  FMultiReadExclusiveWriteSynchronizer := TMultiReadExclusiveWriteSynchronizer.Create;
  FPasswdList := TIdThreadSafeStringList.Create;
  FPasswdList.OwnsObjects := true;
  FSectionList := TIdThreadSafeStringList.Create;
  FSectionList.OwnsObjects := true;
  FSectionList.Sorted := true;
  FSectionList.CaseSensitive := true;
  FPasswdList.Sorted := true;
  FPasswdList.CaseSensitive := true;
  FPath.Value := LauncherIni.VirtualPathToFisical(Path);
  FIniFileEnvironment := TIdThreadSafeStringList.Create;
  FIniFIleUser := TIdThreadSafeStringList.Create;
  FIniFileElastic := TIdThreadSafeStringList.Create;
  LMemIniFile := TMemIniFile.Create(FPath.Value+PathDelim+'launcherenv.ini');
  wenv := TStringList.Create;
  try
  LMemIniFile.ReadSectionValues('ENVIRONMENT',wenv);
  FIniFileEnvironment.assign(wenv);
  wenv.clear;
  LMemIniFile.ReadSectionValues('USERS',wenv);
  FIniFileUser.assign(wenv);
  wenv.clear;
  LMemIniFile.ReadSectionValues('ELASTICSEARCH',wenv);
  FIniFileElastic.assign(wenv);
  FdbStr.Value := LMeminiFile.ReadString('USERS','DB','');
  FSeg_sistema.Value := LMeminiFile.ReadString('SEGURANCA','SEG_SISTEMA','');
  FSeg_servico.Value := LMeminiFile.ReadString('SEGURANCA','SEG_SERVICO','');
  FSeg_identificacao.value := LMeminiFile.ReadString('SEGURANCA','SEG_IDENTIFICACAO','');
  FSeg_PermiteRedefinirSenha.value := compareText(LMeminiFile.ReadString('SEGURANCA','PermiteRedefinirSenha','FALSO'),'SIM') = 0;
  FTemCaptcha := LMeminiFile.ReadString('USERS','USERVALIDACAPTCHA','NAO') = 'SIM';
  FLoginStr.Value := LMeminiFile.ReadString('LOG','LOGIN','');
  FLoginErrStr.Value := LMeminiFile.ReadString('LOG','LOGINERR','');
  FLogoffStr.Value := LMeminiFile.ReadString('LOG','LOGOFF','');
  FLogPassStr.Value := LMeminiFile.ReadString('LOG','LOGPASSWD','');
  fMaxTentativasErro := 9999;
  fMaxTentativasErroCaptcha := 9999;
  fACESSOSSIMULTANEOS:=9999;
  fVerificaSectionKeyBD := false;
  FTemIni := false;
  if assigned(LauncherIni) then
    LauncherIni.MaxConn := strtoint(LMeminiFile.ReadString('ENVIRONMENT','MAXCONN','0'));
{$IFDEF LINUX}
{$IFNDEF FPC}
  if stat(PChar(FPath+'/'+'launcherenv.ini'), StatBuffer) <> -1 then
{$ELSE}
  StatBuffer.st_uid := 0;
  StatBuffer.st_gid := 0;
  if fpstat (FPath.Value+'/'+'launcherenv.ini',StatBuffer) <> -1 then
{$ENDIF}

  begin
     FOwner := StatBuffer.st_uid;
     FGroup := StatBuffer.st_gid;
     FTemIni := true;
  end;
{$ELSE}
  if FileExists(FPath+'\'+'launcherenv.ini') then
  begin
        FOwner := 0;
        FGroup := 0;
        FTemIni := true;
  end;
{$ENDIF}
  finally
    LMemIniFile.free;
    wenv.free;
  end;
end;

destructor TLauncherEnv.destroy;
var
  i : integer;
begin
  try
    if assigned(FPasswdList) then  FPasswdList.Clear;
    if assigned(FSectionList) then FSectionList.Clear;
  finally
    FreeAndNil(FPasswdList);
    FreeAndNil(FSectionList);
    //FreeAndNil(FMemIniFile);
    FreeAndNil(FIniFileUser);
    FreeAndNil(FIniFileElastic);
    FreeAndNil(FIniFileEnvironment);
    FreeAndNil(FMultiReadExclusiveWriteSynchronizer);
    FreeAndNil(FPath);
    FreeAndNil(FSeg_sistema);
    FreeAndNil(FLoginErrStr);
    FreeAndNil(FLoginStr);
    FreeAndNil(FLogoffStr);
    FreeAndNil(FLogPassStr);
    FreeAndNil(FSeg_servico);
    FreeAndNil(FSeg_identificacao);
    FreeAndNil(FSeg_PermiteRedefinirSenha);
    FreeAndNil(FDBStr);
    FreeAndNil(fCaracPass);
    EndWrite;
  end;
  inherited;
end;

procedure TLauncherEnv.GetEnv(Env,GlobalEnv :TIdThreadSafeStringList);
begin
  Env.Clear;
  env.assign(FIniFileEnvironment);
  env.append(FIniFileUSER);
  env.append(FIniFileElastic);
  env.append(GlobalEnv);
  if FIniFileUSER.count > 0 then env.Add('DBUSERS=true')
  else env.Add('DBUSERS=false');
end;

{$IFDEF FPC}
function TLauncherEnv.LoadDBUsers(usuario : string) : TDBUser ;
{$ELSE}
procedure TLauncherEnv.LoadDBUsers(usuario:string);
{$ENDIF}
var
        QRY : TSQLQuery;
        userfield, userpasswd, usertable, userdtvalid, userlastpass, 
        userminpass, usermaxpass,usermustchange,useractive,userdriver,
        usenha1, usenha2,usenha3,usenha4,usenha5,usernumtentativa,
        wdelay,wtimeout,wint,dbuser,dbpass,dbhost : string;
        DBArq : TSqlConnection;
        USER_REG : TDBUser;
{$IFDEF FPC}
	i : integer;
{$ENDIF}
begin
{$IFDEF FPC}
  result := nil;
{$ENDIF}
  QRY := nil;
  DBArq := nil;
  if FTemIni then
  begin
    //dbuser := FMEminiFile.ReadString('USERS','DB_USER','');
    dbuser := FIniFileUser.values['DB_USER'];
    //dbPass := FMeminiFile.ReadString('USERS','DB_PASS','');
    dbpass := FIniFileUser.values['DB_PASS'];
    TrataSenhaEncriptografada(dbPass);
    //dbHost := FMeminiFile.ReadString('USERS','DB_HOSTNAME','localhost');
    dbHost := FIniFileUser.values['DB_HOSTNAME'];
    if dbHost = '' then dbHost := 'localhost';
    //userdriver:= uppercase(FMeminiFile.ReadString('USERS','DRIVERNAME','INTERBASE'));
    userdriver := uppercase(FIniFileUser.values['DRIVERNAME']);
    if userdriver = '' then userdriver := 'INTERBASE';
    if (trim(Fdbstr.value)<>'') and (trim(dbuser)<>'') and (trim(dbPass)<>'') then
    try
      {$IFDEF FPC}
//      CritSec.Acquire;
      {$ENDIF}
      QRY := TSQLQuery.Create(nil);
      if (trim(dbPass)<>'') then 
        DBArq := DBINIT(FdbStr.value,userdriver,DBUSER,DBPASS,DBHOST)
      else DBArq:= DBINIT(FdbStr.value,userdriver,DBUSER,decrypt(DBPASS),DBHOST);
      QRY.SqlConnection := DBArq;
      try
        userfield := FIniFileUser.values['USERFIELD'];
        if trim(userfield) = '' then userfield := 'CO_USUARIO';
        userpasswd:= FIniFileUser.values['USERPASSWORD'];
	if trim(userpasswd)  = '' then  userpasswd := 'CO_SENHA';
        usertable := FIniFileUser.values['USERTABLE'];
        if trim(usertable)  = '' then   usertable := 'USUARIO';
        userdtvalid := FIniFileUser.values['USERDTVALID'];
        userlastpass := FIniFileUser.values['USERLASTPASS'];
        userminpass := FIniFileUser.values['USERMINPASS'];
        usermaxpass := FIniFileUser.values['USERMAXPASS'];
        usermustchange := FIniFileUser.values['USERMUSTCHANGE'];
        useractive := FIniFileUser.values['USERACTIVE'];
        usernumtentativa := FIniFileUser.values['USERNUMTENTATIVA'];

//        userfield := FMeminiFile.ReadString('USERS','USERFIELD','CO_USUARIO');
//        userpasswd:= FMeminiFile.ReadString('USERS','USERPASSWORD','CO_SENHA');
//        usertable := FMeminiFile.ReadString('USERS','USERTABLE','USUARIO');
//        userdtvalid := FMeminiFile.ReadString('USERS','USERDTVALID','');
//        userlastpass := FMeminiFile.ReadString('USERS','USERLASTPASS','');
//        userminpass := FMeminiFile.ReadString('USERS','USERMINPASS','');
//        usermaxpass := FMeminiFile.ReadString('USERS','USERMAXPASS','');
//        usermustchange := FMeminiFile.ReadString('USERS','USERMUSTCHANGE','');
//        useractive := FMeminiFile.ReadString('USERS','USERACTIVE','');
//        usernumtentativa := FMeminiFile.ReadString('USERS','USERNUMTENTATIVA','');

        //wdelay := FMeminiFile.ReadString('ENVIRONMENT','LOGIN_ERR_DELAY','3');
        wdelay := FIniFileEnvironment.values['LOGIN_ERR_DELAY'];
        if trim(wdelay) = '' then
          fLogin_Err_Delay := 3
        else
          fLogin_Err_Delay := StrToInt(wdelay);
        //wtimeout := FMeminiFile.ReadString('ENVIRONMENT','GLOBALTIMEOUT','0');
        wtimeout  := FIniFileEnvironment.values['GLOBALTIMEOUT'];
        if trim(wtimeout) = '' then wtimeout := '0';
        //wint := FMeminiFile.ReadString('ENVIRONMENT','USERMINCARACPASS','1');
        wint := FIniFileEnvironment.values['USERMINCARACPASS'];
        if trim(wint) = '' then
          fMinCaracPass := 1
        else
          fMinCaracPass := StrToInt(wint);
        //wint := FMeminiFile.ReadString('ENVIRONMENT','CARMINALFAPASS','1');
        wint := FIniFileEnvironment.values['CARMINALFAPASS'];
        if trim(wint) = '' then
          fMinAlfaPass := 1
        else
          fMinAlfaPass := StrToInt(wint);
        //wint := FMeminiFile.ReadString('ENVIRONMENT','CARMINALFAMAISPASS','1');
        wint := FIniFileEnvironment.values['CARMINALFAMAISPASS'];
        if trim(wint) = '' then
          fMinAlfaMaisPass := 1
        else
          fMinAlfaMaisPass := StrToInt(wint);
        wint := FIniFileEnvironment.values['CARMINESPPASS'];
        if trim(wint) = '' then
          fCarMinEspPass := 1
        else
          fCarMinEspPass := StrToInt(wint);

        //wint := FMeminiFile.ReadString('ENVIRONMENT','CARMINNUMPASS','1');
        wint := FIniFileEnvironment.values['CARMINNUMPASS'];
        if trim(wint) = '' then
          fMinNumPass := 1
        else
          fMinNumPass := StrToInt(wint);
          
	//fCaracPass := uppercase(FMeminiFile.ReadString('ENVIRONMENT','USERCARACPASS','NAO')) ;
	fCaracPass.value := FIniFileEnvironment.values['USERCARACPASS'];
	if trim(fCaracPass.value) = '' then fCaracPass.value := 'NAO';
	//wint := FMeminiFile.ReadString('ENVIRONMENT','USERDIASEXPIRA','0');
        wint := FIniFileEnvironment.values['USERDIASEXPIRA'];
        if trim(wint) = '' then
          fDiasExpira := 0
        else
          fDiasExpira := StrToInt(wint);
        //wint := FMeminiFile.ReadString('ENVIRONMENT','MAXTENTATIVAERROCAPTCHA','9999');
        wint := FIniFileEnvironment.values['MAXTENTATIVAERROCAPTCHA'];
        if trim(wint) = '' then
          fMaxTentativasErroCaptcha := 9999
        else
          fMaxTentativasErroCaptcha := StrToInt(wint);

        //wint := FMeminiFile.ReadString('ENVIRONMENT','MAXTENTATIVAERRO','9999');
        wint := FIniFileEnvironment.values['MAXTENTATIVAERRO'];
        if trim(wint) = '' then
          fMaxTentativasErro := 9999
        else
          fMaxTentativasErro := StrToInt(wint);

        if fMaxTentativasErroCaptcha > fMaxTentativasErro then fMaxTentativasErroCaptcha := fMaxTentativasErro - 1 ;
	//wint := FMeminiFile.ReadString('ENVIRONMENT','USERMAXREPPASS','0');
        wint := FIniFileEnvironment.values['USERMAXREPPASS'];
        if trim(wint) = '' then
          fMaxRepPass := 0
        else
          fMaxRepPass := StrToInt(wint);

	//wint := FMeminiFile.ReadString('ENVIRONMENT','USERMAXSEQPASS','0');
        wint := FIniFileEnvironment.values['USERMAXSEQPASS'];
        if trim(wint) = '' then
          fMaxSeqPass := 0
        else
          fMaxSeqPass := StrToInt(wint);

        //wint := FMeminiFile.ReadString('ENVIRONMENT','ACESSOSSIMULTANEOS','0');
        wint := FIniFileEnvironment.values['ACESSOSSIMULTANEOS'];
        if trim(wint) = '' then
          fACESSOSSIMULTANEOS := 0
        else
          fACESSOSSIMULTANEOS := StrToInt(wint);

        //fVerificaSectionKeyBD := uppercase(FMeminiFile.ReadString('ENVIRONMENT','VERIFICASENHABD','NAO')) = 'SIM' ;
        fVerificaSectionKeyBD := uppercase(FIniFileEnvironment.values['VERIFICASENHABD']) = 'SIM';
	//usenha1 := FMeminiFile.ReadString('USERS','USENHA1','');
	//usenha2 := FMeminiFile.ReadString('USERS','USENHA2','');
	//usenha3 := FMeminiFile.ReadString('USERS','USENHA3','');
	//usenha4 := FMeminiFile.ReadString('USERS','USENHA4','');
	//usenha5 := FMeminiFile.ReadString('USERS','USENHA5','');
	usenha1 := FIniFileUser.values['USENHA1'];
	usenha2 := FIniFileUser.values['USENHA2'];
	usenha3 := FIniFileUser.values['USENHA3'];
	usenha4 := FIniFileUser.values['USENHA4'];
	usenha5 := FIniFileUser.values['USENHA5'];
        if (usenha1 = '') or (usenha2 = '') or (usenha3 = '') or (usenha4 = '')or (usenha5 = '') then
          fFazRodizio := false
	else fFazRodizio := true;
        QRY.SQL.Clear;
        QRY.SQL.Add('select ' + USERFIELD + ',' + USERPASSWD);
        if userdtvalid <> '' then QRY.SQL.Add(','+USERDTVALID);
        if userlastpass <> '' then QRY.SQL.Add(','+USERLASTPASS);
        if userminpass <> '' then QRY.SQL.Add(','+USERMINPASS);
        if usermaxpass <> '' then QRY.SQL.Add(','+USERMAXPASS);
        if usermustchange <> '' then QRY.SQL.Add(','+USERMUSTCHANGE);
        if useractive <> '' then QRY.SQL.Add(','+USERACTIVE);
        if usernumtentativa  <> '' then QRY.SQL.Add(','+USERNUMTENTATIVA);
	if fFazRodizio then 
	begin
  	  if usenha1 <> '' then QRY.SQL.Add(','+USENHA1);
	  if usenha2 <> '' then QRY.SQL.Add(','+USENHA2);
	  if usenha3 <> '' then QRY.SQL.Add(','+USENHA3);
	  if usenha4 <> '' then QRY.SQL.Add(','+USENHA4);
	  if usenha5 <> '' then QRY.SQL.Add(','+USENHA5);
	end;
        QRY.SQL.Add(' from '+ USERTABLE  );
        if usuario <> '' then begin
          QRY.SQL.Add(' where '+USERFIELD+ ' = ' + QuotedStr(usuario) );
        end;
        BeginWrite;
        try
          QRY.Open;
          if usuario = '' then FPasswdList.Clear;
          while not QRY.Eof  do begin
            if (Usuario='') or (Usuario=QRY.FieldByName(USERFIELD).AsString) then
            begin
              USER_REG := TDBUser.Create(trim(QRY.FieldByName(USERFIELD).AsString));
              try
                USER_REG.Passwd.value := trim(QRY.FieldByName(USERPASSWD).AsString);
                if (userdtvalid <> '') and not (QRY.FieldByName(userdtvalid).IsNull) then
                  try
                    USER_REG.DtValSenha.value := QRY.FieldByName(userdtvalid).AsDateTime
                  except
                    USER_REG.DtValSenha.value := now+10000;
                  end
                else USER_REG.DtValSenha.value := now+10000;
                if (userlastpass <> '') and not (QRY.FieldByName(userlastpass).Isnull) then
                  try
                    USER_REG.UltAltSenha.value := QRY.FieldByName(userlastpass).AsDateTime
                  except
                    USER_REG.UltAltSenha.value := now;
                  end
                else USER_REG.UltAltSenha.value := now;
                if (userminpass <> '') and not (QRY.FieldByName(userminpass).IsNull) then
                  try
                    USER_REG.MinSenha := QRY.FieldByName(userminpass).AsInteger
                  except
                    USER_REG.MinSenha :=  0;
                  end
                else USER_REG.MinSenha :=  0;
                if (usermaxpass <> '') and not (QRY.FieldByName(usermaxpass).IsNull) then
                  try
                    USER_REG.MaxSenha := QRY.FieldByName(usermaxpass).AsInteger;
                    if USER_REG.MaxSenha = 0 then USER_REG.MaxSenha := 999999;
                  except
                    USER_REG.MaxSenha := 999999;
                  end
                else USER_REG.MaxSenha := 999999;
                if (usermustchange <> '') and not (QRY.FieldByName(usermustchange).IsNull) then
                  try
                    USER_REG.MustChange := uppercase(QRY.FieldByName(usermustchange).Asstring) = 'V';
                  except
                    USER_REG.MustChange := false;
                  end
                else USER_REG.MustChange := false;
                if (useractive <> '') and not (QRY.FieldByName(useractive).IsNull) then
                  try
                    if QRY.FieldByname(useractive).AsString = 'S' then
                      USER_REG.UserActive := true
                    else if QRY.FieldByname(useractive).AsString = 'N' then
                      USER_REG.UserActive := false
                    else
                      USER_REG.UserActive := strToBool(QRY.FieldByname(useractive).AsString);
                  except
                    USER_REG.UserActive := true;
                  end
                else USER_REG.UserActive := true;
                if (usernumtentativa <> '') and not (QRY.FieldByName(usernumtentativa).IsNull) then
                  try
                    USER_REG.UserTentativasE := QRY.FieldByName(usernumtentativa).AsInteger;
                  except
                    USER_REG.UserTentativasE := 0;
                  end
                else USER_REG.UserTentativasE :=  0;
                if fFazRodizio then
                begin
                  USER_REG.Senha1.Value := trim(QRY.FieldByName(USenha1).AsString);
                  USER_REG.Senha2.Value := trim(QRY.FieldByName(USenha2).AsString);
                  USER_REG.Senha3.Value := trim(QRY.FieldByName(USenha3).AsString);
                  USER_REG.Senha4.Value := trim(QRY.FieldByName(USenha4).AsString);
                  USER_REG.Senha5.Value := trim(QRY.FieldByName(USenha5).AsString);
  	      end;
                USER_REG.DriverName.value := userdriver;
                if trim(wtimeout) > '' then USER_REG.SectionTimeOut := StrToInt(wtimeout);
  {$IFDEF FPC}
                if usuario <> '' then result := USER_REG
                else
                try
  //              CritSec.Acquire;
  {$ENDIF}
                  FPasswdList.AddObject(trim(QRY.FieldByName(USERFIELD).AsString),USER_REG);
  {$IFDEF FPC}
                finally
                  try
  //                CritSec.Release; // nao consegui adquirir o semaphoro, deve estar com problema , entao libera
                  except
                  end;
                end;
  {$ENDIF}

              except
                freeandnil(User_reg);
  {$IFDEF FPC}
                if usuario = '' then result := nil;
  {$ENDIF}
              end;
            end;
            QRY.Next;
          end;
        finally
          EndWrite;
        end;
      except
        on e : exception do
        begin
{$IFDEF FPC}
          if usuario = '' then result := nil;
{$ENDIF}	    
          WriteLog('  ==== Erro na leitura do banco : '+e.message);
        end;
      end;
    finally
      if assigned(QRY) then QRY.free;
      if assigned(DBArq) then freeandnil(dbarq);
{$IFDEF FPC}	    
//      CritSec.Release;
{$ENDIF}
    end;
  end;
end;

procedure TLauncherEnv.LimpaCache(User:String);
var
  Index : Integer;
begin
    if FPasswdList.Find(User,Index) then { Já existe na lista }
      FPasswdList.Delete(Index);
    if FSectionList.Find(User,Index) then { Já existe na lista }
      FSectionList.Delete(Index);
end;

function TLauncherEnv.FMeminiFileReadString(st1,st2,def:AnsiString):AnsiString;
begin
  result := '';
  if st1 = 'ENVIRONMENT' then
    result := FIniFileEnvironment.values[st2]
  else if st1 = 'USERS' then
    result := FIniFileUser.values[st2]
  else if st1 = 'ELASTICSEARCH' then
    result := FIniFileElastic.values[st2];
  if trim(result) = '' then result := def;

end;

procedure TLauncherEnv.SetGlobalVars(User : TBaseUser);
var 
  wtimeout ,wdelay, wint : string;
begin
  if FTemIni then
  begin
        wdelay := FMeminiFileReadString('ENVIRONMENT','LOGIN_ERR_DELAY','3');
        if trim(wdelay) > '' then fLogin_Err_Delay := StrToInt(wdelay);
        wtimeout := FMeminiFileReadString('ENVIRONMENT','GLOBALTIMEOUT','0');
        if trim(wtimeout) > '' then USer.SectionTimeOut := StrToInt(wtimeout);
        wint := FMeminiFileReadString('ENVIRONMENT','USERMINCARACPASS','1');
        if trim(wint) > '' then fMinCaracPass := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','CARMINALFAPASS','1');
        if trim(wint) > '' then fMinAlfaPass := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','CARMINALFAMAISPASS','1');
        if trim(wint) > '' then fMinAlfaMaisPass := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','CARMINESPPASS','1');
        if trim(wint) > '' then fCarMinEspPass := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','CARMINNUMPASS','1');
        if trim(wint) > '' then fMinNumPass := StrToInt(wint);
        fCaracPass.value := uppercase(FMeminiFileReadString('ENVIRONMENT','USERCARACPASS','NAO')) ;
        wint := FMeminiFileReadString('ENVIRONMENT','USERDIASEXPIRA','0');
        if trim(wint) > '' then fDiasExpira := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','MAXTENTATIVAERROCAPTCHA','9999');
        if trim(wint) > '' then fMaxTentativasErroCaptcha := StrToInt(wint)
        else fMaxTentativasErroCaptcha := 9999;
        wint := FMeminiFileReadString('ENVIRONMENT','MAXTENTATIVAERRO','9999');
        if trim(wint) > '' then fMaxTentativasErro := StrToInt(wint)
        else fMaxTentativasErro := 9999;
        if fMaxTentativasErroCaptcha > fMaxTentativasErro then fMaxTentativasErroCaptcha := fMaxTentativasErro - 1 ;
        wint := FMeminiFileReadString('ENVIRONMENT','USERMAXREPPASS','0');
        if trim(wint) > '' then fMaxRepPass := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','USERMAXSEQPASS','0');
        if trim(wint) > '' then fMaxSeqPass := StrToInt(wint);
        wint := FMeminiFileReadString('ENVIRONMENT','ACESSOSSIMULTANEOS','0');
        if trim(wint) > '' then fACESSOSSIMULTANEOS := StrToInt(wint)
        else fACESSOSSIMULTANEOS := 0;
        fVerificaSectionKeyBD := uppercase(FMeminiFileReadString('ENVIRONMENT','VERIFICASENHABD','NAO')) = 'SIM' ;

  end;
end;

function TLauncherEnv.GetSection(User_section:String):TSection;
var
  Index : Integer;
  wSection : TSection;
begin
{$IFDEF FPC}
  result := nil;
{$ENDIF}
  BeginRead;
  try
CritSec.Acquire;
    if FSectionList.Find(User_section,Index) then { Já existe na lista }
      Result := FSectionList.Objects[Index] as TSection
    else begin
          WSection := TSection.Create;
	  WSection.ContErroLogin := 0;
          WSection.Captcha.Value := '';
          FSectionList.AddObject(User_section,WSection);
          result := wSection;
    end;
  finally
    EndRead;
CritSec.Release;
  end;
end;

function TLauncherEnv.GetUser(User:String):TBaseUser;
var
  Index : Integer;
  WSDBUser : TWSDbUser;
{$IFDEF FPC}
  WDBUser : TDbUser;
{$ENDIF}
begin
  result := nil;
  BeginRead;
  CritSec.Acquire;
  try
    if FPasswdList.Find(User,Index) then { Já existe na lista }
      Result := FPasswdList.Objects[Index] as TBaseUser
    else begin
      if SegurancaWS then
      begin
        BeginWrite;
	try
          WSDBUser := TWSDBUser.Create(user);
  	  WSDBUser.Passwd.value := '';
          SetGlobalVars(WSDBUser);
          FPasswdList.AddObject(User,WSDBUser);
 	finally
          EndWrite;
	end;
        result :=  WSDBUser;
      end
      else if trim(FDbStr.value) <> '' then
      begin
        BeginWrite;
        try
{$IFDEF FPC}
//          CritSec.Acquire;
//          wdbuser := LoadDBUsers(User);
//          if assigned(wdbuser) then 
//          begin
//            result := wdbuser;
//            FPasswdList.AddObject(User,WDBUser);
//          end
//          else WriteLog('  ==== Nao conseguiu ler : '+user);;
//{$ELSE}
          if FPasswdList.Count = 0 then 
	  begin
           writelog(' --- CARGA COMPLETA DOS USUARIOS');		   
           LoadDBUsers(''); // Carrega todos os usuarios no primeiro acesso para o Cache
           if FPasswdList.Find(User,Index) then
             Result := FPasswdList.Objects[Index] as TBaseUser;
          end
	  else begin
            writelog(' --- CARGA DO USUARIO '+user );		   
            wdbuser := LoadDBUsers(User);
            if assigned(wdbuser) then
            begin
              result := wdbuser;
              FPasswdList.AddObject(User,WDBUser);
            end;
          end;	    
{$ELSE}
	  LoadDBUsers(''); // Carrega todos os usuarios no primeiro acesso para o Cache
	  if FPasswdList.Find(User,Index) then
	    Result := FPasswdList.Objects[Index] as TBaseUser;
{$ENDIF}
 	finally
{$IFDEF FPC}
//          CritSec.Release;
{$ENDIF}
          EndWrite;
	end;
      end
      else
      begin
        BeginWrite;
        try
          try
            result := TLinuxUser.Create(User);
            FPasswdList.AddObject(trim(user),result);
          except
{$IFDEF LINIX}    WriteLog('Ambiente Incorreto ou Erro na leitura dos dados do usuario do linux ',errno); {$ENDIF}
          end;
        finally
          EndWrite;
        end;
      end;
    end;
  finally
    EndRead;
    CritSec.Release;
  end;
end;

procedure TLauncherEnv.LimpaSenhas;
begin
   BeginWrite;
   if assigned(FPasswdList) then
     FPasswdList.Clear;
   EndWrite;
end;


procedure TLauncherEnv.GravaSenhaBD(Usuario,Senha : string);
var
        QRY : TSQLQuery;
        userfield, userpasswd, usertable, userdtvalid, userlastpass, 
        userminpass, usermaxpass,usermustchange,useractive,userdriver,
        usenha1, usenha2, usenha3, usenha4, usenha5,
        dbhost,dbuser,dbpass : string;
        DBARQ : TSQlConnection;
begin
   DBArq := nil;
   QRY := nil;
   if FTemIni then
   begin
      dbuser := FMEminiFileReadString('USERS','DB_USER','');
      dbPass := FMeminiFileReadString('USERS','DB_PASS','');
      TrataSenhaEncriptografada(dbPass);
      dbHost := FMeminiFileReadString('USERS','DB_HOSTNAME','localhost');
      userdriver:= uppercase(FMeminiFileReadString('USERS','DRIVERNAME','INTERBASE'));
      if (trim(Fdbstr.value)<>'') and (trim(dbuser)<>'') and (trim(dbPass)<>'') then
      try
        critsec.acquire;
        DBARQ := DBINIT(FdbStr.value,userdriver,DBUSER,DBPASS,DBHOST);
        QRY := TSQLQuery.Create(nil);
        QRY.SqlConnection := DBARQ;
        try
          userfield := FMeminiFileReadString('USERS','USERFIELD','CO_USUARIO');
          userpasswd:= FMeminiFileReadString('USERS','USERPASSWORD','CO_SENHA');
          usertable := FMeminiFileReadString('USERS','USERTABLE','USUARIO');
          userdtvalid := FMeminiFileReadString('USERS','USERDTVALID','');
          userlastpass := FMeminiFileReadString('USERS','USERLASTPASS','');
          userminpass := FMeminiFileReadString('USERS','USERMINPASS','');
          usermaxpass := FMeminiFileReadString('USERS','USERMAXPASS','');
          usermustchange := FMeminiFileReadString('USERS','USERMUSTCHANGE','');
          useractive := FMeminiFileReadString('USERS','USERACTIVE','');
  	usenha1 := FMeminiFileReadString('USERS','USENHA1','');
 	usenha2 := FMeminiFileReadString('USERS','USENHA2','');
	usenha3 := FMeminiFileReadString('USERS','USENHA3','');
	usenha4 := FMeminiFileReadString('USERS','USENHA4','');
  	usenha5 := FMeminiFileReadString('USERS','USENHA5','');
          QRY.SQL.Clear;
          QRY.SQL.Add('update ' + USERTABLE+ ' set ');
          if fFazRodizio then 
	  begin
	      Qry.Sql.Add(    usenha1 + '=' + usenha2 + ','  + 
	                  usenha2 + '=' + usenha3 + ','  + 
	                  usenha3 + '=' + usenha4 + ','  + 
	                  usenha4 + '=' + usenha5 + ','  + 
	                  usenha5 + '=' + USERPASSWD + ','  );
          end;
          Qry.Sql.ADD( USERPASSWD+' =:senha, '+USERLASTPASS+' =:data ,'+ USERMUSTCHANGE );
   	QRY.SQL.Add(' = :change  where '+USERFIELD+ ' = :usuario');
          QRY.ParamByName('usuario').AsString := usuario;
          QRY.ParamByName('senha').Asstring := Senha;
          QRY.ParamByName('Data').asSqlTimeStamp := DateTimeToSqlTimeStamp(now);
          QRY.ParamByName('change').AsString := 'f';
          QRY.ExecSql;
        except
        raise ECCP_Proto.Create('Erro na gravaçao da senha do usuario');
        end;
      finally
        if assigned(QRY) then QRY.free;
        if assigned(DBARQ) then DBARQ.Free;
        critsec.release;
      end;
    end;
end;

procedure TLauncherEnv.GravaSenhaErrada(usuario : string; erros : integer);
var
        QRY : TSQLQuery;
        userfield,  usertable, userdriver,
        dbhost,dbuser,dbpass,dbnumtent : string;
        DBARQ : TSQlConnection;
{$IFDEF FPC}
        PID : longint;
        status : PInteger;
{$ENDIF}
begin
    if FTemIni then
    begin
      dbuser := FMEminiFileReadString('USERS','DB_USER','');
      dbPass := FMeminiFileReadString('USERS','DB_PASS','');
      TrataSenhaEncriptografada(dbPass);
      dbHost := FMeminiFileReadString('USERS','DB_HOSTNAME','localhost');
      dbnumtent := FMEminiFileReadString('USERS','USERNUMTENTATIVA','');
      userdriver:= uppercase(FMeminiFileReadString('USERS','DRIVERNAME','INTERBASE'));
      if (trim(Fdbstr.value)<>'') and (trim(dbuser)<>'') and (trim(dbPass)<>'') and (trim(dbnumtent)<>'')
      then
      try
        critsec.acquire;
        try
          DBARQ := DBINIT(FdbStr.value,userdriver,DBUSER,DBPASS,DBHOST);
          QRY := TSQLQuery.Create(nil);
          QRY.SqlConnection := DBARQ;
          userfield := FMeminiFileReadString('USERS','USERFIELD','CO_USUARIO');
          usertable := FMeminiFileReadString('USERS','USERTABLE','USUARIO');
          QRY.SQL.Clear;
          QRY.SQL.Add('update ' + USERTABLE+ ' set ');
          Qry.Sql.ADD( dbnumtent+' = :tentativas ' );
          QRY.SQL.Add('where '+USERFIELD+ ' = :usuario');
          QRY.ParamByName('usuario').AsString := usuario;
          QRY.ParamByName('tentativas').Asinteger := erros ;
          QRY.ExecSql;
        finally
          QRY.free;
          DBARQ.Free;
          critsec.release;
        end;
      except
          raise ECCP_Proto.Create('Erro na gravacao do numero de vezes com senha errada ');
      end;
    end;
end;

procedure TLauncherEnv.GravaExpiracao(usuario : string);
var	
        QRY : TSQLQuery;
        userfield,  usertable, userdtvalid, userdriver,
        dbhost,dbuser,dbpass : string;
        DBARQ : TSQlConnection;
begin
   if FTemIni then
   begin
      dbuser := FMEminiFileReadString('USERS','DB_USER','');
      dbPass := FMeminiFileReadString('USERS','DB_PASS','');
      TrataSenhaEncriptografada(dbPass);
      dbHost := FMeminiFileReadString('USERS','DB_HOSTNAME','localhost');
      userdriver:= uppercase(FMeminiFileReadString('USERS','DRIVERNAME','INTERBASE'));
      if (trim(Fdbstr.value)<>'') and (trim(dbuser)<>'') and (trim(dbPass)<>'') then
      try
        critsec.acquire;
        try
          DBARQ := DBINIT(FdbStr.value,userdriver,DBUSER,DBPASS,DBHOST);
          QRY := TSQLQuery.Create(nil);
          QRY.SqlConnection := DBARQ;
          userfield := FMeminiFileReadString('USERS','USERFIELD','CO_USUARIO');
          usertable := FMeminiFileReadString('USERS','USERTABLE','USUARIO');
          userdtvalid := FMeminiFileReadString('USERS','USERDTVALID','');
          QRY.SQL.Clear;
          QRY.SQL.Add('update ' + USERTABLE+ ' set ');
          Qry.Sql.ADD( userdtvalid+' = :data ' );
 	  QRY.SQL.Add('where '+USERFIELD+ ' = :usuario');
          QRY.ParamByName('usuario').AsString := usuario;
          QRY.ParamByName('Data').asSqlTimeStamp := DateTimeToSqlTimeStamp(now-1);
          QRY.ExecSql;
        finally
          QRY.free;
          DBARQ.Free;
          critsec.release;
        end;
      except
        raise ECCP_Proto.Create('Erro na gravacao de usuario expirado ');
      end;
    end;
end;

procedure TLauncherEnv.BeginWrite;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.BeginWrite;
{$ENDIF}
end;

procedure TLauncherEnv.EndWrite;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.EndWrite;
{$ENDIF}
end;

procedure TLauncherEnv.BeginRead;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.BeginRead;
{$ENDIF}
end;

procedure TLauncherEnv.EndRead;
begin
{$IFNDEF FPC}
  FMultiReadExclusiveWriteSynchronizer.EndRead;
{$ENDIF}
end;

function TLauncherEnv.GetItem (i : integer): string;
begin
  result := FPasswdList[i];
end;

function TLauncherEnv.Count : integer;
begin
  result := FPasswdList.Count;
end;

function TLauncherEnv.VerificaSessionKeyExpirada(usuario, senha : string):boolean;
var
        QRY : TSQLQuery;
        userfield,  usertable, userdtvalid, userdriver,
        dbhost,dbuser,dbpass : string;
        DBARQ : TSQlConnection;
begin
   result := false;
   if FTemIni then
   begin
      dbuser := FMEminiFileReadString('USERS','DB_USER','');
      dbPass := FMeminiFileReadString('USERS','DB_PASS','');
      TrataSenhaEncriptografada(dbPass);
      dbHost := FMeminiFileReadString('USERS','DB_HOSTNAME','localhost');
      userdriver:= uppercase(FMeminiFileReadString('USERS','DRIVERNAME','INTERBASE'));
      if (trim(Fdbstr.value)<>'') and (trim(dbuser)<>'') and (trim(dbPass)<>'') then
      try
        critsec.acquire;
        try
          DBARQ := DBINIT(FdbStr.value,userdriver,DBUSER,DBPASS,DBHOST);
          QRY := TSQLQuery.Create(nil);
          QRY.SqlConnection := DBARQ;
          QRY.SQL.Clear;
          Qry.sql.add('SELECT SESSION_KEY FROM SCCI_SESSION');
          Qry.sql.add('WHERE NO_USUARIO=:usuario AND SESSION_KEY=:sKey');
          Qry.paramByName('usuario').asString := usuario;
          Qry.paramByName('sKey').asString := senha;
          Qry.open;
          result := not Qry.eof;
          writelog('Verifica sessionKey expirada');
          Qry.close;
        finally
          QRY.free;
          DBARQ.Free;
          critsec.release;
        end;
      except
        raise ECCP_Proto.Create('Erro na gravacao de usuario expirado ');
      end;
    end;
end;

//-------------------Rotinas Genericas ------------------

procedure MsgErro(AThread : TidPeerThread; ErroMsg : string);
var Tamlidos : longint;
    hdr : char;
    len : longint;
{$IFDEF FPC}
    Buf : TIdBytes;
{$ENDIF}
begin
  with AThread.Connection{$IFDEF FPC}.IOHandler{$ENDIF} do
  begin
{$IFDEF FPC}
    ReadTimeout := 60000;
{$ENDIF}
    readString(1); // Lê o Método HDR e joga fora
{$IFDEF FPC}
    TamLidos := readLongInt(true); // Lê o tamanho dos dados
{$ELSE}
    TamLidos := readInteger; // Lê o tamanho dos dados
{$ENDIF}
    ReadString(TamLidos); // Lê os dados
    readString(1); // Lê o Dados HDR e joga fora
{$IFDEF FPC}
    TamLidos := readLongInt(true); // Lê o tamanho dos dados
{$ELSE}
    TamLidos := readInteger; // Lê o tamanho dos dados
{$ENDIF}
    ReadString(TamLidos); // Lê os dados
    hdr := EXCEPT_HDR;
    len := htonl(length(ErroMsg));
{$IFDEF FPC}
    Buf := Default(TIdBytes);
    SetLength(Buf,1);
    Buf := RawToBytes(hdr, 1);
    Write(Buf);
    SetLength(Buf,4);
    Buf := RawToBytes(len, 4);
    Write(Buf);
{$ELSE}
    writebuffer(hdr,1,false); // Envia mesnagem de erro
    writebuffer(len,4,false);
{$ENDIF}
    write(ErroMsg);
  end;
end;

{$IFDEF LINUX}  

procedure writetlv(handle : integer;st : ansistring);
var wlen, len : longint;
    buf : array [1..8192] of char;
begin
  buf[1] := #0;
  len := length(st);
  if len > 8192 then len := 8192;
  wlen := len;
  move(wlen,buf[1],4 );
  move(st[1],buf[5],len );
  __write(handle,buf,len+4);
{$IFDEF FPC}
  fpfsync(Handle);
{$ELSE}
  fsync(Handle);
{$ENDIF}
end;

function readtlv(handle : integer;var st : ansistring): integer;
var
  bsize : longint;
begin
  bsize := 0;
  result := -1;
  if __read(Handle,bsize,4) = 4 then
  begin
    setlength(st,bsize);
    result := __read(Handle,st[1],bSize);
  end;
end;
{$ENDIF}

{$IFDEF FPC}


function TLauncherEnv.RevalidaWSLogin(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring; var ult_login : tdatetime; QtMaxLogin : integer = 0): char;
var
  token , wprog, 
  whome: ansistring;
  wpipe : Integer;
  pfd_read,pfd_write : TFilDes;
  Programa : TMyProc;
  Index : integer;
  wamb : TPtrStr;
  Parametros : PPchar;
  ArrPchar : array [0..8] of PChar;
  w1,w2 ,wseg,localwip : ansistring;
  pid,erro: integer;
  status : PInteger;
begin
  pfd_write := default(TFilDes);
  pfd_read := default(TFilDes);
  result := 'T';
{$IFDEF FPC}
  wamb := Default(TPtrStr);
{$ELSE}
  fillchar(wamb,sizeof(wamb),0);
{$ENDIF}
  Env.Insert(0,'USER='+ Usuario);
  FSeg_Sistema.value := trim(FSeg_Sistema.value);
  if trim(FSeg_Sistema.value) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if not DirectoryExists(whome) then whome := '/tmp';
    wprog := ExecPath(Env.Values['PATH'],FSeg_Sistema.value);
    if (wprog <> '') and TemPerm(wprog) then
    begin
      try
        wpipe := fppipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := fppipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        SetAmbiente(Env,wamb);
        Parametros := @ArrPChar;
        wseg := FSeg_Sistema.value;
        Parametros[0] :=  PChar(wseg);
        w1 := inttostr(pfd_write[0]);
        Parametros[1] :=  PChar(w1);
        w2 := inttostr(pfd_read[1]);
        Parametros[2] :=  PChar(w2);
        localwip :=  PChar(AThread.Connection.socket.Binding.PeerIP);
        Parametros[3] :=  pchar(localwip);
        Parametros[4] :=  nil;
        pid :=  fpfork();
        case pid of
          0 : begin // filho
               fpclose(listenerfd);
               fpclose(pfd_read[0]);
               fpclose(pfd_write[1]);
               fpchdir(pchar(whome));
               if (UserId + GroupID) > 1 then
               begin
                 fpsetregid(GroupID,GroupID);
                 fpsetreuid(UserId,UserId);
               end;
               erro := fpexecve(pchar(wprog),Parametros,@wamb);
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               if erro = -1 then
               begin
                 WriteLog('Não foi possivel executar o programa ');
                 sleep(100);
                 halt(1);
               end
               else begin
                 writelog('Condição anormal ao executar ');
                 sleep(100); // para o waitpid pegar o filho morrendo
                 halt(1);
               end;
             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico.value);
               writetlv(pfd_write[1],FSeg_Identificacao.value);
               writetlv(pfd_write[1],'VALIDA');
               writetlv(pfd_write[1],Usuario);
               writetlv(pfd_write[1],Senha);//Tem o token para revalidar em BD.
               if QtMaxLogin > 0 then
                 writetlv(pfd_write[1],inttostr(QtMaxLogin)) 
               else
                 writetlv(pfd_write[1],''); // Maximo de Logins simultâneos
               if readtlv(pfd_read[0],token) <= 0 then
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               if token <> '' then result :=  token[1]
               else result := 'F';
               fpwaitpid(pid,status,0);
               fpclose(pfd_write[1]);
               fpclose(pfd_read[0]);
             end;
        end;
      finally

      end;
    end
    else writelog('loginexterno :Sem permissao para executar : '+wprog);
{--------- Trocado por execve ------

    Programa := TMyProc.Create(nil);
    StdErrolist  := tstringlist.create;
    try
        wpipe := pipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := pipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        Programa.userid := UserId;
        programa.groupid := GroupId;
        Programa.fd0 := pfd_read[0];
        Programa.fd1 := pfd_write[1];
        with Programa do
        begin
          Expande(Env);
          Options := [poUsePipes];
          whome := Env.Values['HOME'];
          if DirectoryExists(whome) then CurrentDirectory := whome
          else CurrentDirectory := '/tmp';
          OnForkEvent := @AfterForkPipes;
          Environment := Env;
          Executable := ExecPath(Env.Values['PATH'],FSeg_Sistema);
          if Executable <> '' then
          begin
            Parameters.Add(inttostr(pfd_write[0]));
            Parameters.Add(inttostr(pfd_read[1]));
            Parameters.Add(PChar(AThread.Connection.socket.Binding.PeerIP));
            try
              Execute;
              __close(pfd_read[1]);
              __close(pfd_write[0]);
              Token := '';
              writetlv(pfd_write[1],FSeg_Servico);
              writetlv(pfd_write[1],FSeg_Identificacao);
              writetlv(pfd_write[1],'VALIDA');
              writetlv(pfd_write[1],Usuario);
              writetlv(pfd_write[1],Senha);//Tem o token para revalidar em BD.
              writetlv(pfd_write[1],''); // Maximo de Logins simultâneos
              if readtlv(pfd_read[0],token) <= 0 then
                MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
              if token <> '' then result :=  token[1]
              else result := 'F';
              WaitOnExit;
              __close(pfd_write[1]);
              __close(pfd_read[0]);
            except
              raise Exception.Create('Erro ao executar '+ Executable + ' com cógigo de erro: ' + IntToStr(ExitStatus));
            end;
          end
          else begin
            raise exception.Create('Executavel não encontrado : '+FSeg_Sistema);
          end;
        end;
        if assigned(Programa.StdErr) and (programa.StdErr.NumBytesAvailable > 0) then
        begin
          StdErrolist.loadfromstream(programa.StdErr);
          StdErroList.SaveToFile('/var/log/launcher_err.log');
        end;
    finally
      freeandnil(programa);
      freeandnil(StdErroList);
    end;
---- Fim troca por execve }
  end
  else  MsgErro(AThread,'Erro ao gravar log - faltam parametros');

  if ( result = 'T' ) and (length(token) > 2) then
    try
      ult_login := strtofloat(copy(token,2,length(token)));
    except
      ult_login := now;
      // para evitar que venha token incompativel e aborte.
    end;
end;


function TLauncherEnv.LeSegurancaWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring; QTDMAXLOGIN : integer; wIP : string): char;
//wtoken tem a chave de seção para o caso da troca de senha onde a senha vem limpa
var
  token , wprog,
  whome: ansistring;
  wpipe : Integer;
  pfd_read,pfd_write : TFilDes;
  Programa : TMyProc;
  wamb : TPtrStr;
  ArrPchar : array [0..8] of PChar;
  Parametros : PPchar;
  w1,w2 : ansistring;
  pid,erro: integer;
  status : PInteger;
  localwip : ansistring;
  wseg : ansistring;
begin
  result := 'F';
  Token := '';
  pfd_read := default(TFilDes);
  pfd_write := default(TFilDes); 
{$IFDEF FPC}
  wamb := Default(TPtrStr);
{$ELSE}
  fillchar(wamb,sizeof(wamb),0);
{$ENDIF}
  Env.Insert(0,'USER='+ Usuario);
  FSeg_Sistema.value := trim(FSeg_Sistema.value);
  if trim(FSeg_Sistema.value) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if not DirectoryExists(whome) then whome := '/tmp';
    wprog := ExecPath(Env.Values['PATH'],FSeg_Sistema.value);
    if (wprog <> '') and TemPerm(wprog) then
    begin
      try
        wpipe := fppipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := fppipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        SetAmbiente(Env,wamb);
        Parametros := @ArrPchar;
        wseg := FSeg_Sistema.value;
        Parametros[0] :=  PChar(wseg);
        w1 := inttostr(pfd_write[0]);
        Parametros[1] :=  PChar(w1);
        w2 := inttostr(pfd_read[1]);
        Parametros[2] :=  PChar(w2);
        if wIP <> '' then localwip := wip
        else localwip :=  AThread.Connection.socket.Binding.PeerIP;
        Parametros[3] :=  pChar(localwip);
        Parametros[4] :=  nil;
        pid :=   fpfork();
        case pid of
          0 : begin // filho
               fpclose(listenerfd);
               fpclose(pfd_read[0]);
               fpclose(pfd_write[1]);
               fpchdir(pchar(whome));
               if (UserId <> 0) and (GroupID <> 0) then
               begin
                   fpsetregid(GroupID,GroupID);
                   fpsetreuid(UserId,UserId);
               end;
               erro := fpexecve(pchar(wprog),Parametros,@wamb);
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               if erro = -1 then
               begin
                 WriteLog('Não foi possivel executar o programa ');
                 sleep(100); // para o waitpid pegar o filho morrendo
                 halt(1);
               end
               else begin
                 writelog('Condição anormal ao executar ');
                 sleep(100); // para o waitpid pegar o filho morrendo
                 halt(1);
               end;

             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico.value);
               writetlv(pfd_write[1],FSeg_Identificacao.value);
               writetlv(pfd_write[1],'LOGIN');
               writetlv(pfd_write[1],Usuario);
               writetlv(pfd_write[1],Senha);
               writetlv(pfd_write[1],inttostr(QTDMAXLOGIN)); //NovaSenha no login vira qtd maxima de logins simultaneos. 0 nao permite logins simultaneos.
               if readtlv(pfd_read[0],token) <= 0 then
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               if token <> '' then result :=  token[1]
               else result := 'F';
               fpwaitpid(pid,status,0);
               fpclose(pfd_write[1]);
               fpclose(pfd_read[0]);
             end;
        end;
      finally

      end;
    end
    else writelog('loginexterno :Sem permissao para executar : '+wprog);
{--------- Trocado por execve ------
    Programa := TMyProc.Create(nil);
    StdErrolist  := tstringlist.create;
    try
        wpipe := pipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := pipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        Programa.userid := UserId;
        programa.groupid := GroupId;
        Programa.fd0 := pfd_read[0];
        Programa.fd1 := pfd_write[1];
        with Programa do
        begin
          Expande(Env);
          Options := [poUsePipes];
          whome := Env.Values['HOME'];
          if DirectoryExists(whome) then CurrentDirectory := whome
          else CurrentDirectory := '/tmp';
          OnForkEvent := @AfterForkPipes;
          Environment := Env;
          Executable := ExecPath(Env.Values['PATH'],FSeg_Sistema);
          if Executable <> '' then 
          begin
            Parameters.Add(inttostr(pfd_write[0]));
            Parameters.Add(inttostr(pfd_read[1]));
            if wIP <> '' then 
                 Parameters.Add(wIP)
            else Parameters.Add(PChar(AThread.Connection.socket.Binding.PeerIP));
         
            try
              Execute;
              __close(pfd_read[1]);
              __close(pfd_write[0]);
              Token := '';
              writetlv(pfd_write[1],FSeg_Servico);
              writetlv(pfd_write[1],FSeg_Identificacao);
              writetlv(pfd_write[1],'LOGIN');
              writetlv(pfd_write[1],Usuario);
              writetlv(pfd_write[1],Senha);
              writetlv(pfd_write[1],inttostr(QTDMAXLOGIN)); //NovaSenha no login vira qtd maxima de logins simultaneos. 0 nao permite logins simultaneos.
              if readtlv(pfd_read[0],token) <= 0 then
                MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
              result :=  token[1];
              WaitOnExit;
              __close(pfd_write[1]);
              __close(pfd_read[0]);
            except
              raise Exception.Create('Erro ao executar '+ Executable + ' com cógigo de erro: ' + IntToStr(ExitStatus));
            end;
          end
          else begin
            raise exception.Create('Executavel não encontrado : '+FSeg_Sistema);
          end;
        end;
        if assigned(Programa.StdErr) and (programa.StdErr.NumBytesAvailable > 0) then
        begin
          StdErrolist.loadfromstream(programa.StdErr);
          StdErroList.SaveToFile('/var/log/launcher_err.log');
        end;
    finally
      freeandnil(programa);
      freeandnil(StdErroList);
    end;
------------fim troca execve ----- }
  end
  else  MsgErro(AThread,'Erro ao gravar log - faltam parametros');
  if length(token) > 2 then Senha := copy(token,2,length(token))
  else Senha := ''; // a senha vai ter ou o bloco de dados ou a mensagem de erro.
                    // em caso de erro, seu conteúdo será apresentado ao usuário na tela, 
                    // então não posso deixar que a senha volte com o que foi digitado pelo 
                    // usuário.
end;


function TLauncherEnv.TrocaSenhaWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring;
                                    NovaSenha : string;wtoken : string; Var pErro : string): char;
//wtoken tem a chave de seção para o caso da troca de senha onde a senha vem limpa
var
  token ,wprog,
  whome: ansistring;
  wpipe : Integer;
  pfd_read,pfd_write   : TFilDes;
  Programa : TMyProc;
  pid,erro: integer;
  status : PInteger;
  wamb : TPtrStr;
  ArrPchar : array [0..8] of PChar;
  Parametros : PPchar;
  wseg,w1,w2,localwip : ansistring;
begin
  pErro := '';
  Token := '';

  pfd_read := default(TFilDes);
  pfd_write := default(TFilDes);

  result := 'F';
{$IFDEF FPC}
  wamb := Default(TPtrStr);
{$ELSE}
  fillchar(wamb,sizeof(wamb),0);
{$ENDIF}
  Env.Insert(0,'USER='+ Usuario);
  FSeg_Sistema.value := trim(FSeg_Sistema.value);
  if trim(FSeg_Sistema.value) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if not DirectoryExists(whome) then whome := '/tmp';
    wprog := ExecPath(Env.Values['PATH'],FSeg_Sistema.value);
    if (wprog <> '') and TemPerm(wprog) then
    begin
      try
        wpipe := fppipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := fppipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        SetAmbiente(Env,wamb);
        Parametros := @ArrPchar;
        wseg := fSeg_Sistema.value;
        Parametros[0] :=  PChar(wseg);
        w1 := inttostr(pfd_write[0]);
        Parametros[1] :=  PChar(w1);
        w2 := inttostr(pfd_read[1]);
        Parametros[2] :=  PChar(w2);
        localwip := PChar(AThread.Connection.socket.Binding.PeerIP);
        Parametros[3] :=  PChar(localwip);
        Parametros[4] :=  nil;
        pid :=   fpfork();
        case pid of
          0 : begin // filho
               fpclose(listenerfd);
               fpclose(pfd_read[0]);
               fpclose(pfd_write[1]);
               fpchdir(PChar(whome));
               if (UserId <> 0) and (GroupID <> 0) then
               begin
                   fpsetregid(GroupID,GroupID);
                   fpsetreuid(UserId,UserId);
               end;
               erro := fpexecve(pchar(wprog),Parametros,@wamb);
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               if erro = -1 then
               begin
                 WriteLog('Não foi possivel executar o programa ');
                 sleep(100); // para o waitpid pegar o filho morrendo
                 halt(1);
               end
               else begin
                 writelog('Condição anormal ao executar ');
                 sleep(100); // para o waitpid pegar o filho morrendo
                 halt(1);
               end;
             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico.value);
               writetlv(pfd_write[1],FSeg_Identificacao.value);
               writetlv(pfd_write[1],'PASSWD');
               writetlv(pfd_write[1],wtoken);
               writetlv(pfd_write[1],Senha);
               writetlv(pfd_write[1],NovaSenha);
               if readtlv(pfd_read[0],token) <= 0 then
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               if token <> '' then result :=  token[1]
               else result := 'F';
               fpwaitpid(pid,status,0);
               fpclose(pfd_write[1]);
               fpclose(pfd_read[0]);
             end;
        end;
      finally

      end;
    end
    else writelog('loginexterno :Sem permissao para executar : '+wprog);


{--------- Trocado por execve ------

    Programa := TMyProc.Create(nil);
    StdErrolist  := tstringlist.create;
    try
        wpipe := pipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := pipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        Programa.userid := UserId;
        programa.groupid := GroupId;
        Programa.fd0 := pfd_read[0];
        Programa.fd1 := pfd_write[1];
        with Programa do
        begin
          Expande(Env);
          Options := [poUsePipes];
          whome := Env.Values['HOME'];
          if DirectoryExists(whome) then CurrentDirectory := whome
          else CurrentDirectory := '/tmp';
          OnForkEvent := @AfterForkPipes;
          Environment := Env;
          Executable := ExecPath(Env.Values['PATH'],FSeg_Sistema);
          if Executable <> '' then
          begin
            Parameters.Add(inttostr(pfd_write[0]));
            Parameters.Add(inttostr(pfd_read[1]));
            Parameters.Add(PChar(AThread.Connection.socket.Binding.PeerIP));
            try
              Execute;
              __close(pfd_read[1]);
              __close(pfd_write[0]);
              Token := '';
              writetlv(pfd_write[1],FSeg_Servico);
              writetlv(pfd_write[1],FSeg_Identificacao);
              writetlv(pfd_write[1],'PASSWD');
              writetlv(pfd_write[1],wtoken);
              writetlv(pfd_write[1],Senha);
              writetlv(pfd_write[1],NovaSenha);
              if readtlv(pfd_read[0],token) <= 0 then
                MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
              result :=  token[1];
              WaitOnExit;
              __close(pfd_write[1]);
              __close(pfd_read[0]);
            except
              raise Exception.Create('Erro ao executar '+ Executable + ' com cógigo de erro: ' + IntToStr(ExitStatus));
            end;
          end
          else raise exception.create('Nao encontrado o executavel : '+FSeg_sistema);       
        end;
        if assigned(Programa.StdErr) and (programa.StdErr.NumBytesAvailable > 0) then
        begin
          StdErrolist.loadfromstream(programa.StdErr);
          StdErroList.SaveToFile('/var/log/launcher_err.log');
        end;
    finally
      freeandnil(programa);
      freeandnil(StdErroList);
    end;
------------fim troca execve ----- }
  end
  else  MsgErro(AThread,'Erro ao gravar log - faltam parametros');

  if ( result = 'F' ) and (length(token) > 2) then
    pErro := copy(token,2,length(token));

  Senha := wtoken;
end;

function TLauncherEnv.EmailPasswordWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring; CPF: string;Var pErro : string): char;
var
  token , wprog, 
  whome: ansistring;
  wpipe : Integer;
  pfd_read,pfd_write : TFilDes;
  Programa : TMyProc;
  Index : integer;
  wamb : TPtrStr;
  Parametros : PPchar;
  ArrPchar : array [0..8] of PChar;
  w1,w2 ,wseg,localwip : ansistring;
  pid,erro: integer;
  status : PInteger;
begin
  Token := '';
  pErro := '';
  pfd_write := default(TFilDes);
  pfd_read := default(TFilDes);
  result := 'T';
{$IFDEF FPC}
  wamb := Default(TPtrStr);
{$ELSE}
  fillchar(wamb,sizeof(wamb),0);
{$ENDIF}
  Env.Insert(0,'USER='+ Usuario);
  FSeg_Sistema.value := trim(FSeg_Sistema.value);
  if trim(FSeg_Sistema.value) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if not DirectoryExists(whome) then whome := '/tmp';
    wprog := ExecPath(Env.Values['PATH'],FSeg_Sistema.value);
    if (wprog <> '') and TemPerm(wprog) then
    begin
      try
        wpipe := fppipe(pfd_write);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
        wpipe := fppipe(pfd_read);
        if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
        SetAmbiente(Env,wamb);
        Parametros := @ArrPChar;
        wseg := FSeg_Sistema.value;
        Parametros[0] :=  PChar(wseg);
        w1 := inttostr(pfd_write[0]);
        Parametros[1] :=  PChar(w1);
        w2 := inttostr(pfd_read[1]);
        Parametros[2] :=  PChar(w2);
        localwip :=  PChar(AThread.Connection.socket.Binding.PeerIP);
        Parametros[3] :=  pchar(localwip);
        Parametros[4] :=  nil;
        pid :=  fpfork();
        case pid of
          0 : begin // filho
               fpclose(listenerfd);
               fpclose(pfd_read[0]);
               fpclose(pfd_write[1]);
               fpchdir(pchar(whome));
               if (UserId + GroupID) > 1 then
               begin
                 fpsetregid(GroupID,GroupID);
                 fpsetreuid(UserId,UserId);
               end;
               erro := fpexecve(pchar(wprog),Parametros,@wamb);
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               if erro = -1 then
               begin
                 WriteLog('Não foi possivel executar o programa ');
                 sleep(100);
                 halt(1);
               end
               else begin
                 writelog('Condição anormal ao executar ');
                 sleep(100); // para o waitpid pegar o filho morrendo
                 halt(1);
               end;
             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               fpclose(pfd_read[1]);
               fpclose(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico.value);
               writetlv(pfd_write[1],FSeg_Identificacao.value);
               writetlv(pfd_write[1],'EMAILPWD');
               writetlv(pfd_write[1],Usuario);
               writetlv(pfd_write[1],Senha);//Chave Fixa 
               writetlv(pfd_write[1],CPF); //CPF
               if readtlv(pfd_read[0],token) <= 0 then
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               if token <> '' then result :=  token[1]
               else result := 'F';
               fpwaitpid(pid,status,0);
               fpclose(pfd_write[1]);
               fpclose(pfd_read[0]);
             end;
        end;
      finally

      end;
    end
    else writelog('loginexterno :Sem permissao para executar : '+wprog);
  end
  else  MsgErro(AThread,'Configuração da [SEGURANCA] invalida - faltam parametros');
  if ( result = 'F' ) and (length(token) > 2) then
    pErro := copy(token,2,length(token));
end;




{$ELSE}
// ====================== DCC =============================

function TLauncherEnv.RevalidaWSLogin(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring; var ult_login : tdatetime): char;

var
  token : ansistring;
  whome : string;
{$IFDEF LINUX}
  error : integer;
  pid : integer;
  status : PInteger;
  wamb : TPtrStr;
  wpipe : Integer;
  pfd_read,pfd_write   : array[0..1] of Integer;
{$IFDEF FPC}
  w1,w2 : ansistring;
  Parametros : PPchar;
{$ENDIF}
{$ELSE}
  StartUpInfo        : TStartUpInfo;
  ProcessInformation : TProcessInformation;
  BufSize: Integer;         // env block size
  Buffer: Pointer;          // env block
{$ENDIF}
begin
  Token := '';
  result := 'F';
  ult_login := now;
  Env.Insert(0,'USER='+ Usuario);
{$IFDEF MSWINDOWS}
  fillchar(StartUpInfo,sizeof(StartUpInfo),0);
  StartUpInfo.cb := SizeOf(TStartupInfo);
  fillchar(ProcessInformation,sizeof(ProcessInformation),0);
{$ENDIF}
  if trim(FSeg_Sistema) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if whome <> '' then
    try
      chdir(whome);
    except
      chdir('/tmp');
    end;
{$IFDEF LINUX}
    wpipe := pipe(@pfd_write);
    if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
    wpipe := pipe(@pfd_read);
    if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
{$IFDEF FPC}
    GetMem(Parametros,8*sizeof(PChar));
{$ENDIF}
    pid :=  fork();
    case pid of
         0 : begin // filho
               __close(pfd_read[0]);
               __close(pfd_write[1]);
               if (UserId <> 0) and (GroupID <> 0) then
               begin
                  setregid(GroupID,GroupID);
                  setreuid(UserId,UserId);
               end;
               SetAmbiente(Env,wamb);
{$IFDEF FPC}
               Parametros[0] :=  PChar(FSeg_Sistema);
               w1 := inttostr(pfd_write[0]);
               Parametros[1] :=  PChar(w1);
               w2 := inttostr(pfd_read[1]);
               Parametros[2] :=  PChar(w2);

               Parametros[3] :=  PChar(AThread.Connection.socket.Binding.PeerIP);
               Parametros[4] :=  nil;

               error := fpexecve(ExecPath(Env.Values['PATH'],FSeg_Sistema),Parametros,@wamb);
{$ELSE}
               error := execle(pchar(ExecPath(Env.Values['PATH'],FSeg_Sistema)),pchar(FSeg_Sistema),
                               pchar(inttostr(pfd_write[0])),PChar(inttostr(pfd_read[1])),
                               pchar(AThread.Connection.socket.Binding.PeerIP),nil,wamb);
{$ENDIF}
               if error <> 0 then
                  WriteLog('Erro ao executar '+FSeg_sistema+inttostr(error));
               __close(pfd_read[1]);
               __close(pfd_write[0]);
             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               __close(pfd_read[1]);
               __close(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico);
               writetlv(pfd_write[1],FSeg_Identificacao);
               writetlv(pfd_write[1],'VALIDA');
               writetlv(pfd_write[1],Usuario);
               writetlv(pfd_write[1],Senha);//Tem o token para revalidar em BD.
               writetlv(pfd_write[1],''); // Maximo de Logins simultâneos

               if readtlv(pfd_read[0],token) <= 0 then
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               result :=  token[1];
               waitpid(pid,status,0);
               __close(pfd_write[1]);
               __close(pfd_read[0]);
             end;
    end;
{$ELSE}
    BufSize := CreateEnvBlock(Env, True, nil, 0);
    GetMem(  Buffer , BufSize+1024);
    CreateEnvBlock(Env, True, Buffer, BufSize);
    SetErrorMode($FFFF);
    if not CreateProcess({lpApplicationName} NIL,
                             {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],FSeg_Sistema)+' '+AThread.Connection.Binding.PeerIP),
                             {lpProcessAttributes} NIL,
                             {lpThreadAttributes} NIL,
                             {bInheritHandles} True,
                             {dwCreationFlags} 0,
                             {lpEnvironment} Buffer,
                             {lpCurrentDirectory} NIL,
                             {lpStartupInfo} StartUpInfo,
                             {lpProcessInformation} ProcessInformation) then
    begin
        MsgErro(AThread,'Erro ao executar  '+FSeg_Sistema + ' as '+DateTimetoStr(now));
    end else
    begin
        WaitForSingleObject(ProcessInformation.hProcess,INFINITE);
                CloseHandle( ProcessInformation.hProcess );
                CloseHandle( ProcessInformation.hThread );
        FreeMem(Buffer);
    end;
{$ENDIF}
{$IFDEF FPC}
    FreeMem(Parametros,8*sizeof(PChar));
{$ENDIF}
  end;
end;


function TLauncherEnv.TrocaSenhaWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring;
                                    NovaSenha : string = '';wtoken : string = ''): char;
//wtoken tem a chave de seção para o caso da troca de senha onde a senha vem limpa
var
  token : ansistring;
  whome : string;
{$IFDEF LINUX}
  error : integer;
  pid : integer;
  status : PInteger;
  wamb : TPtrStr;
  wpipe : Integer;
  pfd_read,pfd_write   : array[0..1] of Integer;
{$IFDEF FPC}
  w1,w2 : ansistring;
  Parametros : PPchar;
{$ENDIF}
{$ELSE}
  StartUpInfo        : TStartUpInfo;
  ProcessInformation : TProcessInformation;
  BufSize: Integer;         // env block size
  Buffer: Pointer;          // env block
{$ENDIF}
begin
  token := '';
  result := 'F';
  Env.Insert(0,'USER='+ Usuario);
{$IFDEF MSWINDOWS}
  fillchar(StartUpInfo,sizeof(StartUpInfo),0);
  StartUpInfo.cb := SizeOf(TStartupInfo);
  fillchar(ProcessInformation,sizeof(ProcessInformation),0);
{$ENDIF}
  if trim(FSeg_Sistema) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if whome <> '' then
    try
      chdir(whome);
    except
      chdir('/tmp');
    end;
{$IFDEF LINUX}
    wpipe := pipe(@pfd_write);
    if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
    wpipe := pipe(@pfd_read);
    if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
{$IFDEF FPC}
    GetMem(Parametros,8*sizeof(PChar));
{$ENDIF}
    pid :=  fork();
    case pid of
         0 : begin // filho
               __close(pfd_read[0]);
               __close(pfd_write[1]);
               if (UserId <> 0) and (GroupID <> 0) then
               begin
                  setregid(GroupID,GroupID);
                  setreuid(UserId,UserId);
               end;
               SetAmbiente(Env,wamb);
{$IFDEF FPC}
               Parametros[0] :=  PChar(FSeg_Sistema);
               w1 := inttostr(pfd_write[0]);
               Parametros[1] :=  PChar(w1);
               w2 := inttostr(pfd_read[1]);
               Parametros[2] :=  PChar(w2);

               Parametros[3] :=  PChar(AThread.Connection.socket.Binding.PeerIP);
               Parametros[4] :=  nil;

               error := fpexecve(ExecPath(Env.Values['PATH'],FSeg_Sistema),Parametros,@wamb);

{$ELSE}
               error := execle(pchar(ExecPath(Env.Values['PATH'],FSeg_Sistema)),pchar(FSeg_Sistema),
                               pchar(inttostr(pfd_write[0])),PChar(inttostr(pfd_read[1])),
                               pchar(AThread.Connection.socket.Binding.PeerIP),nil,wamb);
{$ENDIF}
               if error <> 0 then
                  WriteLog('Erro ao executar '+FSeg_sistema+inttostr(error));
               __close(pfd_read[1]);
               __close(pfd_write[0]);
             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               __close(pfd_read[1]);
               __close(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico);
               writetlv(pfd_write[1],FSeg_Identificacao);
               writetlv(pfd_write[1],'PASSWD');
               writetlv(pfd_write[1],wtoken);
               writetlv(pfd_write[1],Senha);
               writetlv(pfd_write[1],NovaSenha);
               if readtlv(pfd_read[0],token) <= 0 then
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               result :=  token[1];
               waitpid(pid,status,0);
               __close(pfd_write[1]);
               __close(pfd_read[0]);
             end;
    end;
{$ELSE}
    BufSize := CreateEnvBlock(Env, True, nil, 0);
    GetMem(  Buffer , BufSize+1024);
    CreateEnvBlock(Env, True, Buffer, BufSize);
    SetErrorMode($FFFF);
    if not CreateProcess({lpApplicationName} NIL,
                             {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],FSeg_Sistema)+' '+AThread.Connection.Binding.PeerIP),
                             {lpProcessAttributes} NIL,
                             {lpThreadAttributes} NIL,
                             {bInheritHandles} True,
                             {dwCreationFlags} 0,
                             {lpEnvironment} Buffer,
                             {lpCurrentDirectory} NIL,
                             {lpStartupInfo} StartUpInfo,
                             {lpProcessInformation} ProcessInformation) then
    begin
        MsgErro(AThread,'Erro ao executar  '+FSeg_Sistema + ' as '+DateTimetoStr(now));
    end else
    begin
        WaitForSingleObject(ProcessInformation.hProcess,INFINITE);
                CloseHandle( ProcessInformation.hProcess );
                CloseHandle( ProcessInformation.hThread );
        FreeMem(Buffer);
    end;
{$ENDIF}
{$IFDEF FPC}
    FreeMem(Parametros,8*sizeof(PChar));
{$ENDIF}
  end;
  Senha := wtoken;
end;


function TLauncherEnv.LeSegurancaWS(Env : TIdThreadSafeStringList; AThread : TidPeerThread; UserID, GroupID: integer;
                                    Usuario:string;var  Senha: ansistring; QTDMAXLOGIN : integer; wIP : string): char;
//wtoken tem a chave de seção para o caso da troca de senha onde a senha vem limpa
var
  token : ansistring;
  whome : string;
{$IFDEF LINUX}
  error : integer;
  pid : integer;
  status : PInteger;
  wamb : TPtrStr;
  wpipe : Integer;
  pfd_read,pfd_write   : array[0..1] of Integer;
{$IFDEF FPC}
  w1,w2 : ansistring;
  Parametros : PPchar;
{$ENDIF}
{$ELSE}
  StartUpInfo        : TStartUpInfo;
  ProcessInformation : TProcessInformation;
  BufSize: Integer;         // env block size
  Buffer: Pointer;          // env block
{$ENDIF}
begin
  result := 'F';
  Env.Insert(0,'USER='+ Usuario);
{$IFDEF MSWINDOWS}
  fillchar(StartUpInfo,sizeof(StartUpInfo),0);
  StartUpInfo.cb := SizeOf(TStartupInfo);
  fillchar(ProcessInformation,sizeof(ProcessInformation),0);
{$ENDIF}
  if trim(FSeg_Sistema) <> '' then
  begin
    whome := expande(Env.Values['HOME'],Env);
    if whome <> '' then
    try
      chdir(whome);
    except
      chdir('/tmp');
    end;
{$IFDEF LINUX}
    wpipe := pipe(@pfd_write);
    if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe escrita');
    wpipe := pipe(@pfd_read);
    if wpipe = -1 then MsgErro(AThread,'Erro ao criar pipe leitua');
{$IFDEF FPC}
    GetMem(Parametros,8*sizeof(PChar));
{$ENDIF}
    pid :=  fork();
    case pid of
         0 : begin // filho
               __close(pfd_read[0]);
               __close(pfd_write[1]);
               if (UserId <> 0) and (GroupID <> 0) then
               begin
                  setregid(GroupID,GroupID);
                  setreuid(UserId,UserId);
               end;
               SetAmbiente(Env,wamb);
{$IFDEF FPC}
               Parametros[0] :=  PChar(FSeg_Sistema);
               w1 := inttostr(pfd_write[0]);
               Parametros[1] :=  PChar(w1);
               w2 := inttostr(pfd_read[1]);
               Parametros[2] :=  PChar(w2);

               Parametros[3] :=  PChar(AThread.Connection.socket.Binding.PeerIP);
               Parametros[4] :=  nil;

               error := fpexecve(ExecPath(Env.Values['PATH'],FSeg_Sistema),Parametros,@wamb);


{$ELSE}
               error := execle(pchar(ExecPath(Env.Values['PATH'],FSeg_Sistema)),Pchar(FSeg_Sistema),
                               PChar(inttostr(pfd_write[0])),PChar(inttostr(pfd_read[1])),
                               PChar(AThread.Connection.socket.Binding.PeerIP),nil,wamb);
{$ENDIF}
               if error <> 0 then
                  WriteLog('Erro ao executar '+FSeg_sistema+inttostr(error));
               __close(pfd_read[1]);
               __close(pfd_write[0]);
             end;
        -1 : begin
               raise ECCP_Proto.Create('Erro no fork do processo filho');
             end;
        else begin // pai
               __close(pfd_read[1]);
               __close(pfd_write[0]);
               status := nil;
               Token := '';
               writetlv(pfd_write[1],FSeg_Servico); 
               writetlv(pfd_write[1],FSeg_Identificacao);
               writetlv(pfd_write[1],'LOGIN');
               writetlv(pfd_write[1],Usuario);
               writetlv(pfd_write[1],Senha);
               writetlv(pfd_write[1],''); //NovaSenha
	       if readtlv(pfd_read[0],token) <= 0 then 
                 MsgErro(AThread,'Erro de comunicacao no pipe - tamanho muito grande');
               result :=  token[1];
               waitpid(pid,status,0);
               __close(pfd_write[1]);
               __close(pfd_read[0]);
             end;
    end;
{$ELSE}
    BufSize := CreateEnvBlock(Env, True, nil, 0);
    GetMem(  Buffer , BufSize+1024);
    CreateEnvBlock(Env, True, Buffer, BufSize);
    SetErrorMode($FFFF);
    if not CreateProcess({lpApplicationName} NIL,
                             {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],FSeg_Sistema)+' '+AThread.Connection.Binding.PeerIP),
                             {lpProcessAttributes} NIL,
                             {lpThreadAttributes} NIL,
                             {bInheritHandles} True,
                             {dwCreationFlags} 0,
                             {lpEnvironment} Buffer,
                             {lpCurrentDirectory} NIL,
                             {lpStartupInfo} StartUpInfo,
                             {lpProcessInformation} ProcessInformation) then
    begin
        MsgErro(AThread,'Erro ao executar  '+FSeg_Sistema + ' as '+DateTimetoStr(now));
    end else
    begin
        WaitForSingleObject(ProcessInformation.hProcess,INFINITE);
                CloseHandle( ProcessInformation.hProcess );
                CloseHandle( ProcessInformation.hThread );
        FreeMem(Buffer);
    end;
{$ENDIF}
{$IFDEF FPC}
    FreeMem(Parametros,8*sizeof(PChar));
{$ENDIF}
  end;
  Senha := copy(token,2,length(token));
end;
{$ENDIF}

function TLauncherEnv.SegurancaWS : boolean;
begin
  if UpperCase(trim(FSeg_sistema.value)) <> '' then result := true
  else result := false
end;

//============================================================================//
                               {TBaseUser}
                               
constructor TBaseUser.create(Usuario:AnsiString);
begin
  inherited create;
  fuser := TIdThreadSafeString.Create;
  fhome := TIdThreadSafeString.Create;
  fPasswd := TIdThreadSafeString.Create;
  fDTValSenha := TIdThreadSafeDateTime.Create;
  fUltAltSenha := TIdThreadSafeDateTime.Create;
  fSenha1 := TIdThreadSafeString.Create;
  fSenha2 := TIdThreadSafeString.Create;
  fSenha3 := TIdThreadSafeString.Create;
  fSenha4 := TIdThreadSafeString.Create;
  fSenha5 := TIdThreadSafeString.Create;
  fUltimoUso := TIdThreadSafeDateTime.Create;
  FUser.Value := Usuario;
  FUserActive := true;
  fUserTentativasE := 0; 
  fDtValSenha.Value := now+20000;
  fSectionTimeOut := 0;
  fUltimoUso.Value := now;
end;

destructor TBaseUser.destroy;
begin
  fuser.free;
  fhome.free;
  fPasswd.free;
  fDTValSenha.free;
  fUltAltSenha.free;
  fSenha1.free;
  fSenha2.free;
  fSenha3.free;
  fSenha4.free;
  fSenha5.free;
  fUltimoUso.free;
  inherited;
end;


function TBaseUser.SectionTimedOut : boolean;
var l : longint;
begin
//  writelog('= qtd min = '+ floattostr((now - fUltimoUso.value)*MinsPerDay));
  result := (fSectionTimeOut > 0) and ((now - fUltimoUso.value)*MinsPerDay > fSectionTimeOut) ;
end;


//============================================================================//
                                 {TDBUser}

constructor TDBUser.create(Usuario:AnsiString);
begin
  inherited;
  fDriverName := TIdThreadSafeString.Create;
end;

destructor TDBUser.destroy; 
begin
  fDriverName.free;
  inherited;
end;

procedure TDBUser.GetEnv(Env,GlobalEnv:TIdThreadSafeStringList);
begin
end;

function TDBUser.SenhaOK(Senha:AnsiString):boolean;
begin
  Result := FPasswd.value = md5crypt(PChar(Senha), pchar(FPasswd.value))
end;

function TDBUser.TestMaxPass:boolean;
begin
  Result := (int(now) <= FUltAltSenha.value+FMaxMudaSenha);
end;

function TDBUser.TestPasswdDate:boolean;
begin
  Result := (int(now) <= FDtValSenha.value);
end;

function TDBUser.TestPasswdChange:boolean;
begin
  Result := (FMinMudaSenha = 0) or (int(now) <= FUltAltSenha.value+FMinMudaSenha);
end;


function TestaSenhaRepetida(SenhaBD,Senha : ansistring) : boolean;
var 
  SenhaEnc : Ansistring;
begin
    result := false;
    SenhaEnc := md5crypt(pchar(trim(senha)),pchar('$1$'+copy(SenhaBd,4,6)+'$'));
    if SenhaBd = SenhaEnc then  result := true; 
end;

function TDBUser.SenhaUsada ( pw : string) : boolean;
begin
  if TestaSenhaRepetida(fPasswd.value,pw) or TestaSenhaRepetida(fsenha1.value,pw) or 
     TestaSenhaRepetida(fsenha2.value,pw) or TestaSenhaRepetida(fsenha3.value,pw) or 
     TestaSenhaRepetida(fsenha4.value,pw) or TestaSenhaRepetida(fsenha5.value,pw)then
    result := true 
  else result := false;
end;

function TDBUser.LimiteDiasSenha(DiasExpira : integer) : boolean;
begin
   result := (DiasExpira = 0) or ((now - fUltAltSenha.value) <= DiasExpira)
end;

//============================================================================//
                                {TWSDBuser}
procedure TWSDBUser.GetEnv(Env,GlobalEnv:TIdThreadSafeStringList);
begin
end;

function TWSDBUser.SenhaOK(Senha:AnsiString):boolean;
begin
  Result := FPasswd.value = Senha;
end;

function TWSDBUser.TestMaxPass:boolean;
begin
  Result := true;
end;

function TWSDBUser.TestPasswdDate:boolean;
begin
  Result := true;
end;

function TWSDBUser.TestPasswdChange:boolean;
begin
  Result := true;
end;

function TWSDBUser.SenhaUsada ( pw : string) : boolean;
begin
  result := false;
end;

function TWSDBUser.LimiteDiasSenha(DiasExpira : integer) : boolean;
begin
   result := true;
end;


//============================================================================//
                                {TLinuxUser}
                                
constructor TLinuxUser.create(Usuario:AnsiString);
{$IFDEF LINUX}
var
  Password_rec : PPasswordRecord;
  Shadow_rec : PPasswordFileEntry;
{$ENDIF}
begin
  inherited Create(Usuario);
  fshell := TIdThreadSafeString.Create;
{$IFDEF LINUX}
{$IFDEF FPC}
  Password_rec := fpgetpwnam(pchar(Usuario));
{$ELSE}
  Password_rec := getpwnam(pchar(Usuario));
{$ENDIF}
  if Password_rec <> nil then
  begin
    fhome.value := Password_rec^.pw_dir;
    fshell.value := Password_rec^.pw_shell;
    Shadow_rec := getspnam(pchar(Usuario));
    if Shadow_rec <> nil then
    begin
      FUltMudancaSenha := shadow_rec^.sp_lstchg;
      FMinMudaSenha := shadow_rec^.sp_min;
      FMaxMudaSenha := shadow_rec^.sp_max;
      FAvisaMudaSenha := shadow_rec^.sp_warn;
      FViraInativaSenha:= shadow_rec^.sp_inact;
      FExpiraSenha := shadow_rec^.sp_expire;
      FPasswd.value := shadow_rec^.sp_pwdp;
    end
    else raise Exception.Create('Erro ao ler Passwd/Shadow');
  end
  else raise Exception.Create('Erro ao ler Passwd/Shadow');
{$IFDEF FPC}
  fpendpwent;
  endspent;
{$ENDIF}

{$ENDIF}
end;

destructor TLinuxUser.destroy; 
begin
  fShell.free;
  inherited;
end;

procedure TLinuxUser.GetEnv(Env,GlobalEnv:TIdThreadSafeStringList);
var 
  index : integer;
  wambiente : TIdThreadSafeStringList;
begin
  wambiente := TIdThreadSafeStringList.create;
  try
    Env.Clear;
    if fshell.value <> '/bin/sh' then 
       wAmbiente.LoadFromFile(fhome.value +'/.bash_profile')
    else
       wAmbiente.LoadFromFile(fhome.value +'/.profile');
    for Index := 0 to wAmbiente.Count - 1 do 
       if (copy(wAmbiente[Index],1,1) <> '[') and
        (copy(wAmbiente[Index],1,1) <> '#') and
        (pos('=',wAmbiente[Index]) <> 0) then 
       Env.add(wambiente[Index]);
    Env.Values['USER'] := fuser.value ;
    Env.Values['HOME'] := fhome.value ;
  finally
    freeandnil(wambiente);
  end;
end;

function TLinuxUser.SenhaOK(Senha:AnsiString):boolean;
begin
      Result := false;
{$IFDEF LINUX}
      if FPasswd.value  <> '' then 
        Result := FPasswd.value = crypt(PChar(Senha ), pchar(FPasswd.value ))
{$ENDIF}
end;

function TLinuxUser.TestPasswdDate:boolean;
begin
  result := true;
end;

function TLinuxUser.TestMaxPass:boolean;
begin
  result := true;
end;

function TLinuxUser.TestPasswdChange:boolean;
begin
  result := true;
end;

function TLinuxUser.SenhaUsada ( pw : string) : boolean;
begin
  result := false;
end;

function TLinuxUser.LimiteDiasSenha( diasexpira : integer ) : boolean ; 
begin
  result := true;
end;

//===========================================================================
                           {TCCPServer}

constructor TCCPServer.create(AOwner: TComponent);
begin
        inherited;
        LauncherEnvList := TLauncherEnvList.Create;
{$IFDEF LINUX}
        MaxConnections := 500000;
        UnhookSignal(RTL_SIGINT);
{$IFDEF FPC}
//        OnException:= @HandleError;
        fpsignal(SIGQUIT,@trataquit);
        fpsignal(SIGINT,@trataint);
        fpsignal(SIGHUP,@tratahup);
        fpsignal(SIGTERM,@trataterm);
        fpsignal(SIGUSR1,@tratadebug);
        fpsignal(SIGWINCH, TSignalHandler(SIG_IGN));
{$ELSE}
        signal(SIGQUIT,trataquit);
        signal(SIGINT,trataint);
        signal(SIGKILL,tratakill);
        signal(SIGHUP,tratahup);
        signal(SIGTERM,trataterm);
        signal(SIGWINCH, TSignalHandler(SIG_IGN));
{$ENDIF}
{$ENDIF}
end;

destructor TCCPServer.destroy;
begin
        LauncherEnvList.Free;
        inherited;
end;

{
procedure TCCPServer.HandleError(T:TIdContext;E:Exception);
begin
writelog('Error Exception Catch!!!!!');
end;
}

function posset (term : Tchar; inicio : integer; st : ansistring ):integer;
var
  i : integer;
begin
  i := inicio ;
  result := 0; 
  while i <= length(st) do
  begin
    if st[i] in term then 
    begin
      result := i;
      break;
    end;
    inc(i);
  end;
  if i >= length(st) then result := i;
end;

function expande(wAmbVar : string) : String;
var
    i,pfim : integer;
    novovalor : AnsiString;
begin
  if wAmbVar <> '' then
  begin
      i := 1;
      repeat
        while (i <= length(wAmbVar)) and  (wAmbVar[i] <> '$') do inc(i);
        if wAmbVar[i] = '$' then
        begin
          pfim := posset(['[','/','\',':',' ','(',#10,#13],i+1,wAmbVar);
          if pfim > 0 then
          begin
{$IFDEF LINUX}
            novovalor := getenv(copy(wAmbVar,i+1,pfim-i-1));
{$ELSE}
            novovalor := GetEnvironmentVariable(pchar(copy(wAmbVar,i+1,pfim-i-1)));
{$ENDIF}
            if novovalor <> '' then
            begin
              delete(wAmbVar,i,pfim-i);
              insert(novovalor,wAmbVar,i);
            end;
          end;
          inc(i);
        end;
      until i >= length(wAmbVar);
      result := wAmbVar;
  end;
end;

function expande(wAmbVar : string; Env : TIdThreadSafeStringList) : String;

var
    i,pfim : integer;
    novovalor : AnsiString;
begin
  if wAmbVar <> '' then
  begin
      i := 1;
      repeat
        while (i <= length(wAmbVar)) and  (wAmbVar[i] <> '$') do inc(i);
        if wAmbVar[i] = '$' then
        begin
          pfim := posset(['[','/','\',':',' ','(',#10,#13],i+1,wAmbVar);
          if pfim > 0 then
          begin
            novovalor := Env.Values[copy(wAmbVar,i+1,pfim-i-1)];
            if novovalor <> '' then
            begin
              delete(wAmbVar,i,pfim-i);
              insert(novovalor,wAmbVar,i);
            end;
          end;
          inc(i);
        end;
      until i >= length(wAmbVar);
      result := wAmbVar;
  end;
end;

procedure expande(Env : TIdThreadSafeStringList);
var Index : Integer;
begin
  for Index := 0 to Env.Count - 1 do
    if pos('=',Env[Index]) > 0 then
      Env[Index] := expande(Env[Index],Env);
end;

{$IFDEF MSWINDOWS}
function GetAllEnvVars(const Vars: TStrings): Integer;
var
  PEnvVars: PChar;    // pointer to start of environment block
  PEnvEntry: PChar;   // pointer to an env string in block
begin
  // Clear the list
  if Assigned(Vars) then
    Vars.Clear;
  // Get reference to environment block for this process
  PEnvVars := GetEnvironmentStrings;
  if PEnvVars <> nil then
  begin
    // We have a block: extract strings from it
    // Env strings are #0 separated and list ends with #0#0
    PEnvEntry := PEnvVars;
    try
      while PEnvEntry^ <> #0 do
      begin
        if Assigned(Vars) then
          Vars.Add(PEnvEntry);
        Inc(PEnvEntry, StrLen(PEnvEntry) + 1);
      end;
      // Calculate length of block
      Result := (PEnvEntry - PEnvVars) + 1;
    finally
      // Dispose of the memory block
      Windows.FreeEnvironmentStrings(PEnvVars);
    end;
  end
  else
    // No block => zero length
    Result := 0;
end;

procedure DeleteDuplicate(var New : TIdThreadSafeStringList;Launcherenv : TIdThreadSafeStringList);
var IdxNew, IdxLauncher: integer;
    
begin
    for IdxLauncher := 0 to Pred(LauncherEnv.Count) do
	begin
	  IdxNEw := New.IndexOfName(Launcherenv.Names[IdxLauncher]);
      if IdxNew > -1 then 
		  New.Delete(IdxNew);
    end;
end;

function CreateEnvBlock(const NewEnv: TStrings; 
  const IncludeCurrent: Boolean;
  const Buffer: Pointer; 
  const BufSize: Integer): Integer;
var
  EnvVars: TIdThreadSafeStringList; // env vars in new block
  Idx: Integer;         // loops thru env vars
  PBuf: PChar;          // start env var entry in block
begin
  // String list for new environment vars
  EnvVars := TIdThreadSafeStringList.Create;
  try
    // include current block if required
    if IncludeCurrent then
	begin
      GetAllEnvVars(EnvVars);
	  DeleteDuplicate(EnvVars,NewEnv);
	end;
    // store given environment vars in list
    if Assigned(NewEnv) then
      EnvVars.AddStrings(NewEnv);
    // Calculate size of new environment block
    Result := 0;
    for Idx := 0 to Pred(EnvVars.Count) do
      Inc(Result, Length(expande(EnvVars[Idx],EnvVars)) + 1);
    Inc(Result);
    // Create block if buffer large enough
    if (Buffer <> nil) and (BufSize >= Result) then
    begin
      // new environment blocks are always sorted
//      EnvVars.Sorted := True;
      // do the copying
      PBuf := Buffer;
      for Idx := 0 to Pred(EnvVars.Count) do
      begin
	    EnvVars[Idx] := expande(EnvVars[Idx],EnvVars);
        StrPCopy(PBuf, EnvVars[Idx]);
        Inc(PBuf, Length(EnvVars[Idx]) + 1);
      end;
      // terminate block with additional #0
      PBuf^ := #0;
    end;
  finally
    EnvVars.Free;
  end;
end;

{$ELSE}

procedure SetAmbiente(Ambiente:TIdThreadSafeStringList; var stamb:TPtrStr);
var
    I,Index : integer;
    st: AnsiString;
begin
  I := 1;
  for Index := 0 to Ambiente.Count - 1 do
  begin
    if pos('=',Ambiente[Index]) > 0 then
    begin
      Ambiente[Index] := expande(Ambiente[Index],Ambiente);
      if I < MAXSTR then 
      begin
  	stamb[i] := pchar(ambiente[Index]);
	inc(i);
      end;
    end;
  end;
  stamb[I] := nil;
end;

{$ENDIF}


procedure SetAmbiente(Ambiente:TIdThreadSafeStringList);
var
    Index : integer;
{$IFDEF FPC}
    EnvSt : String;
{$ENDIF}
begin
  for Index := 0 to Ambiente.Count - 1 do
  begin
//    Ambiente[Index];
    if pos('=',Ambiente[Index]) > 0 then
    begin
      Ambiente[Index] := expande(Ambiente[Index]);
{$IFDEF LINUX}
{$IFDEF FPC}
      EnvSt := Ambiente[Index];
      setcenv(EnvSt);
{$ELSE}
      putenv(Pchar(Ambiente[Index]));
{$ENDIF}
{$ELSE}
      SetEnvironmentVariable(Pchar(Ambiente.Names[Index]),Pchar(Ambiente.Values[Ambiente.Names[Index]]));
{$ENDIF}
    end;
  end;
end;

function TCCPServer.AlteraSenha(Usuario : ansistring; var Senha : ansistring) : boolean;
var
        Salt : string;
begin
       result := true;
       Salt := '$1$'+formatdatetime('mmsshh',now)+'$';
       Senha := MD5crypt(Senha,Salt);
end;

function Descriptografa(st : ansistring ) : ansistring;
var 
  salt : ansistring;
  iv : ansistring;
begin
  salt := copy(st,5,9);
  st := DecodeBase64(copy(st,14,maxint));
  iv := DecodeBase64(LauncherIni.IVComum.Value);
  {$IFDEF FPC}  
  result := AnsiString(PAnsichar(AesDecrypt(DecodeBase64(mod1(LauncherIni.ChaveComum.value,salt)),IV,St,CBC)));
  {$ENDIF}
// AnsiString(PAnsichar( - para  remover o padding
end;

{$IFDEF FPC}
procedure ParseUsuarioSenhaPrograma(UsuarioSenhaPrograma : ansistring; var Usuario,Senha,Path,Programa,NovaSenha : ansistring; var wCaptcha : ansistring ;var worigen : ansistring );
{$ELSE}
procedure ParseUsuarioSenhaPrograma(UsuarioSenhaPrograma : ansistring; var Usuario,Senha,Path,Programa,NovaSenha : ansistring; var wCaptcha : ansistring );
{$ENDIF}
var
//  p,
  i : integer;
//  nome,
//  valor : string;
  IV : ansistring;
  StList : TStringList;
begin
  usuario := '';
  senha := '';
  Programa := '';
  Path := '';
  NovaSenha := '';
  if (UsuarioSenhaPrograma <> '') then
  begin
    if copy(UsuarioSenhaPrograma,1,3) = '$CC' then
      UsuarioSenhaPrograma := decrypt(copy(UsuarioSenhaPrograma,4,length(UsuarioSenhaPrograma)));
    if UsuarioSenhaPrograma[1] = ':' then 
    begin
      StList := TStringList.Create;
      try
        StList.Delimiter := ':';
        StList.QuoteChar := '''';
        StList.DelimitedText := UsuarioSenhaPrograma;
        Path := ExtractFilePath(Stlist.Values['SERVERPATH']);
        Programa := ExtractFileName(Stlist.Values['SERVERPATH']);
        Usuario := Stlist.Values['USUARIO'];
        Senha := Stlist.Values['SENHA'];
{$IFDEF FPC}
        wCaptcha := Stlist.Values['CAPTCHA'];
        wOrigen := Stlist.Values['ORIGIN'];
{$ENDIF}
        NovaSenha := Stlist.Values['NOVASENHA'];
      finally
        StList.Free;
      end;
    end
    else begin
{$IFNDEF LINUX} // para evitar warnings
      if PathDelim = '\' then
        UsuarioSenhaPrograma := StringReplace(UsuarioSenhaPrograma,'/','\',[rfReplaceAll])
      else
{$ENDIF}
        UsuarioSenhaPrograma := StringReplace(UsuarioSenhaPrograma,'\','/',[rfReplaceAll]);
      i := pos(',',UsuarioSenhaPrograma);
      if i = 0 then i := length(UsuarioSenhaPrograma)+1;
      Programa := copy(UsuarioSenhaPrograma,1,i-1);
      Path := ExtractFilePath(Programa);
      Programa := ExtractFileName(programa);
      UsuarioSenhaPrograma := copy(UsuarioSenhaPrograma,i+1,MaxInt);
      i := pos(',',UsuarioSenhaPrograma);
      if i = 0 then i := length(UsuarioSenhaPrograma)+1;
      Usuario := copy(UsuarioSenhaPrograma,1,i-1);
      UsuarioSenhaPrograma := copy(UsuarioSenhaPrograma,i+1,MaxInt);
      i := pos(',',UsuarioSenhaPrograma);
      if i = 0 then i := length(UsuarioSenhaPrograma)+1;
      Senha := copy(UsuarioSenhaPrograma,1,i-1);
      UsuarioSenhaPrograma := copy(UsuarioSenhaPrograma,i+1,MaxInt);
      if UsuarioSenhaPrograma <> '' then
      begin
        i := pos(',',UsuarioSenhaPrograma);
        if i = 0 then i := length(UsuarioSenhaPrograma)+1;
        NovaSenha := copy(UsuarioSenhaPrograma,1,i-1);
        UsuarioSenhaPrograma := copy(UsuarioSenhaPrograma,i+1,MaxInt);
        if UsuarioSenhaPrograma <> '' then
        begin
          i := pos(',',UsuarioSenhaPrograma);
          if i = 0 then i := length(UsuarioSenhaPrograma)+1;
          wCaptcha := copy(UsuarioSenhaPrograma,1,i-1);
        end;
      end;
    end;
    iv := '';
    if copy(usuario,1,4) = '____' then usuario := Descriptografa(usuario);
    if copy(senha,1,4) = '____' then Senha :=  Descriptografa(senha);
  end;
end;

{$IFDEF FPC} // Rotina Versao EXCLUSIVA FPC ************************

function TCCPServer.ProgramExecute(Usuario      : String;
                               var Senha        : ansiString;
                                   ParmExtra	: String;
                                   Path,
                                   Programa     : String;
                                   Env          : TIdThreadSafeStringList;
                                   LoginStr,
                                   LogOffStr,
				   LogPassStr   : string;
                                   AThread      : TidPeerThread;
                                   WSLogin      : boolean = false;
                                   UserID       : Integer=0;
                                   GroupId      : Integer=0;
                                   SenhaAntiga  : boolean=false;
                                   wSenhaAntiga : Integer=-999;
                                   NovoModoOp   : boolean = false;
                                   wtoken : string = '';
                                   Criptografa : boolean = false;
                                   Salt : string = '';
                                   wsistema : string = '';
                                   wPermiteRedefinirSenha : boolean = false;
                                   wOrigem : string = ''):boolean;
var
  LauncherEnv : TLauncherEnv;
  ControleAcessoStr : string;
  Erro,PID : longint;
  status : PInteger;
  whome, msg : ansistring;
  Prog : TMyProc;
  MyEnv: TIdThreadSafeStringList;
  wamb : TPtrStr;
  w1,w2 : ansistring;
  Parametros : PPchar;
  ArrPchar : array [0..8] of PChar;
  wParmExtra,wprograma,localwip,ProgramPath : ansistring;
  pErro : string;
  ch : longint;
  st4 : ansistring;
begin
  if trim(wOrigem) = '' then
    wOrigem := Parmextra;
{$IFDEF FPC}
  wamb := Default(TPtrStr);
{$ELSE}
  fillchar(wamb,sizeof(wamb),0);
{$ENDIF}
  WriteLog('  ==== ProgramExecute '+Programa+' - por : '+usuario );
  result := true;
  pErro := '';
  try
    MyEnv := TIdThreadSafeStringList.create;
//  MyEnv.Assign(Env);
    Env.assignTo(MyEnv);
    with AThread.Connection do
    begin
      WriteLog('  ==== Antes do Case do método ');
      case Programa of
        'KILL' : begin
                   pid :=  fpfork();
                   case pid of
                     0 : begin // filho
                           if (UserId <> 0) and (GroupID <> 0) then
                           begin
                             fpsetregid(GroupID,GroupID);
                             fpsetreuid(UserId,UserId);
                           end;
                           try
                             if (ParmExtra <> '') and (strtoint(ParmExtra) <> getpid()) and
                                (strtoint(ParmExtra)<> fpgetppid()) and (strtoint(ParmExtra)>200) then
                             begin
                               fpkill(strtoint(ParmExtra),15);
                               sleep(100); 
                               fpkill(strtoint(ParmExtra),9);
                             end;
                             writeres(AThread,SRV_OK);
                           except
                             writeres(AThread,SRV_NOK);
                           end;
//                           AThread.Connection.IOHandler.Close;
                           halt(0);
                          end;
                     -1 : begin
                            raise ECCP_Proto.Create('Erro no fork do processo filho');
                            result := false;
                          end;
                      else begin // pai
                            status := nil;
                            fpwaitpid(pid,status,0);
                      end;
                   end;
                 end;
        'HUP'  : begin
                   WriteLog('Relendo a configuração de '+ParmExtra);
                   writeres(AThread,SRV_OK);
                   if ParmExtra <> '' then 
                   begin
                     LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
                     LauncherEnv.LimpaCache(ParmExtra);
                   end
                   else LauncherEnvList.Reset := true;
                 end ;
        'EMAILPWD':begin
                     // so funciona com loginbd
                     if WSLogin and
                        wPermiteRedefinirSenha and
                        (wSistema = 'loginbd') then
                     begin
                       if ParmExtra <> '' then
                       begin
                         LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
                         LauncherEnv.LimpaCache(ParmExtra);
                       end
                       else LauncherEnvList.Reset := true;
                       if LauncherEnv.EmailPasswordWS(Env,AThread,UserID,GroupID,usuario,senha,ParmExtra,perro) = 'F' then
                       begin
                               writeres(AThread,SRV_NOK_MSG);
                               writeres_st(AThread,pErro);
                       end
                       else writeres(AThread,SRV_OK);
                     end
                     else begin
                       writeres(AThread,SRV_NOK_MSG);
                       writeres_st(AThread,'Ambiente não permite redefinição de senha por e-mail!');
                     end;
                   end;
        'PASSWD' :begin
                    if LogPassStr <> '' then
                      ExecLog(Athread,MyEnv,UserId,GroupID,LogPassStr,'');
                    LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
                    if assigned(LauncherEnv) and not LauncherEnv.GetUser(usuario).SenhaUsada(ParmExtra) then
                    begin
                      msg := '';
                      try
                        ValidaSenha(ParmExtra,LauncherEnv.MinCaracPass, LauncherEnv.MinAlfaPass,
                                     LauncherEnv.MinAlfaMaisPass,LauncherEnv.MinNumPass,
                                     LauncherEnv.MaxRepPass,LauncherEnv.MaxSeqPass,LauncherEnv.CaracPass.value,
                                     LauncherEnv.CarMinEspPass);
                      except
                        on e : exception do
                          msg := 'ValidaSenha : '+e.message;
                      end;
                      if Msg = '' then 
                      begin
                         if WSLogin then
                         begin
                           pErro := '';
                           if LauncherEnv.TrocaSenhaWS(Env,AThread,UserID,GroupID,usuario,Senha,ParmExtra,wtoken,pErro) = 'T' then
                           begin
                             LauncherEnv.GetUser(Usuario).passwd.value := '';
                             writeres(AThread,SRV_OK)
                           end
                           else begin
                             if pErro > '' then begin
                               writeres(AThread,SRV_NOK_MSG);
                               writeres_st(AThread,pErro);
                               raise ECCP.Create(pErro);
                             end
                             else begin
                               writeres(AThread,SRV_NOK);
                               raise ECCP.Create('Não foi possivel alterar a senha');
                             end;
                           end;
                         end
                         else begin
                           wParmExtra := ParmExtra;
                           if AlteraSenha(Usuario,wParmExtra) then 
                           begin
                             LauncherEnv.GravaSenhaBD(usuario,wParmExtra);
                             writeres(AThread,SRV_OK);

                             LauncherEnv.GetUser(usuario).Passwd.value := wParmExtra; 
                             LauncherEnv.GetUser(usuario).MustChange := false; 
                             LauncherEnv.GetUser(usuario).UltAltSenha.value := now;
//                             LauncherEnv.GetUser(usuario).Passwd :=  md5crypt(pchar(trim(Senha)),wParmExtra);
//                             LauncherEnv.LimpaCache(Usuario);
//                             LauncherEnvList.Reset := true;
                           end
                           else begin
                             writeres(AThread,SRV_NOK);
                             raise ECCP.Create('Não foi possivel alterar a senha');
                           end;
                         end;
                      end
                      else begin
                         writeres(AThread,SRV_NOK_MSG);
                         writeres_st(AThread,msg);
                         raise ECCP.Create(Msg);
                      end;
                    end
                    else begin
                       msg := 'Esta senha já foi usada anteriormente';
                       writeres(AThread,SRV_NOK_MSG);
                       writeres_st(AThread,msg);
                       raise ECCP.Create('Esta senha já foi usada anteriormente');
                    end;
                  end;
        'PING'  : writeres(AThread,SRV_PING_REPLY or CalcIdle shl 16);
        'AMB'   : writeres_st(AThread,MyEnv.CommaText);
        'TYPE'  : writeres_St(AThread,FileSearch(ParmExtra,MyEnv.Values['PATH']));
        'LOGOFF': begin
                    if WSLogin then Senha := '';
                    if LogOffStr <> '' then
                    begin
                      LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
                      if assigned(LauncherEnv) then
                      begin
                        if LauncherEnv.VerificaSectionKeyBD then
                          ExecLog(Athread,MyEnv,UserId,GroupID,LogOffStr,ParmExtra,LauncherEnv.GetSection(Usuario).SectionKey.Value)
                        else
                          ExecLog(Athread,MyEnv,UserId,GroupID,LogOffStr,ParmExtra);
                        if WSLogin then LauncherEnv.GetUser(Usuario).Passwd.value := '';
                     end;
                    end;
                  end;
        'LOGIN' : begin

                     ControleAcessoStr := MyEnv.Values['CONTROLEACESSO'];
                     if (ControleAcessoStr = '') and (LogInStr <> '') then
                       ExecLog(Athread,MyEnv,UserId,GroupID,LogInStr,wOrigem);
                     if SenhaAntiga  then begin
                       ch := SRV_NOK_CHANGE or wSenhaAntiga shl 16;
                       st4 := '';
                       setlength(st4,4);
                       move(ch,st4[1],4);
                       msg := st4 + senha;
                       writeres_st(AThread,msg)
                     end
                     else begin
                       if ControleAcessoStr <> '' then begin
                         ControleAcessoStr := FileSearch(ControleAcessoStr,MyEnv.Values['PATH']) + ' '+
                                              MyEnv.Values['USER'] + ' '+
                                              quotedStr(MyEnv.Values['SCCIDIRATV'])+' '+
                                             socket.Binding.PeerIP;
                         SetAmbiente(MyEnv);
                         rshell(ControleAcessoStr);
                         Erro := ShellExitCode;
                         if erro <> 0 then 
                           writeres(AThread,SRV_NOK_ACESSO)
                         else
                           if WSLogin then writeres_st(AThread,char(SRV_WS_OK)+Senha)
                           else writeres(AThread,SRV_OK);
                       end
                       else
                         if WSLogin then writeres_st(AThread,char(SRV_WS_OK)+Senha)
                         else writeres(AThread,SRV_OK);

                     end;
        end
        else begin  // -----Chamada defalt dos programas w , nao e´ nenhum metodo predefinido
               if not NovoModoOp then
               begin
                 Path := IncludeTrailingPathDelimiter(Path);
                 Programa := Path + Programa;
               end;
{------ Retirando o ProgramExecute para otimizar a execuçao e diminuir deadlocks 
               Prog := TMyProc.Create(nil);
               StdErrlist  := tstringlist.create;
               try
                 Prog.userid := UserId;
                 prog.groupid := GroupId;
                 prog.MyAthread := AThread;
                 with Prog do
                 begin
                   Expande(MyEnv);
                   Parameters.Add(inttostr(socket.Binding.Handle));
                   if NovoModoOp then
                     Parameters.Add(PChar(socket.Binding.PeerIP));
                   Executable :=  ExecPath(MyEnv.Values['PATH'],Programa);
                   if (Executable = '') or not TemPerm(Executable) then 
                   begin // Como nao deu o fork tem q mandar um pid e depois a menssagem
                     writeres(AThread,0); 
                     MsgErro(AThread,'Programa '+Programa+' nao encontrado no PATH ou sem permissao');
                     raise exception.Create('Programa '+Programa+' nao encontrado no PATH ou sem permissao');
                   end;
                   Options := [poWaitOnExit,poDefaultErrorMode];
                   whome := MyEnv.Values['HOME'];
                   if DirectoryExists(whome) then CurrentDirectory := whome
                   else CurrentDirectory := '/tmp';
                   Environment := MyEnv;
                   OnForkEvent := @AfterForkExec;
                   try
                     Execute;
                     WaitOnExit;
                   except
                     on e : exception do
                     begin
                       MsgErro(AThread,'Erro ao executar '+ Executable + ' com cógigo de erro: ' + IntToStr(ExitStatus));
                       raise exception.Create('Erro ao executar '+ Executable + ' com cógigo de erro: ' + IntToStr(ExitStatus));
                     end;
                   end;
                 end;
                 if assigned(Prog.StdErr) and (prog.StdErr.NumBytesAvailable > 0) then
                 begin
                   stderrlist.loadfromstream(prog.StdErr);
                   StdErrList.SaveToFile('/var/log/launcher_err.log');
                 end;
               finally
                 freeandnil(StdErrList);
                 freeandnil(prog);
               end;
------}
            try
               Parametros := @ArrPchar;
               wprograma := programa;
               if NovoModoOp then
               begin
                 Parametros[0] :=  PChar(wprograma);
                 w1 := inttostr(socket.Binding.Handle);
                 Parametros[1] :=  PChar(w1);
                 localwip :=  PChar(socket.Binding.PeerIP);
                 Parametros[2] :=  PChar(localwip);
                 Parametros[3] :=  nil;
               end
               else
               begin
                 Parametros[0] :=  PChar(wprograma);
                 w1 := inttostr(socket.Binding.Handle);
                 Parametros[1] :=  PChar(w1);
                 Parametros[2] :=  nil;
               end;
               if (Programa = '') or not TemPerm(ExecPath(MyEnv.Values['PATH'],Programa)) then
               begin // Como nao deu o fork tem q mandar um pid e depois a menssagem
                 writeres(AThread,0);
                 MsgErro(AThread,'Programa '+Programa+' nao encontrado no PATH ou sem permissao');
                 raise exception.Create('Programa '+Programa+' nao encontrado no PATH ou sem permissao');
               end
               else
               begin
                 whome := expande(Env.Values['HOME'],Env);
                 if (whome = '') or not DirectoryExists(whome) then
                   whome := '/tmp';
                 SetAmbiente(Env,wamb);
                 ProgramPath := ExecPath(Env.Values['PATH'],Programa);
                 pid :=   fpfork();
                 case pid of
                   0 : begin // filho
                         if (UserId + GroupID) > 1 then
                         begin
                           fpsetregid(GroupID,GroupID);
                           fpsetreuid(UserId,UserId);
                         end;
                         fpchdir(pchar(whome));
                         fpclose(listenerfd);
                         if SaidaPadrao then
                         begin
                           fpclose(1);            // Redireciona o StdOut p. /dev/null
                           fpopen(pchar('/dev/null'),O_RDWR);
                           fpclose(2);            // Redireciona o StdOut p. /dev/null
                           fpopen(pchar('/dev/null'),O_RDWR);
                         end;
                         erro := fpexecve(PChar(ProgramPath),Parametros,@wamb);
                         if erro = -1 then
                         begin
                           MsgErro(Athread,'Não foi possivel executar o programa ');
                           sleep(100); // para o waitpid pegar o filho morrendo
                           halt(1);
                         end
                         else begin
                           MsgErro(Athread,'Condição anormal ao executar ');
                           sleep(100); // para o waitpid pegar o filho morrendo
                           halt(1);
                         end;
                       end;
                  -1 : begin
                         raise ECCP.Create('Erro no fork do processo filho');
                         result := false;
                   end;
                   else begin // pai
                     writeres(AThread,pid);
                     status := nil;
                     fpwaitpid(pid,status,0);
                   end;
                 end;
              end;
            finally

            end;
        end;
      end;
//      AThread.Connection.IOHandler.Close;  /// Acho q é automatico
    end;
  finally
    FreeAndNil(MyEnv);
  end;
end;


procedure TCCPServer.ExecLog(Athread :TidPeerThread;Env:TIdThreadSafeStringList;UserId,GroupID : integer;LogStr,ParmExtra:string;Session_Key : string = '');
var
  ArrPchar : array [0..11] of PChar;
  Parametros : PPchar;
  wprograma,
  worigem,wip,whome : ansistring;
  Programa : TMyProc;
  contparam,p : integer;
  StdErroList: TStringList;
{$IFDEF LINUX}
  erro : integer;
  pid : integer;
  status : PInteger;
  wamb : TPtrStr;
{$ENDIF}
  wst : array [1..11] of ansistring;
  contst : integer;
  wsessionkey,localwip,ProgramPath : ansistring;
begin
{$IFDEF FPC}
  wamb := Default(TPtrStr);
{$ELSE}
  fillchar(wamb,sizeof(wamb),0);
{$ENDIF}
  LogStr := trim(LogStr);
  if LogStr <> '' then
  begin
    try
      Parametros := @ArrPChar;
      whome := expande(Env.Values['HOME'],Env);
      if (whome = '') or not DirectoryExists(whome) then
        whome := '/tmp';
      LogStr := expande(LogStr,Env);

      p := pos(' ',LogStr);
      ContParam := 0;
      wprograma := copy(LogStr,1,p-1);
      Parametros[ContParam] := PChar(wPrograma);
      inc(ContParam);
      contst := 1;
      repeat
        delete(LogStr,1,p);
        p := pos(' ',LogStr);
        if p > 0 then wst[Contst] := copy(LogStr,1,p-1)
        else wst[Contst]:= LogStr;
        Parametros[ContParam] := PChar(wSt[contst]);
        inc(ContParam);
        inc(contst);
      until p <= 0;
      if trim(ParmExtra) <> '' then
      begin
        splitpair(ParmExtra,wOrigem,wIP);              
        Parametros[ContParam] := PChar(wIP);
        inc(ContParam);
        Parametros[ContParam] := PChar(wOrigem);
        inc(ContParam);
      end
      else begin
        localwip := PChar(AThread.Connection.socket.Binding.PeerIP);
        Parametros[ContParam] := PChar(localwip);
        inc(ContParam);
        Parametros[ContParam] := PChar('S_ORIGEM');
        inc(ContParam);
      end;
      if session_Key <> '' then 
      begin
        wsessionkey := session_Key;
        Parametros[ContParam] := PChar(wsessionKey);
        inc(ContParam);
      end;
      Parametros[ContParam] := nil;
      SetAmbiente(Env,wamb);

      try
        ProgramPath := ExecPath(Env.Values['PATH'],wPrograma);
	if (wPrograma <> '') and TemPerm(ProgramPath) then
	begin
          pid :=  fpfork();
          case pid of
             0 : begin // filho
                   if (UserId <> 0) and (GroupID <> 0) then
                   begin
                      fpsetregid(GroupID,GroupID);
                      fpsetreuid(UserId,UserId);
                   end;
                   fpchdir(pchar(whome));
                   fpclose(listenerfd);
                   erro := fpexecve(pchar(ProgramPAth),Parametros,@wamb);
                   if erro <> 0 then
                   begin
                     DoDisplayMessage('Erro ao executar Execlog(login/logoff)');
                     sleep(100); // para o waitpid pegar o filho morrendo
                     halt(1);
                   end 
                   else 
                   begin
                     sleep(100);
                     halt(1);
                   end;
                 end;
            -1 : begin
                   raise ECCP.Create('Erro no fork do processo filho');
                 end;
            else begin // pai
                   status := nil;
                   fpwaitpid(pid,status,0);
                end;
          end; 
        end
        else writelog('sccilogin/logoff : Erro ao executar '+wprograma+' no PATH');
      except
        DoDisplayMessage('Erro ao executar Log de acesso');
      end;
    finally

    end;
{----- Trocado por fork / exec para minimizar logs
    Programa := TMyProc.Create(nil);
    StdErrolist  := tstringlist.create;
    try
        LogStr := expande(LogStr,Env);
        Programa.userid := UserId;
        programa.groupid := GroupId;
        with Programa do
        begin
          Expande(Env);
          Options := [poWaitOnExit,poDefaultErrorMode];
          whome := Env.Values['HOME'];
          if DirectoryExists(whome) then CurrentDirectory := whome
          else CurrentDirectory := '/tmp';
          Environment := Env;
          OnForkEvent := @AfterFork;
          p := pos(' ',LogStr);
          Executable := ExecPath(Env.Values['PATH'],copy(LogStr,1,p-1));
          if Executable <> '' then
          begin
            repeat
              delete(LogStr,1,p);
              p := pos(' ',LogStr);
              if p > 0 then Parameters.Add(copy(LogStr,1,p-1))
              else Parameters.Add(LogStr);
            until p <= 0;
            if trim(ParmExtra) <> '' then
            begin
              splitpair(ParmExtra,wOrigem,wIP);              
              Parameters.Add(wIP);
              Parameters.Add(wOrigem);
            end
            else begin
              Parameters.Add(AThread.Connection.socket.Binding.PeerIP);
              Parameters.Add('S_ORIGEM');
            end;
            if session_Key <> '' then Parameters.Add(session_Key);
            try
              Execute;
              WaitOnExit;
            except
              WriteLog('Erro ao executar LOGIN/LOGOUT/LOGERR, com cógigo de erro: ' + IntToStr(ExitStatus));
            end;
          end
          else begin
            WriteLog('Nao encontrado programa no path ao executar : '+LogStr);
          end;
        end;
        if assigned(Programa.StdErr) and (programa.StdErr.NumBytesAvailable > 0) then
        begin
          StdErrolist.loadfromstream(programa.StdErr);
          StdErroList.SaveToFile('/var/log/launcher_err.log');
        end;
    finally
    finally
        freeandnil(StdErroList);
        freeandnil(programa);
    end; 
----}
    
  end ;
end;

//function TCCPServer.MyDoExecute(AThread: TIdPeerThread): boolean; 
procedure TCCPServer.MyDoExecute(AThread: TIdPeerThread); 
var
  TamLidos      : Integer;
  wCaptcha,
  UsuarioSenhaPrograma,
  Usuario,
  Senha,
  Path,
  Programa,
  NovaSenha     : AnsiString;
  Section       : TSection;
  Env           : TIdThreadSafeStringList;
  LauncherEnv   : TLauncherEnv;
  SenhaEmBranco, SenhaExpirada, SenhaAntiga, SenhaMustChange, UsuarioInativo,
  LoginOK       : boolean;
  User1         : TBaseUser;
  wloginOK	: char;
  salt,
  wip,
  worigem,
  wloginStr,
  wtoken,
  wlogpassstr,worigen,
  wlogoffstr    : ansistring;
  wSenhaAntiga,wnum,
  wOwner,wGroup : integer;
  sessionKeyExpirada,
  Bloqueou,BloqueouCaptcha : boolean;
  wMaxTentativasErroCaptcha,wMaxTentativasErro, wdiasexpira : integer;
  wTimeOut,wfazrodizio,wseguranca,wtemini : boolean;
  wloginerrstr, wrealpath, wservico : string;
  wPodeLiberar : longint;
  contDel : longint;
  ToBeBlocked: sigset_t;
  hdr : ansichar;
  ult_login : tdatetime;
  wtentativas,
  wconterro  : integer;
  wsistema : string;
  wPermiteRedefinirSenha : boolean;
  respostaLogin : string;
  senhaOriginal : AnsiString;
begin
  WriteLog('------------------------ (fpc) '+DateTimeToStr(now) + ' - '+ inttostr(podeliberar));
  if TestTimeBetweenCalls(10) then // 10 miniutos rele o localtime
  begin
    writelog(' ==== Relendo localtime ');
    ReReadlocaltime; // rotina que atualiza o timezone para tratar horario de verao
  end;
  ult_login := 0;
  wtentativas := 0;
  wconterro := 0;
  Section := nil;
  User1 := nil;
  // result := false;
  try
    Salt := '';
    wCaptcha := '';
{
  fpSigEmptySet(ToBeBlocked);
  fpsigaddset(ToBeBlocked, SIGHUP);
  fpsigaddset(ToBeBlocked, SIGINT);
  fpsigaddset(ToBeBlocked, SIGQUIT);
  fpsigaddset(ToBeBlocked, SIGTERM);
  pthread_sigmask(SIG_BLOCK, @ToBeBlocked, nil);
}
    wtimeout := false;
    Contdel := 0;
    while Deletando and (contdel < 5) do
    begin
      sleep(1000); inc(ContDel);
      WriteLog('Deletando');
    end;
    if ContDel >= 5 then Deletando := false;
    inc(PodeLiberar);
    wPodeLiberar := PodeLiberar;
    NovaSenha := '';
    Programa := '';
    Path := '';
    Senha := '';
    Usuario := '';
    SenhaEmBranco := false;
    SenhaExpirada := false;
    SenhaMustChange := false;
    UsuarioInativo := false;
    LoginOK := false;
    Bloqueou := false;
    BloqueouCaptcha := false;
    sessionKeyExpirada := false;
    User1 := nil;
    wOwner := -1;
    wGroup := -1;
    wLoginOK := ' ';
    wtoken := '';
    wOrigen := '';
    LauncherEnv := nil;
    salt := '';
    try
      writelog('  ==== Inicio monitoramento ');
      with AThread.Connection.IOHandler do
      begin
      try
        ReadTimeout := 60000;
        hdr := readchar;
        if (hdr <> SRV_HDR) and (hdr <> SRV_HDR_CRYPT)  then
          raise ECCP_Proto.Create('Erro no protocolo CCP - Header');
          TamLidos := readLongInt(true); // Lê o tamanho dos dados
        if (Tamlidos > 0) and (TamLidos <= TAMBUFOBJETO) then
          UsuarioSenhaPrograma := readString(TamLidos)
        else begin
          UsuarioSenhaPrograma := '';
          raise ECCP.create('Tamanho do buffer muito grande ');
        end;
        ParseUsuarioSenhaPrograma(UsuarioSenhaPrograma,Usuario,Senha,Path,Programa,NovaSenha,wCaptcha,wOrigen);

      // Leitura dos parametros passados para o launcher

      Env := TIdThreadSafeStringList.Create;
      try
        Writelog('  ==== Inicio ' + usuario + ' em '+path +' '+programa);
        LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
        if Assigned(LauncherEnv) then // O ambiene operacioanl é valido ( tem launcherenv.ini )
        begin
  	    Writelog('  ==== Antes do teste da senha');
            //if LauncherEnv.SegurancaWS and (Programa = 'LOGIN') then LauncherEnv.LimpaCache(Usuario);  // login externo nao tem cache para novo login
	    User1 := LauncherEnv.GetUser(Usuario); // Le as informaçoes do usuario do cache ou faz nova leitura
            if LauncherEnv.SegurancaWS and (Programa = 'LOGIN') then User1.Passwd.value := '';  // login externo nao tem cache para novo login
  	    Writelog('  ==== Depois do teste da senha');
            if not assigned ( user1 ) then     // Tambem precisa computar o tempo quando nao tiver usuario
            begin                              // Para evitar saber se é usuario inexistente ou senha errada
              sleep(1000*LauncherEnv.LOGIN_ERR_DELAY);
              raise ECCP.Create ('Usuario ou Senha Incorreto. Por favor tente novamente ');
//              raise ECCP.Create ('Erro na carga do usuario -> '+usuario);
            end;
  	    Writelog('  ==== Leu informação do usuario');
	    Bloqueou := Assigned(User1) and (User1.fUserTentativasE > LauncherEnv.MaxTentativasErro);
	    if Assigned(user1) and (User1.Passwd.value  <> '') then   // Senha nao esta em branco 
	    begin
              Section := LauncherEnv.GetSection(Usuario);
              if assigned(LauncherEnv) and LauncherEnv.TemIni then LauncherEnv.GetEnv(Env,LauncherIni.GlobalEnv)
              else LauncherEnv.GetUser(Usuario).GetEnv(Env,LauncherIni.GlobalEnv);
              // Le o ambiente do launcherenv.ini
              if BloqueouCaptcha then writelog ( '  ==== BloqueouCaptcha ATIVO ');
	            BloqueouCaptcha := Launcherenv.TemCaptcha and (Section.ContErroLogin > LauncherEnv.MaxTentativasErroCaptcha);
              if (Section.Captcha.Value <> '') and BloqueouCaptcha then     // Se veio o captch certo Desbloqueia para
                if wCaptcha = Section.Captcha.Value then
                begin
                  BloqueouCaptcha := false; // tentar o login novamente
		              writelog ( ' Bloqueio de captha liberado');
                  Section.InBloqueadoCaptcha := false;
                end;
              Writelog('  ==== Com Senha no BD/ em cache');
              if Bloqueou {or BloqueouCaptcha }then
                 LoginOk := false
              else begin
//                 if LauncherEnv.SegurancaWS and ((Programa = 'PASSWD') or (Programa = 'EMAILPWD')) then
                 if (LauncherEnv.SegurancaWS and (Programa = 'PASSWD')) or (Programa = 'EMAILPWD') then
                 begin
                    LoginOK := true;
                    wtoken := User1.Passwd.value  ;
                 end         
                 else LoginOk :=  Assigned(user1) and User1.SenhaOK(Senha) and User1.UserActive;
                 // Valida a senha - caso banco de dados
                 if (LauncherEnv.ACESSOSSIMULTANEOS <= 1) and not LoginOK then
                   sessionKeyExpirada := LauncherEnv.VerificaSessionKeyExpirada(Usuario, Senha)
                 else if (LauncherEnv.ACESSOSSIMULTANEOS > 1) and LauncherEnv.VerificaSectionKeyBD and not LoginOK and LauncherEnv.SegurancaWS then
                 begin
                 respostaLogin := LauncherEnv.RevalidaWSlogin(Env,AThread,wOwner,wGroup,usuario,senha,ult_login); 
                 if respostaLogin = 'T' then
                 begin
                    if assigned(User1) then
                    begin
                      User1.Passwd.value  := senha;
                      User1.UltimoUso.value  := ult_login;
                      Section := LauncherEnv.GetSection(usuario);
                      LoginOk := true;
                    end
                    else LoginOk := false;
                  end
                  else begin
                    LoginOk := false;
                    if respostaLogin = 'E' then
                      sessionKeyExpirada := true;
            //			  raise ECCP.Create('Erro ao recarregar a chave');
                  end;
                  writelog ( '  ==== Revalidando Section Key ====');
                end;

    //             if not LoginOK and assigned(LauncherEnv) and assigned(user1) then // Se não conseguiu refresh cash pode ester desatualizado
    //               LauncherEnv.LimpaCache(Usuario);
//                        LauncherEnvList.Reset := true;
	      end ;
	      if LoginOK then
              begin
                writelog('  ==== LoginOK');		      
                wGroup := LauncherEnv.Group;
                wOwner := LauncherEnv.Owner;
              end;
	    end
	    else begin
              Writelog('  ==== Sem Senha no Banco de dados ( login externo )'); 
	      if LauncherEnv.TemIni then LauncherEnv.GetEnv(Env,LauncherIni.GlobalEnv);
              if LauncherEnv.SegurancaWS then
              begin
                wGroup := LauncherEnv.Group;
                wOwner := LauncherEnv.Owner;
                if (Programa = 'LOGIN') then
                begin
                  Section := LauncherEnv.GetSection(usuario);
	          BloqueouCaptcha := LauncherEnv.TemCaptcha and (Section.ContErroLogin > LauncherEnv.MaxTentativasErroCaptcha);
                  if (Section.Captcha.Value <> '') and BloqueouCaptcha then     // Se veio o captch certo Desbloqueia para
		  begin
                    if wCaptcha = Section.Captcha.Value then
	            begin
		      writelog ( '  ==== Bloqueio de captha liberado');
	              BloqueouCaptcha := false; // tentar o login novamente
	              Section.InBloqueadoCaptcha := false;
	            end
 		  end; 
                  if trim(NovaSenha) <> '' then
                  begin
                    splitpair(NovaSenha,wOrigem,wIP);
                    Section.IPAcesso.Value := wIP;
                  end;
		  if BloqueouCaptcha or Bloqueou then wLoginOK := 'F'
		  else begin
		        SenhaOriginal := senha;
		        wLoginOK := LauncherEnv.LeSegurancaWS(Env,AThread,wOwner,wGroup,usuario,senha,LauncherEnv.ACESSOSSIMULTANEOS,wIP);
        		if wLoginOK='F' then begin
		          if Assigned(user1) and not Bloqueou then begin
		            inc(User1.fUserTentativasE);
		            sleep(1000*LauncherEnv.LOGIN_ERR_DELAY);
		            writelog('wseguranca ' + booltostr(Launcherenv.SegurancaWS));
		            // LauncherEnv.GravaSenhaErrada(usuario,User1.fUsertentativasE);
		            if  (User1.fUserTentativasE > LauncherEnv.MaxTentativasErro) and 
		                (LauncherEnv.MaxTentativasErro > 0) and (LauncherEnv.MaxTentativasErro <> 9999) then
		            begin
		              Bloqueou := true;
		              User1.DtValSenha.value := now-1;
		              LauncherEnv.GravaExpiracao(usuario);
		            end;
		            Env.Insert(0,'USER='+ Usuario);
		            if Env.Values['HOME'] = '' then
		              Env.Add('HOME='+LauncherEnv.RealPath.value);
		            ExecLog(Athread,Env,LauncherEnv.Owner,LauncherEnv.Group,LauncherEnv.LoginErrStr.value,NovaSenha);
		          end;
		          if not Bloqueou then begin
		            if (Trim(Senha) > '') and (Senha <> SenhaOriginal) then // a senha é setada pelo serviço de autenticação com erros retornados pelos programas loginxxx
		              raise ELOGINEXTERRO.Create('Erro de autenticação: '+Senha)
		            else  
		              raise ELOGINEXTERRO.Create('Erro de autenticação');
		          end;
		        end;
		  end;    
                  LoginOK := (wLoginOK = 'T') or ( wLoginOK = 'E') or 
                             (wLoginOK = 'C') or  
                             (wLoginOk = 'M') or (wLoginOk = 'B');
                  SenhaExpirada := wLoginOK = 'E';
                  SenhaMustChange := wLoginOK = 'M';
                  SenhaAntiga:= wLoginOK = 'C';
                  SenhaEmBranco := wLoginOK = 'B';
                  UsuarioInativo := wLoginOK = 'E';
                  if SenhaAntiga then 
                  begin
                    wSenhaAntiga := ord(senha[1])-30;
                    delete(senha,1,1);
                  end;  
                  User1.Passwd.value  := Senha;
                  wtoken := User1.Passwd.value ;
                end 
                else if (Programa = 'EMAILPWD') and LauncherEnv.SegurancaWS then
                begin
                    LoginOK := true;
                    SenhaExpirada := false;
                    SenhaMustChange := false;
                    SenhaAntiga:= false;
                    SenhaEmBranco := false ;
                    UsuarioInativo := false;
                    writelog('  ==== Redefinicao de Senha ')
                end
                else begin
                  if LauncherEnv.VerificaSectionKeyBD and LauncherEnv.SegurancaWS then
   		  begin
		      	respostaLogin := LauncherEnv.RevalidaWSlogin(Env,AThread,wOwner,wGroup,usuario,senha,ult_login);
			if respostaLogin = 'T' then
      			begin
			  if assigned(user1) then
        		  begin
                            User1.Passwd.value  := senha;
                            User1.UltimoUso.value  := ult_login;
                            Section := LauncherEnv.GetSection(usuario);
  			    LoginOk := true;
        	  	  end
        	        else LoginOk := false; 
                  end
      else begin
        LoginOk := false;
        if respostaLogin = 'E' then begin
          sessionKeyExpirada := true;
        end;
//			  raise ECCP.Create('Erro ao recarregar a chave');
      end;
      writelog ( '  ==== Revalidando Section Key ====');
    end
      else LoginOk := false;
                end
              end
              else begin
                if Assigned(user1) then SenhaEmBranco := true;
                LoginOK := false;
	        wGroup := LauncherEnv.Group;
	        wOwner := LauncherEnv.Owner;
              end;
            end;
            wLoginStr:= LauncherEnv.Loginstr.value;
            wLogOffStr := LauncherEnv.LogOffStr.value;
            wLogPassStr := LauncherEnv.LogPassStr.value;
            wdiasexpira := LauncherEnv.DiasExpira;
            wTemIni := LauncherEnv.TemIni;
            wSeguranca := LauncherEnv.SegurancaWS;
            wServico := LauncherEnv.Servico.value;
            wRealPath := LauncherEnv.RealPath.value;
            wloginerrstr := LauncherEnv.LoginErrStr.value ;
            wMaxTentativasErro := LauncherEnv.MaxTentativasErro;
            wMaxTentativasErroCaptcha := LauncherEnv.MaxTentativasErroCaptcha;
            wFazRodizio := LauncherEnv.FazRodizio;
            wsistema := Launcherenv.Sistema.value;
            wPermiteRedefinirSenha := Launcherenv.PermiteRedefinirSenha.value;
            WriteLog('  ==== Depois do Controle de senha ');
	end
	else begin
          WriteLog(' ==== Erro de atribuição do Usuário launcherenv - vazio');
          raise ECCP_Proto.Create('Nao foi possivel acessar a configuração do usuário');
        end;
//-----------------
        if LoginOK  then    // Login valido , vai tratar condiçoes como expirada, captcha etc
//-----------------
        begin
          Writelog('  ==== Validado ok');
          if assigned(User1) and (Programa = 'LOGIN') then 
             User1.UltimoUso.value  := now; // Nao da timeout se for feito novo login
          if assigned(User1) then wTimeOut := User1.SectionTimedOut;
          if wTimeOut then raise ECCP.Create ('Tempo de seção excedido')
          else if assigned(User1) then 
                 User1.UltimoUso.value  := now;
          if not wSeguranca then 
          begin
            SenhaExpirada := not User1.TestPasswdDate or (wLoginOK = 'X');
            SenhaAntiga := not User1.TestPasswdChange or (wLoginOK = 'C');
            SenhaMustChange := User1.MustChange or not User1.TestMaxPass or (wLoginOK = 'M');
            UsuarioInativo := not User1.UserActive or (User1.DtValSenha.value  < now) or (wLoginOK = 'E');
            if SenhaAntiga and not SenhaMustChange and not SenhaExpirada  then
              wSenhaAntiga := trunc( (User1.UltAltSenha.value +User1.MaxSenha+1) - now )
            else begin
              wSenhaAntiga := -999;
              SenhaAntiga := false;
            end;
          end
          else begin
//            UsuarioInativo := false;   // Nao sei porque esta assim Sol 60507 - intermedium corrigiu
//            SenhaExpirada := false;      
          end;
          Writelog('  ==== Tudo Pronto para rodar ');
          if UsuarioInativo then
            raise ECCP.Create('Usuário inativo, acesso não permitido. Consulte o Administrador !')
          else
            if (not SenhaExpirada and not SenhaMustChange) or (Programa = 'PASSWD') or (SenhaAntiga) then
            begin
              if (assigned(user1)) and user1.LimiteDiasSenha(wdiasexpira) or (Programa = 'PASSWD') then
              begin
                if wSeguranca and (Programa = 'LOGOFF') then
                  if (wServico <> '') and (copy(wlogoffstr,1,13) = 'logoutbanese') then 
                    wLogOffStr := wLogOffstr + ' ' + wServico + ' ' +Senha;
                if not wSeguranca and (assigned(user1)) and (User1.fUserTentativasE > 0) and (LauncherEnv.MaxTentativasErro > 0) and (LauncherEnv.MaxTentativasErro <> 9999) then 
                    LauncherEnv.GravaSenhaErrada(usuario,0);
                User1.fUserTentativasE := 0;
                if assigned(Section) then
                begin
                   if wSeguranca then Section.SectionKey.Value := Senha;
                   Section.LastLogin.Value := now;
                   Section.ContErroLogin := 0;
                   if trim(NovaSenha) <> '' then
                   begin
                     splitpair(NovaSenha,wOrigem,wIP);
                     Section.IPAcesso.Value := wIP;
                   end
                   else Section.IPAcesso.Value := AThread.Connection.socket.Binding.PeerIP;
                end;

                if not wTemIni then {Configuração está vazia pega profile}
                  ProgramExecute(Usuario,Senha,NovaSenha,Path,Programa,Env,
		                 wLoginStr,wLogOffStr,wLogPassStr,AThread,
		                 false{WSLogin},
		                 0{UserID},
                                 0{GroupId},
		                 false{SenhaAntiga},
		                 -999{wSenhaAntiga},
		                 false{NovoModoOp},
		                 ''{wtoken},
		                 false{Criptografa},
		                 ''{Salt},
		                 ''{wsistema},
		                 false{wPermiteRedefinirSenha},
		                 wOrigen)
                else begin { Não tem launcherenv.ini }
                  Env.Insert(0,'USER='+ Usuario);
                  if (LauncherEnv.FSeg_sistema.value = 'loginsicoob') and (Env.Values['SKEY'] = '') then
                    Env.add('SKEY='+Senha);
                  if Env.Values['HOME'] = '' then Env.Add('HOME='+wRealPath);
                  if wSeguranca then Env.Add('SEG_SISTEMA=WEBSERVICE') else Env.Add('SEG_SISTEMA=LAUNCHER');
                  if wFazRodizio then Env.Add('FAZRODIZIO=SIM');
                  Writelog('  ==== Chamada da ProgramExecute ');
                  ProgramExecute(Usuario,Senha,NovaSenha,Path,Programa,Env,
		                 wLoginStr,wLogOffStr,wLogPassStr,
                                 AThread,wSeguranca,
                                 wOwner,wGroup,
				 SenhaAntiga, wSenhaAntiga,true,wtoken,hdr = SRV_HDR_CRYPT,salt,
                                 wsistema,wPermiteRedefinirSenha,wOrigen);
                  Writelog('  ==== Depois da ProgramExecute ');
                end;
  	      end
              else begin
	        SenhaExpirada := true;
	        raise ECCP.Create('Limite global de validade da senha atingido');
	      end;
            end
            else raise ECCP.Create('Usuario / Senha Incorreta ou Senha Expirada');
        end
        else begin
             if not wTemIni and not DirectoryExists(Path) then
               raise ECCP.Create('Diretorio '+Path+' nao encontrado')
             else begin
               if assigned (User1) then wtentativas :=  User1.fUserTentativasE else wtentativas := -1;
               if assigned(section) then wconterro := section.ContErroLogin else wconterro := -1;
               writelog('  ==== Senha com erro - Erro '+inttostr( wtentativas) + ' / captcha erro '
	                 +   inttostr(wconterro) + ' / max captcha '
	                 +   inttostr(LauncherEnv.MaxTentativasErroCaptcha) + ' / maxerrogeral '
                         +   inttostr(LauncherEnv.MaxTentativasErro ));

               if Assigned(user1) and assigned(section) and not Bloqueou and not BloqueouCaptcha then begin
                 inc(User1.fUserTentativasE);
		 Section.ContErroLogin := succ(Section.ContErroLogin);
                 sleep(1000*LauncherEnv.LOGIN_ERR_DELAY);
                 if Launcherenv.TemCaptcha and assigned(User1) and  (Section.ContErroLogin > wMaxTentativasErroCaptcha) then
	         begin
                   BloqueouCaptcha := true;
		   Writelog('  ==== Bloqueou Captcha ');
		 end;
                 if assigned(User1) and  (User1.fUserTentativasE > wMaxTentativasErro) then
                 begin
                   Bloqueou := true;
                   User1.DtValSenha.value  := now-1;
//	           if assigned(Launcherenv) and not wseguranca then 
//		        LauncherEnv.GravaExpiracao(usuario);
// Como a quantidade de erros esta sendo gravada nÃo precisa mais expirar o usuario.
//
		   Writelog('  ==== Bloqueou Usuario ');
                 end;
                 if (LauncherEnv.MaxTentativasErro > 0) and (LauncherEnv.MaxTentativasErro <> 9999)  then 
                   if not wseguranca then 
                     LauncherEnv.GravaSenhaErrada(usuario,User1.fUserTentativasE); 
                 if assigned(LauncherEnv) then
                 begin
                   if  LauncherEnv.TemIni then LauncherEnv.GetEnv(Env,LauncherIni.GlobalEnv);
                   if Env.Values['USER'] = '' then
                     Env.Add('USER='+ Usuario);
                   if Env.Values['HOME'] = '' then
                     Env.Add('HOME='+wRealPath);
                   ExecLog(Athread,Env,LauncherEnv.Owner,LauncherEnv.Group,LauncherEnv.LoginErrStr.value,NovaSenha);
                 end;
               end;
  	       raise ECCP.Create('Usuario ou Senha Incorreto. Por favor tente novamente');
	     end;
        end;
      finally
        freeAndNil(Env);
      end;
    except
      on E: EIDException do Writelog('On EIDException : ' + E.message);
      on E2: ECCP_Proto do
             try
               Writelog('On ECCP_PROTO  : ' + E2.message);
               writeres(AThread,SRV_NOK);
	     except
             end;
      on E3 : ECCP do
      begin
        WriteLog('On E  = '+E3.Message);
        if BloqueouCaptcha and (Programa = 'LOGIN') then
        begin
          try
            if Assigned(LauncherEnv) and Assigned(User1) and Assigned(Section) and LauncherEnv.TemCaptcha then 
            begin
              Section.Captcha.Value := GeraCaptcha;
              Section.InBloqueadoCaptcha := true;
              writeres_st(AThread,char(SRV_NOK_CAPTCHA)+EncodeBase64(geraCaptcha7Jpg(Section.Captcha.Value)));
            end;
          except
          end;
        end
        else if Bloqueou then try writeres(AThread,SRV_NOK_BLOCK) except end
        else if wTimeOut then try writeres(AThread,SRV_EXPIRED) except end
        else if UsuarioInativo then try writeres(AThread,SRV_NOK_INACTIVE) except end
        else if SenhaExpirada then try writeres(AThread,SRV_NOK_EXPIRED) except end
        else if SenhaEmBranco then
             begin
               if wSeguranca then try writeres(AThread,SRV_WS_NOPASS) except end
               else  try writeres(AThread,SRV_NOK_NOPASS) except end
             end
        else if SenhaMustChange then try writeres(AThread,SRV_NOK_MUSTCHANGE) except end
        else if sessionKeyExpirada then try 
          writelog(' ==== SessionKey Expirada por Acessos Simultaneos');
          writeres(AThread, SRV_NOK_QTACESSO);
        except end
        else if wSeguranca then
             begin
                if Programa = 'LOGIN' then try writeres_st(AThread,char(SRV_WS_NOK)+e3.message{+virou wtoken era Senha}) except end
                else try  writeres(AThread, SRV_WS_NOPASS); except end
             end
        else begin writelog('else'); try writeres(AThread,SRV_NOK) except end; end;
      end;
      on E4 : ELOGINEXTERRO do begin
        try 
          writeres_st(AThread,char(SRV_WS_NOK)+e4.message);
        except
        end;  
      end;
      On E5 : Exception do
	      begin
		       writelog('On Exception '+E5.Message);
        end;
      else writelog('On Else_Exception');
    end;
    if (wPodeLiberar = PodeLiberar) and assigned(LauncherEnvList) and LauncherEnvList.Reset then
    begin
      WriteLog('  ==== Relendo configuraçao');
      Deletando := true;
      try
        if assigned(LauncherIni) then
          LauncherIni.Refresh;
        if assigned(LauncherEnvList) and assigned(Server) then
          LauncherEnvList.Clear;
      finally
        if assigned(LauncherEnvList) then LauncherEnvList.Reset := false;
        Deletando := false;
      end;
      WriteLog('  ==== Depois de  Reler configuraçao');
    end;
    end; {with}
    except 
      on E2: EIDException do WriteLog('On EIDException : IdException reading client data: '+ E2.Message);
      on E: Exception do WriteLog('On E : Exception reading client data: '+ E.Message);
    end;
  finally
    try
      AThread.Connection.Disconnect;
    except
      on E:Exception do
      begin
        Writelog('erro na disconnect'+e.message)
      end;
    end;
  end; 
  writelog ( '  ==== Fim da DoMyExecute' );
end;

//////////////////////////////////////////////////////////////////////////////////////////////
{$ELSE} // Rotina Execlog Versao Kylix
//////////////////////////////////////////////////////////////////////////////////////////////


procedure TCCPServer.ExecLog(Athread :TidPeerThread;Env:TstringList;UserId,GroupID : integer;LogStr,ParmExtra:string;Session_Key : string = '');
var 
  wprograma,p1,p2,p3,p4,p5,
  whome : ansistring;
{$IFDEF LINUX}  
  error : integer;
  pid : integer;
  status : PInteger;
  wamb : TPtrStr;
{$ELSE}
  StartUpInfo        : TStartUpInfo;
  ProcessInformation : TProcessInformation;
  BufSize: Integer;         // env block size
  Buffer: Pointer;          // env block 
{$ENDIF}  
begin
{$IFDEF MSWINDOWS}
  fillchar(StartUpInfo,sizeof(StartUpInfo),0);
  StartUpInfo.cb := SizeOf(TStartupInfo);
  fillchar(ProcessInformation,sizeof(ProcessInformation),0);
{$ENDIF}  
  if trim(LogStr) <> '' then 
  begin
    whome := expande(Env.Values['HOME'],Env);
    if whome <> '' then
    try
      chdir(whome);
    except
      chdir('/tmp');
    end;
    LogStr := expande(LogStr,Env);
    wPrograma := trim(copy(LogStr,1,pos(' ',LogStr)));
    LogStr := trim(copy(LogStr,pos(' ',LogStr)+1,length(LogStr)));
    p1 := trim(copy(LogStr,1,pos(' ',LogStr)));
    LogStr := trim(copy(LogStr,pos(' ',LogStr)+1,length(LogStr)));
    p2 := trim(copy(LogStr,1,pos(' ',LogStr)));
    LogStr := trim(copy(LogStr,pos(' ',LogStr)+1,length(LogStr)));
    if pos(' ',LogStr) = 0 then
    begin
      p3 := trim(LogStr);
    end
    else begin
      p3 := trim(copy(LogStr,1,pos(' ',LogStr)));
      LogStr := trim(copy(LogStr,pos(' ',LogStr)+1,length(LogStr)));
      p4 := trim(copy(LogStr,1,pos(' ',LogStr)));
      LogStr := trim(copy(LogStr,pos(' ',LogStr)+1,length(LogStr)));
      p5 := trim(LogStr);
   end;
{$IFDEF LINUX}
    try
      pid :=  fork();
      case pid of
         0 : begin // filho
               if (UserId <> 0) and (GroupID <> 0) then
               begin
                  setregid(GroupID,GroupID);
                  setreuid(UserId,UserId);
               end;
               SetAmbiente(Env,wamb);
               if (p4 <> '' ) and (p5 <> '') then 
                 if ParmExtra <> ''  then
                  error := execle(pchar(ExecPath(Env.Values['PATH'],wPrograma)),
                    pchar(wPrograma),p1,p2,p3,p4,p5,
                    AThread.Connection.socket.Binding.PeerIP,ParmExtra,nil,wamb)
                 else
                  error := execle(pchar(ExecPath(Env.Values['PATH'],wPrograma)),
                    pchar(wPrograma),p1,p2,p3,p4,p5,
                    AThread.Connection.socket.Binding.PeerIP,nil,wamb)
               else 
                 if ParmExtra <> ''  then
                  error := execle(pchar(ExecPath(Env.Values['PATH'],wPrograma)),
                    pchar(wPrograma),p1,p2,p3,
                    AThread.Connection.socket.Binding.PeerIP,parmextra,nil,wamb)
                 else
                  error := execle(pchar(ExecPath(Env.Values['PATH'],wPrograma)),
                    pchar(wPrograma),p1,p2,p3,
                    AThread.Connection.socket.Binding.PeerIP,nil,wamb);
               if error <> 0 then
               begin
                  DoDisplayMessage('Erro ao executar '+wPrograma);
                  halt(1);
               end;
             end;
        -1 : begin
               raise ECCP.Create('Erro no fork do processo filho');
             end;
        else begin // pai
	       status := nil;
               waitpid(pid,status,0);
	     end;
      end;
    except
      DoDisplayMessage('Erro ao executar Log de acesso');
    end;
{$ELSE}
    BufSize := CreateEnvBlock(Env, True, nil, 0);
    GetMem(  Buffer , BufSize+1024);
    CreateEnvBlock(Env, True, Buffer, BufSize);
    SetErrorMode($FFFF);
    if not CreateProcess({lpApplicationName} NIL,
                             {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],wPrograma)+' '+p1+' '+p2+' '+p3+' '+AThread.Connection.Binding.PeerIP),
                             {lpProcessAttributes} NIL,
                             {lpThreadAttributes} NIL,
                             {bInheritHandles} True,
                             {dwCreationFlags} 0,
                             {lpEnvironment} Buffer,
                             {lpCurrentDirectory} NIL,
                             {lpStartupInfo} StartUpInfo,
                             {lpProcessInformation} ProcessInformation) then
    begin
        DoDisplayMessage('Erro ao executar  '+LogStr + ' as '+DateTimetoStr(now));
    end else
    begin
        WaitForSingleObject(ProcessInformation.hProcess,INFINITE);
		CloseHandle( ProcessInformation.hProcess );
		CloseHandle( ProcessInformation.hThread );	
        FreeMem(Buffer,BufSize+1024);
    end;	
{$ENDIF}   
  end;
end;

function TCCPServer.ProgramExecute(Usuario      : AnsiString;
                               var Senha	: AnsiString;
                                   ParmExtra,
                                   Path,
				   Programa     : AnsiString;
                                   Env          : TStringList;
                                   LoginStr,
                                   LogOffStr,
			 	   LogPassStr    : string;
                                   AThread      : TidPeerThread;
                                   WSLogin      : boolean = false;
                                   UserID       : Integer=0;
                                   GroupId      : Integer=0;
				   SenhaAntiga  : boolean=false;
				   wSenhaAntiga : Integer=-999;
                                   NovoModoOp   : boolean = false; 
                                   wtoken : string = '';
                                   Criptografa : boolean = false;
                                   Salt : string = ''):boolean;
var
{$IFDEF LINUX}
  PID : longint;
  status : PInteger;
  wamb : TPtrStr;
{$IFDEF FPC}
  w1,w2 : string;
  Parametros : PPchar;
{$ENDIF}
{$ENDIF}
  error : integer;
  whome : string;
{$IFDEF MSWINDOWS}
  StartUpInfo        : TStartUpInfo;
  ProcessInformation : TProcessInformation;
  BufSize: Integer;         // env block size
  Buffer: Pointer;          // env block 
{$ENDIF}
  LauncherEnv : TLauncherEnv;
  ControleAcessoStr : string;
  msg : ansistring;
begin
{$IFDEF MSWINDOWS}
  fillchar(StartUpInfo,sizeof(StartUpInfo),0);
  StartUpInfo.cb := SizeOf(TStartupInfo);
  fillchar(ProcessInformation,sizeof(ProcessInformation),0);
{$ENDIF}  
  result := true;
  with AThread.Connection do
  begin
    if Programa  = 'KILL' then
    begin
      DoDisplayMessage('Matando processo : '+ParmExtra);
{$IFDEF LINUX}
      pid :=  fork();
      case pid of
	0 : begin // filho
              if (UserId <> 0) and (GroupID <> 0) then
              begin
{$IFDEF FPC}
                fpsetregid(GroupID,GroupID);
                fpsetreuid(UserId,UserId);
{$ELSE}
                setregid(GroupID,GroupID);
                setreuid(UserId,UserId);
{$ENDIF}
              end;
              try
                if (ParmExtra <> '') and (strtoint(ParmExtra) <> getpid()) and 
                   (strtoint(ParmExtra)<>getppid()) and (strtoint(ParmExtra)>200) then 
{$IFDEF FPC}
                fpkill(strtoint(ParmExtra),15);
{$ELSE}
                kill(strtoint(ParmExtra),15);
{$ENDIF}

                writeres(AThread,SRV_OK);
              except 
                writeres(AThread,SRV_NOK);
              end;
{$IFNDEF FPC}
              Disconnect;
{$ELSE}
              AThread.Connection.IOHandler.Close;
{$ENDIF}
              halt(0);
             end;
        -1 : begin
               raise ECCP.Create('Erro no fork do processo filho');
	       result := false;
             end;
         else begin // pai
               status := nil;
               waitpid(pid,status,0);
         end;
       end;
{$ELSE}
      writeres(AThread,SRV_OK);
{$ENDIF}
    end
    else if Programa  = 'HUP' then
    begin
      DoDisplayMessage('Relendo a configuração');  
      writeres(AThread,SRV_OK);
      if assigned(LauncherIni) then
        LauncherIni.Refresh;
      LauncherEnvList.Clear;
{$IFNDEF FPC}
      Disconnect;
{$ELSE}
      AThread.Connection.IOHandler.Close;
{$ENDIF}

    end
    else if Programa  = 'PASSWD' then
    begin
        if LogPassStr <> '' then
          ExecLog(Athread,Env,UserId,GroupID,LogPassStr,ParmExtra);
        DoDisplayMessage('PASSWD');
        LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
        if not LauncherEnv.GetUser(usuario).SenhaUsada(ParmExtra) then
        begin
          msg := '';
          try
            ValidaSenha(ParmExtra,LauncherEnv.MinCaracPass, LauncherEnv.MinAlfaPass, 
                        LauncherEnv.MinAlfaMaisPass,LauncherEnv.MinNumPass,
                        LauncherEnv.MaxRepPass,LauncherEnv.MaxSeqPass,LauncherEnv.CaracPass,
                        LauncherEnv.CarMinEspPass);
          except
            on e : exception do
              msg := e.message;
          end;
          if Msg = '' then begin
            if WSLogin then 
            begin
              if LauncherEnv.TrocaSenhaWS(Env,AThread,UserID,GroupID,usuario,Senha,ParmExtra,wtoken) = 'T' then
                writeres(AThread,SRV_OK)
              else begin
                writeres(AThread,SRV_NOK);
                raise ECCP.Create('Não foi possivel alterar a senha');
              end;
            end
            else begin
              if AlteraSenha(Usuario,ParmExtra) then begin
                LauncherEnv.GravaSenhaBD(usuario,ParmExtra);
                writeres(AThread,SRV_OK);
                DoDisplayMessage('Relendo a configuração');
                if assigned(LauncherIni) then
                  LauncherIni.Refresh;
                LauncherEnvList.Clear;
              end
              else begin
                writeres(AThread,SRV_NOK);
                raise ECCP.Create('Não foi possivel alterar a senha');
              end;
            end;
	  end
	  else begin
            writeres(AThread,SRV_NOK_MSG);
            writeres_st(AThread,msg);
	    raise ECCP.Create(Msg);
          end;
        end
        else begin
          writeres(AThread,SRV_NOK);
          raise ECCP.Create('Esta senha já foi usada anteriormente');
        end;
{$IFNDEF FPC}
        Disconnect;
{$ELSE}
        AThread.Connection.IOHandler.Close;
{$ENDIF}

    end
    else if Programa = 'PING' then
    begin
      DoDisplayMessage(Programa+' - por : '+usuario);
      writeres(AThread,SRV_PING_REPLY or CalcIdle shl 16);
{$IFNDEF FPC}
      Disconnect;
{$ELSE}
      AThread.Connection.IOHandler.Close;
{$ENDIF}

    end
    else if Programa = 'AMB' then
    begin
      DoDisplayMessage(Programa+' - por : '+usuario);
      writeres_st(AThread,Env.CommaText);
{$IFNDEF FPC}
      Disconnect;
{$ELSE}
      AThread.Connection.IOHandler.Close;
{$ENDIF}
    end
    else if Programa = 'TYPE' then
    begin
      DoDisplayMessage(Programa+' - por : '+usuario);
{$IFDEF MSWINDOWS}
      ParmExtra := ParmExtra + '.exe';
{$ENDIF}
      writeres_St(AThread,FileSearch(ParmExtra,Env.Values['PATH']));
{$IFNDEF FPC}
      Disconnect;
{$ELSE}
      AThread.Connection.IOHandler.Close;
{$ENDIF}

    end
    else if Programa = 'LOGOFF' then
    begin
      DoDisplayMessage(Programa+' - por : '+usuario);
      if WSLogin then Senha := '';
      if LogOffStr <> '' then
        ExecLog(Athread,Env,UserId,GroupID,LogOffStr,ParmExtra);
{$IFNDEF FPC}
      Disconnect;
{$ELSE}
      AThread.Connection.IOHandler.Close;
{$ENDIF}

    end
    else if Programa = 'LOGIN' then
    begin
        DoDisplayMessage('LOGIN : '+Env.Values['USER']+' as '+DateTimetoStr(now));
        ControleAcessoStr := Env.Values['CONTROLEACESSO'];
        if (ControleAcessoStr = '') and (LogInStr <> '') then
          ExecLog(Athread,Env,UserId,GroupID,LogInStr,ParmExtra);
        if SenhaAntiga  then
begin
          writeres(AThread,SRV_NOK_CHANGE or wSenhaAntiga shl 16)
end
        else begin
          if ControleAcessoStr <> '' then begin
{$IFDEF MSWINDOWS}
            ControleAcessoStr := ControleAcessoStr + '.exe';
{$ENDIF}

            ControleAcessoStr := FileSearch(ControleAcessoStr,Env.Values['PATH']) + ' '+
                                 Env.Values['USER'] + ' '+
                                 quotedStr(Env.Values['SCCIDIRATV'])+' '+
{$IFDEF LINUX}
				socket.Binding.PeerIP;
{$ELSE}
				Binding.PeerIP;
{$ENDIF}				
            DoDisplayMessage('Validando acesso ao sistema('+controleacessostr+')');
{$IFDEF LINUX}
            SetAmbiente(Env);
{$IFDEF FPC}
            punix.shell(ControleAcessoStr);
{$ELSE}
            Error := libc.system(pchar(ControleAcessoStr));
{$ENDIF}
{$ELSE}
            BufSize := CreateEnvBlock(Env, True, nil, 0);
            GetMem(  Buffer , BufSize+1024);
            CreateEnvBlock(Env, True, Buffer, BufSize);
            SetErrorMode($FFFF);
            error := 0;
            if not CreateProcess({lpApplicationName} NIL,
                             {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],ControleAcessoStr)),
                             {lpProcessAttributes} NIL,
                             {lpThreadAttributes} NIL,
                             {bInheritHandles} True,
                             {dwCreationFlags} 0,
                             {lpEnvironment} Buffer,
                             {lpCurrentDirectory} NIL,
                             {lpStartupInfo} StartUpInfo,
                             {lpProcessInformation} ProcessInformation) then
			begin
              WaitForSingleObject(ProcessInformation.hProcess,INFINITE);
	      CloseHandle( ProcessInformation.hProcess );
	      CloseHandle( ProcessInformation.hThread );	
              StrDispose(Buffer);
	    end
            else
              error := 1;
{$ENDIF}
            if error <> 0 then begin
              DoDisplayMessage('Acesso ao sistema não permitido');
              writeres(AThread,SRV_NOK_ACESSO);
            end
            else
              if WSLogin then writeres_st(AThread,char(SRV_WS_OK)+Senha)
              else writeres(AThread,SRV_OK);
              
          end
          else
            if WSLogin then writeres_st(AThread,char(SRV_WS_OK)+Senha)
            else writeres(AThread,SRV_OK);
        end;

{$IFNDEF FPC}
        Disconnect;
{$ELSE}
        AThread.Connection.IOHandler.Close;
{$ENDIF}
    end
    else begin
        if not NovoModoOp then
        begin
          Path := IncludeTrailingPathDelimiter(Path);
          Programa := Path + Programa;
        end;
{$IFDEF LINUX}
        pid :=  fork();
        case pid of
          0 : begin // filho
                 writeres(AThread,getpid());
                 SetAmbiente(Env,wamb);
                 if (UserId <> 0) and (GroupID <> 0) then
                 begin
{$IFDEF FPC}
                   fpsetregid(GroupID,GroupID);
                   fpsetreuid(UserId,UserId);
{$ELSE}
                   setregid(GroupID,GroupID);
                   setreuid(UserId,UserId);
{$ENDIF}
                 end;
                 whome := expande(Env.Values['HOME'],Env);
                 if whome <> '' then
                 begin
                   try
                     chdir(whome);
                   except
                     MsgErro( AThread, 'Diretório de trabalho do usuário no servidor não existe ('+whome+')');
                     DoDisplayMessage('Diretório de trabalho do usuário no servidor não existe ('+whome+')');
                     raise ; 
                   end;
                 end;
                 WriteLog('Exec:'+Programa+' p/ '+usuario+'-'
                                         +whome+' '+inttostr(getpid()));
                 __close(1);            // Redireciona o StdOut p. /dev/null
{$IFDEF FPC}
                 fpopen('/dev/null',O_RDWR);
{$ELSE}
                 Libc.open('/dev/null',O_RDWR);
{$ENDIF}
                 if NovoModoOp then
{$IFDEF FPC}
                 begin
                   GetMem(Parametros,8*sizeof(PChar));
                   Parametros[0] :=  PChar(programa);
                   w1 := inttostr(socket.Binding.Handle);
                   Parametros[1] :=  PChar(w1);
                   Parametros[2] :=  PChar(socket.Binding.PeerIP);
                   Parametros[3] :=  nil;
                   error := execve((ExecPath(Env.Values['PATH'],Programa)),Parametros,@wamb);
                end
{$ELSE}
                   error := execle(PChar(ExecPath(Env.Values['PATH'],Programa)),PChar(Programa),
                           inttostr(socket.Binding.Handle),
                           socket.Binding.PeerIP,nil,wamb)
{$ENDIF}
                 else
{$IFDEF FPC}
                 begin
                   GetMem(Parametros,8*sizeof(PChar));
                   Parametros[0] :=  PChar(programa);
                   w1 := inttostr(socket.Binding.Handle);
                   Parametros[1] :=  PChar(w1);
                   Parametros[2] :=  nil;
                   error := fpexecve((ExecPath(Env.Values['PATH'],Programa)),Parametros,@wamb);
                end;
{$ELSE}
                   error := execle(PChar(ExecPath(Env.Values['PATH'],Programa)),PChar(Programa),
                           inttostr(socket.Binding.Handle),nil,wamb);
{$ENDIF}
                 if error = -1 then
                 begin
                   MsgErro(Athread,'Não foi possivel executar o programa '+Programa);
{$IFNDEF FPC}
                   Disconnect;
{$ELSE}
                   AThread.Connection.IOHandler.Close;
{$ENDIF}

                   halt(1);
                 end
		 else begin
                   MsgErro(Athread,'Condição anormal ao executar '+Programa+' '+inttostr(errno));
{$IFNDEF FPC}
                   Disconnect;
{$ELSE}
                   AThread.Connection.IOHandler.Close;
{$ENDIF}
                   halt(1);
 		 end;
              end;
          -1 : begin 
                     raise ECCP.Create('Erro no fork do processo filho');
                     result := false;
               end;
          else begin // pai
                status := nil;
{$IFNDEF FPC}
                waitpid(pid,status,0);
                Disconnect;
{$ELSE}
                fpwaitpid(pid,status,0);
                AThread.Connection.IOHandler.Close;
{$ENDIF}
               end;
        end;
{$ELSE}
        BufSize := CreateEnvBlock(Env, True, nil, 0);
        GetMem(  Buffer , BufSize+1024);
	CreateEnvBlock(Env, True, Buffer, BufSize);
	writeres(AThread,0);
        whome := expande(Env.Values['HOME'],Env);
        if whome <> '' then
            try
               chdir(whome);
            except
               MsgErro( AThread, 'Diretorio '+whome+' Inválido');
		       raise ; 
            end;
        WriteLog('Exec:'+Programa+' p/ '+Env.Values['USER']+'-'
                                         +whome+
                                         '-'+DateTimetoStr(now));
        if NovoModoOp then
		begin
//                   {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],Programa)+' '+
            if not CreateProcess({lpApplicationName}
                   NIL {pchar(Programa)},
                   {lpCommandLine} pchar(ExecPath(Env.Values['PATH'],Programa)+' '+
                    inttostr(Binding.Handle)+' '+
                        Binding.PeerIP) {NIL},
                   {lpProcessAttributes} NIL,
                   {lpThreadAttributes} NIL,
                   {bInheritHandles} True,
                   {dwCreationFlags} 0,
                   {lpEnvironment} buffer,
                   {lpCurrentDirectory} NIL,
                   {lpStartupInfo} StartUpInfo,
                   {lpProcessInformation} ProcessInformation) then
            begin
                writeres(AThread,SRV_NOK); // Nao pode voltar para o
                WriteLog('Erro ao executar : '+Programa+' por '+Env.Values['USER']+ ' as '+DateTimetoStr(now));
            end else
            begin
              WaitForSingleObject(ProcessInformation.hProcess,INFINITE);
	      CloseHandle( ProcessInformation.hProcess );
	      CloseHandle( ProcessInformation.hThread );			  
              FreeMem(Buffer,BufSize+1024);
            end;	
	end;	   
{$IFNDEF FPC}
        Disconnect;
{$ELSE}
        AThread.Connection.IOHandler.Close;
{$ENDIF}
{$ENDIF}
      end;
    end;
end;

//function TCCPServer.MyDoExecute(AThread: TIdPeerThread): boolean;
procedure TCCPServer.MyDoExecute(AThread: TIdPeerThread);
var
  TamLidos      : Integer;
  UsuarioSenhaPrograma,
  Usuario,
  Senha,
  Path,
  Programa,
  NovaSenha     : AnsiString;
  Env           : TStringList;
  LauncherEnv   : TLauncherEnv;
  SenhaEmBranco, SenhaExpirada, 
  SenhaAntiga, SenhaMustChange, UsuarioInativo,
  wTimeOut,LoginOK       : boolean;
  User1         : TBaseUser;
  wloginOK	: char;
  wloginStr,
  wtoken,
  wLogPassStr,
  wCaptcha,
  wlogoffstr    : string;
  wSenhaAntiga,wnum,
  wOwner,wGroup : integer;
  wNoDelay,
  Bloqueou : boolean;
  wIP : string;
begin
  wIP := '';
  SenhaEmBranco := false;
  SenhaExpirada := false;
  SenhaMustChange := false;
  UsuarioInativo := false;
  LoginOK := false;
  Bloqueou := false;
  User1 := nil;
  wOwner := -1;
  wGroup := -1;
  wNoDelay:=true;
  wLoginOK := ' ';
  wtoken := '';
  wCaptcha := '';
  LauncherEnv := nil;
  wTimeOut := false;
  SenhaAntiga := false;
  wSenhaAntiga := 0;

{$IFDEF MSWINDOWS}
  setsockopt(AThread.Connection.binding.handle,IPPROTO_TCP,TCP_NODELAY,@wNoDelay,SizeOf(wNoDelay));
{$ELSE}
{$IFDEF FPC}
  LauncherEnvList.BeginWrite;
  try
    if LauncherEnvList.Reset then
    begin
      if assigned(LauncherIni) then
        LauncherIni.Refresh;
      if assigned(Server) then
        LauncherEnvList.Clear;
    end;
  finally 
    LauncherEnvList.Reset := false;
    LauncherEnvList.EndWrite;
  end;
{$ENDIF}
  if LauncherIni.NoDelay then 
  begin
{$IFDEF FPC}
    fpsetsockopt(AThread.Connection.Socket.Binding.Handle,IPPROTO_TCP,TCP_NODELAY,@wNoDelay,SizeOf(wNoDelay));
{$ELSE}
    setsockopt(AThread.Connection.Socket.Binding.Handle,IPPROTO_TCP,TCP_NODELAY,@wNoDelay,SizeOf(wNoDelay));
{$ENDIF}
  end;
{$ENDIF}
  with AThread.Connection{$IFDEF FPC}.IOHandler{$ENDIF} do
  begin
    try
      if readString(1) <> SRV_HDR then
          raise ECCP_Proto.Create('Erro no protocolo CCP - Header');
{$IFDEF FPC}
      ReadTimeout := 200000;
      TamLidos := readLongInt(true); // Lê o tamanho dos dados
{$ELSE}
      TamLidos := readInteger; // Lê o tamanho dos dados
{$ENDIF}
      UsuarioSenhaPrograma := readString(TamLidos);
      ParseUsuarioSenhaPrograma(UsuarioSenhaPrograma,Usuario,Senha,Path,Programa,NovaSenha,wCaptcha);
      try
        Env := TStringList.Create;
        LauncherEnvList.BeginRead;
        try
          LauncherEnv := LauncherEnvList.GetLauncherEnv(Path);
        finally
          LauncherEnvList.EndRead;
        end;
        try
          if Assigned(LauncherEnv) then
	  begin
            if LauncherEnv.SegurancaWS and (Programa = 'LOGIN') then LauncherEnv.LimpaCache(Usuario);
	    User1 := LauncherEnv.GetUser(Usuario);
	    Bloqueou := Assigned(User1) and (User1.fUserTentativasE > LauncherEnv.MaxTentativasErro);
	    if Assigned(user1) and (User1.Passwd <> '') then
	    begin
                if Bloqueou then
                    LoginOk := false
                else begin
                    if LauncherEnv.SegurancaWS and (Programa = 'PASSWD') then
                    begin
                       LoginOK := true;
                       wtoken := User1.Passwd ;
                    end 
                    else LoginOk :=  Assigned(user1) and User1.SenhaOK(Senha) and User1.UserActive;
                    if not LoginOK and assigned(user1) then // Se não conseguiu refresh cash pode ester desatualizado
                    begin
		      wnum := User1.UserTentativasE;
                      LauncherEnv.BeginRead;
                      try
		        LauncherEnv.LimpaSenhas; // Descarta os dados do usuario
  		        if not LauncherEnv.SegurancaWS then LauncherEnv.LoadDBUsers('');;
                      finally
                        LauncherEnv.EndRead;
                      end;
		      User1 := LauncherEnv.GetUser(Usuario);
                      if assigned(User1) then
			User1.UserTentativasE := wnum;
		      LoginOk :=  assigned(User1) and User1.SenhaOK(Senha) and User1.UserActive;
		      if not LoginOk then sleep( 1000);
		    end;
	      end;
	      wGroup := LauncherEnv.Group;
	      wOwner := LauncherEnv.Owner;
	      if LauncherEnv.TemIni then LauncherEnv.GetEnv(Env,LauncherIni.GlobalEnv)
	      else LauncherEnv.GetUser(Usuario).GetEnv(Env,LauncherIni.GlobalEnv);
	    end
	    else begin
	      if LauncherEnv.TemIni then LauncherEnv.GetEnv(Env,LauncherIni.GlobalEnv);
              if LauncherEnv.SegurancaWS then
              begin
                wGroup := LauncherEnv.Group;
                wOwner := LauncherEnv.Owner;
                if (Programa = 'LOGIN') then
                begin
                  wLoginOK := LauncherEnv.LeSegurancaWS(Env,AThread,wOwner,wGroup,usuario,senha,launcherenv.ACESSOSSIMULTANEOS,wIP);
                  wtoken := User1.Passwd;
                  LoginOK := (wLoginOK = 'T') or ( wLoginOK = 'E') or (wLoginOK = 'C') or 
                             (wLoginOK = 'F') or (wLoginOk = 'M') or (wLoginOk = 'B');
                  SenhaExpirada := wLoginOK = 'E';
                  SenhaMustChange := wLoginOK = 'M';
                  SenhaAntiga:= wLoginOK = 'C';
                  SenhaEmBranco := wLoginOK = 'B';
                  UsuarioInativo := not User1.UserActive or (User1.DtValSenha < now) or (wLoginOK = 'E');
                  if SenhaAntiga then 
                  begin
                    wSenhaAntiga := ord(senha[1])-30;
                    delete(senha,1,1);
                  end;  
                  User1.Passwd := Senha;
                end;
              end
              else begin
                if Assigned(user1) then SenhaEmBranco := true;
	        LoginOK := false;
	        wGroup := LauncherEnv.Group;
	        wOwner := LauncherEnv.Owner;
              end;
            end;
            wLoginStr:= LauncherEnv.Loginstr;
            wLogPassStr := LauncherEnv.LogPassStr;
            wLogOffStr := LauncherEnv.LogOffStr;
	  end
	  else WriteLog(' Erro de atribuição do Usuário');
        finally
//          LauncherEnvList.EndRead;
        end;
        if LoginOK  then
        begin
          if (Programa = 'LOGIN') then User1.UltimoUso := now; // Nao da timeout se for feito novo login
          wTimeOut := User1.SectionTimedOut;
          if wTimeOut then raise Exception.Create ('Tempo de seção excedido')
          else User1.UltimoUso := now;
          if not LauncherEnv.SegurancaWS then
          begin
            SenhaExpirada := not User1.TestPasswdDate or (wLoginOK = 'E');
            SenhaAntiga := not User1.TestPasswdChange or (wLoginOK = 'C');
            SenhaMustChange := User1.MustChange or not User1.TestMaxPass 
                               or(wLoginOK = 'M');
            UsuarioInativo := not User1.UserActive or (User1.DtValSenha < now) or (wLoginOK = 'F');
            if SenhaAntiga and not SenhaMustChange and not SenhaExpirada  then 
              wSenhaAntiga := trunc( (User1.UltAltSenha+User1.MaxSenha+1) - now ) 
            else begin
	      wSenhaAntiga := -999;
              SenhaAntiga := false;
            end;
          end;
          if wTimeOut then raise Exception.Create ('Tempo de seção excedido')
          else User1.UltimoUso := now;
          if UsuarioInativo then
            raise ECCP.Create('Usuário inativo, acesso não permitido. Consulte o Administrador !')
          else
            if (not SenhaExpirada and not SenhaMustChange) or (Programa = 'PASSWD') or (SenhaAntiga) then
            begin
              if user1.LimiteDiasSenha(LauncherEnv.DiasExpira) or (Programa = 'PASSWD') then
              begin
                User1.fUserTentativasE := 0;
                if LauncherEnv.SegurancaWS and (Programa = 'LOGOFF') then
                  if LauncherEnv.Servico = '' then 
                      wLogOffStr := wLogOffstr + ' ' + AThread.Connection.{$IFDEF LINUX}socket.{$ENDIF}Binding.PeerIP + ' ' +Senha
                  else
                      wLogOffStr := wLogOffstr + ' ' + LauncherEnv.Servico + ' ' +Senha; 
                if not LauncherEnv.TemIni then {Configuração está vazia pega profile}
                  ProgramExecute(Usuario,Senha,NovaSenha,Path,Programa,Env,
		                 wLoginStr,wLogOffStr,wLogPassStr,AThread)
                else begin { Não tem launcherenv.ini }
                  Env.Insert(0,'USER='+ Usuario);
                  if Env.Values['HOME'] = '' then Env.Add('HOME='+LauncherEnv.RealPath);
                  if LauncherEnv.SegurancaWS then Env.Add('SEG_SISTEMA=WEBSERVICE') else Env.Add('SEG_SISTEMA=LAUNCHER');
                  if LauncherEnv.FazRodizio then Env.Add('FAZRODIZIO=SIM');
                  ProgramExecute(Usuario,Senha,NovaSenha,Path,Programa,Env,
		                 wLoginStr,wLogOffStr,wLogPassStr,
                                 AThread,Launcherenv.SegurancaWS,
                                 wOwner,wGroup,
				 SenhaAntiga, wSenhaAntiga,true,wtoken);
                end;
  	      end
              else begin
	        SenhaExpirada := true;
	        raise ECCP.Create('Limite global de validade da senha atingido');
	      end;
            end
            else raise ECCP.Create('Usuario / Senha Incorreta ou Senha Expirada');
        end
        else begin    
             if not LauncherEnv.TemIni and not DirectoryExists(Path) then 
               raise ECCP.Create('Diretorio '+Path+' nao encontrado')
             else begin
               if Assigned(user1) and not Bloqueou then begin
                 inc(User1.fUserTentativasE);
                 sleep(1000*LauncherEnv.LOGIN_ERR_DELAY);
                 if  User1.fUserTentativasE > LauncherEnv.MaxTentativasErro then
                 begin
                   Bloqueou := true;
                   User1.DtValSenha := now-1;
	           LauncherEnv.GravaExpiracao(usuario);
  //               LauncherEnv.ExecLoginError;
                 end;
                 Env.Insert(0,'USER='+ Usuario);
                 if Env.Values['HOME'] = '' then
                   Env.Add('HOME='+LauncherEnv.RealPath);
                 ExecLog(Athread,Env,LauncherEnv.Owner,LauncherEnv.Group,LauncherEnv.LoginErrStr,NovaSenha);
               end;
  	       raise ECCP.Create('Usuario / Senha Incorreta');
	     end;
        end;
      finally
        freeAndNil(Env);
      end;
    except
      on E:Exception do
      begin
        WriteLog(e.message);
        if Bloqueou then writeres(AThread,SRV_NOK_BLOCK)
        else if wTimeOut then writeres(AThread,SRV_EXPIRED)
        else if UsuarioInativo then writeres(AThread,SRV_NOK_INACTIVE)
        else if SenhaExpirada then writeres(AThread,SRV_NOK_EXPIRED)
        else if SenhaEmBranco then
             begin
               if assigned(Launcherenv) and LauncherEnv.SegurancaWS then writeres(AThread,SRV_WS_NOPASS)
               else  writeres(AThread,SRV_NOK_NOPASS)
             end
        else if SenhaMustChange then writeres(AThread,SRV_NOK_MUSTCHANGE)
        else if assigned(Launcherenv) and LauncherEnv.SegurancaWS then 
             begin
                if Programa = 'LOGIN' then writeres_st(AThread,char(SRV_WS_NOK)+Senha) 
                else writeres(AThread,SRV_WS_NOPASS);
             end
        else writeres(AThread,SRV_NOK);
      end ;
    on Eid: EIDException do begin
    end;
    end;
{$IFNDEF FPC}
    Disconnect;
{$ELSE}
    AThread.Connection.IOHandler.Close;
{$ENDIF}
  end;
{$IFNDEF FPC}
//  Result := true;
{$ENDIF}
end;



{$ENDIF} // Fim ExecLog e Program//Execute - Kylix ***************************




procedure writeres_st(AThread : TidPeerThread;st : ansistring);
type
   TArrBuf = array of char;
var wlen, len : longint;
    buf : TArrBuf;
begin
  len := length(st);
  buf := Default(TArrBuf);
  setlength(buf,len+6);
  buf[1] := RSLT_HDR_ST;
  wlen := htonl(len);
  move(wlen,buf[2],4 );
  if len > 0 then move(st[1],buf[6],len );
{$IFDEF FPC}
  try
    AThread.Connection.IOHandler.Write(RawToBytes(Buf[1],len+5));
  except
    writelog('erro writeres ');
  end;
{$ELSE}
  AThread.Connection.writebuffer(buf[1],len+5,true);
{$ENDIF}
end;

procedure writeres(AThread : TidPeerThread;retorno : longint);
var quatro : longint;
    buf : array [1..10] of char;
begin
  buf[1] := RSLT_HDR;
  quatro := htonl(4);
  move(quatro,buf[2],4 );
  move(retorno,buf[6],4 );
{$IFDEF FPC}
  try 
    AThread.Connection.IOHandler.Write(RawToBytes(Buf,9));
  except
    writelog('erro writeres ');
  end;	  
{$ELSE}
  AThread.Connection.writebuffer(buf,9,true);
{$ENDIF}
end;

procedure TCCPServer.DoDisplayMessage(Message:String);
begin
  if assigned(FOnDisplayMessage) then
    FOnDisplayMessage(Message);
end;

{TServer}

procedure TServer.DisplayMessage(const Msg: string);
begin
//  UILock.Acquire;
  try
      writelog(msg);
  finally
//    UILock.Release;
  end;
end;

constructor TServer.Create;
begin
  inherited;
  CCPServer1:= TCCPServer.Create(nil);
  UILock := TCriticalSection.Create;
end;

destructor TServer.Destroy;
begin
  freeAndNil(CCPServer1);
  freeAndNil(UILock);
  inherited
end;

procedure TServer.run(porta : integer);
{$IFDEF FPC}
var
  Binding: TIdSocketHandle;
  wNoDelay : integer;
{$ENDIF}
begin
{$IFDEF FPC}
  wNoDelay:=1;
{$ENDIF}
  //uses idGlobal
  //explicitly adding a Binding object prevents TIdTCPServer
  //from creating its own default IPv4 and IPv6 Binding objects
  //on the same listening IP/Port pair...
{$IFDEF FPC}
  {$IFDEF LINUX} 
  if not TemLog  then
  begin
    __close(0);            // Redireciona o StdIn p. /dev/null
    fpopen('/dev/null',O_RDWR);
    if not SaidaPadrao then
    begin
      __close(1);            // Redireciona o StdOut p. /dev/null
      fpopen('/dev/null',O_RDWR);
      __close(2);            // Redireciona o StdErr p. /dev/null
      fpopen('/dev/null',O_RDWR);
   end;
  end;
  fpUmask(&002); 
  {$ENDIF}
  CCPServer1.OnDisplayMessage := @DisplayMessage;
  CCPServer1.OnExecute := @CCPServer1.MyDoExecute;
  CCPServer1.Bindings.Clear;
  Binding := CCPServer1.Bindings.Add;
  Binding.IPVersion := Id_IPv4; //optional: forces the Binding to work in Id_IPV4 mode.
  Binding.Port := porta; //customization
  if LauncherIni.NoDelay then
    fpsetsockopt(Binding.Handle,IPPROTO_TCP,TCP_NODELAY,@wNoDelay,SizeOf(wNoDelay));
{$ELSE}
  CCPServer1.OnDisplayMessage := DisplayMessage;
  CCPServer1.DefaultPort := porta;
  CCPServer1.OnExecute := CCPServer1.MyDoExecute;

{$ENDIF}
  CCPServer1.MaxConnections := 5000;
  if Server.CCPServer1.MaxConnections > 0 then
    CCPServer1.MaxConnections := LauncherIni.MaxConn;
  CCPServer1.Active := true;
  listenerfd := CCPServer1.bindings[0].handle;
  FimLoop := false;
  repeat
{$IFDEF LINUX}
{$IFDEF FPC}
    fppause;
{$ELSE}
    pause;
{$ENDIF}
{$ELSE}
    waitforsingleobject(CCPServer1.ThreadMgr.GetThread.Handle ,INFINITE);
{$ENDIF}
    WriteLog('-> Thread terminada');
  until FimLoop;
  CCPServer1.Active := false;
end;

begin
{$IFDEF FPC}
  CritSec := TCriticalSection.Create;
  CritSecEnv := TCriticalSection.Create;
  PodeLiberar := 0;
{$ENDIF}
  LauncherIni := TLauncherIni.Create;
  Server := TServer.Create;
  SaidaPadrao := false;
  TemLog := false;
  if paramcount >= 1 then 
  begin 
    try
	porta := strtoint(paramstr(1));
	except 
	  raise Exception.Create('Erro na conversão da porta especificada para número');
	end;
	if (paramcount = 2) and (Paramstr(2) = '-t' ) then TemLog := true;
	if (paramcount = 2) and (Paramstr(2) = '-c' ) then SaidaPadrao := true;
  end
  else raise Exception.Create('Porta não especificada'); 
  try
    Server.Run(Porta);
    Writelog('Servidor Terminado');
  finally
    freeAndNil(Server);
    freeAndNil(LauncherIni);
{$IFDEF FPC}
    freeandNil(CritSec);
    freeandNil(CritSecEnv);
{$ENDIF}
{$IFDEF MSWINDOWS}
    CoUnInitialize;
{$ENDIF}
end;

end.
