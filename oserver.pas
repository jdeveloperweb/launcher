unit oserver;                               

interface

(*$V+*)
(*$IFDEF PPC*)
(*$DEFINE CONSOLE*)
(*$DEFINE XDB*)
(*$ELSE*)
(*$H-*)
(*$ENDIF*)

uses   {$IFDEF MSWINDOWS} Winsock, ScktComp,windows,dialogs,ZLib,{$ENDIF}
       {$IFDEF KYLIX}  Libc, ZLib, {$ENDIF}
       {$IFDEF FPC} punix, sockets, baseunix, zstream, {$ENDIF}
       {$IFDEF XE} punix, {$ENDIF}
       lib1,Classes,SysUtils, pxmllib;

const 
        MAXBUF = 320000;
        MAXOBJ = 2000;
        STATUSMSG_HDR     = #$F4;
        PROGRESSMSG_HDR   = #$F5;
        METD_HDR_Z  = #$F7;
        METD_HDR_K_Z= #$F8;
        DATA_HDR_Z  = #$F9;
        METD_HDR    = #$FA;
        METD_HDR_K  = #$FC;
        DATA_HDR    = #$FB;
        EXCEPT_HDR  = #$FD;
        DEBUG_HDR = #$FE;
        DEBUGSTOP_HDR = #$FF;
        DEBUGCONTINUE_HDR = #$F6;

type 
        THeader   = record
                        magic  : char;
                        len    : longint;
                    end;
        TBufTrans = array [ 1 .. MAXBUF ] of char;
        TPtrProc  = Procedure(var buf : TBufTrans; len : longint;
                         var bufout : TBufTrans; var lenout : longint);
        TPtrProcStream = procedure(bufin, bufout : TStream );
        TPtrProcJson = procedure(jsonIn, jsonOut: TpXml);

        TObj      = record
                        nome          : string;
                        PtrProc       : TPtrProc;
                        PtrProcStream : TPtrProcStream;
                        PtrProcJson   : TPtrProcJson;
                        ComoString    : boolean;
                    end;
        TArrObj   = array [ 1 .. MAXOBJ ] of TObj;



procedure oserver_transmite( fd, fdlog : word; Stream : TStream; Obj: String);
function  oserver_recebe( fd, fdlog : word; Stream : TStream; obj : string): char; 
procedure Registra( Objeto : string; Func : TPtrProc; ComoString : boolean = true); overload;
procedure Registra( Objeto : string; Func : TPtrProcStream; ComoString : boolean = true); overload;
procedure Registra( Objeto: string; Func: TPtrProcJson; ComoString : boolean = true); overload;
procedure RegistraDefault( Objeto : string; Func : TPtrProc);
procedure ServerRun;
{$IFDEF MSWINDOWS}
function __read(fd:integer;var buf;qtd:longint) : integer;
{$ENDIF}
procedure Debug(DebugMessage:AnsiString; Stop:Boolean = false);
procedure StatusMsg(Msg : string);
procedure Progress(Perc : integer);
procedure Executa(MethodName:AnsiString; jsonIn, jsonOut: TpXml);


implementation

var 
        fd : word;
        obj_l : TArrObj;
        indobj : SmallInt;
        RotinaDefault : TObj;
	ToZ,
        Keep : boolean;
        {$IFDEF MSWINDOWS}
        Sockstream : TWinSocketStream;
        client: Tcustomwinsocket;
        {$ENDIF}
        ip_usuario : string;
        JsonInLinhaDeComando: TpXml;
        ObjLinhaDeComando : string;
        lista_bloqueio_usuarioweb : array [1..103] of ansistring = (
		'wdoc.PostGeraJasper',
		'wdoc.documento',
		'wdoc.GetDocumento',
		'wdoc.GetTempFilePdf',
		'wpretendente.GetDominios',
		'wtela.GetTela',
		'wtela.PostTela',
		'wtela.GetEvolucaoSimulacao',
		'wtela.GetDadosEntrada',
		'wtela.ProcessaTelaGrupoTipoOperacao',
		'wtela.GetOpcoesPrazoFinanciamento',
		'wtela.GetInicializaVariavel',
		'wtela.GetOpcoesDespesasOriginacao',
		'wtela.LeOriginacaoBaseAuxiliar',
		'wtela.GetContratoValidadoCPF',
		'wtela.GetContrato',
		'wtela.GetPrestacoesDisponiveis',
		'wtela.GetPrestacoesPagas',
		'wrenda.GetDemonstrativoIR',
		'wtela.GetSaldoQuitacao',
		'wtela.PostReciboConsolidado',
		'wtela.GetEvolucaoTeorica',
		'wtela.PostGeraRelatorioArqsHtml',
		'wtela.GetConfigEmailEmissaoBoleto',
		'wtela.GetEnviarDocEmail',
		'wtela.GetPrestacoesDisponiveis1',
		'wtela.PutAtualizaSenha',
		'wae.validaambiente',
		'wtela.GetDemonstrativoCET',
                'wtela.GetAcessoContratoCorrelacional',
		'wscciweb.Login',
                'wscciweb.Dados',
                'wscciweb.PrestDisponiveis',
                'wscciweb.PrestPagas',
                'wscciweb.DadosIR',
                'wscciweb.EndMut',
                'wscciweb.AltCad',
                'wscciweb.DadosQuit',
                'wscciweb.LembrarSenha',
                'wscciweb.EmitirRecibo',
                'wscciweb.listactrporctrvelho',
                'wscciweb.listactrporcpf',
                'wscciweb.letitulos',
                'wscciweb.imprimerecibo',
                'wtela.GetValidaCPFePropostaCliente',
                'wtela.GetPretendente',
                'wtela.ProcessaTelaHint',
                'wtela.ProcessaCheckListTecnicoCredito',
                'wtela.GetEnviaEMailAcessoCliente',
                'wtela.GetProcessaCheckListTecnicoCredito',
                'wtela.GetTarefaDisponivel',
                'wtela.GetDados',
                'wtela.GetAndamentoOperacao',
                'wtela.GetPretendenteDocumento',
                'woriginacao.PostInicioTarefa',
                'wdoc.GetDocumentoOperacao',
                'wdoc.PostDocumentoOperacao',
                'wtela.GetPretendenteValidadoCPF',
                'wpretendente.PutPretendente',
                'wtela.GetDadosEmailEnviado',
                'wtela.GetEmailsPretendente',
                'wtela.GetCriticasProposta',
                'wtela.GetListaComponentesCheckList',
                'wtela.GetCheckListPessoa',
                'wtela.GetDadosRating',
                'woriginacao.PostOperacaoSalvaSimulacaoInternet',
                'wtela.GetIndiceReajusteAno',
                'wtela.GetOpcoesMinMaxGrupoOperacao',
                'wtela.GetEvolucaoSimulacaoSeguradoras',
                'wtela.GetContratoGen',
                'wsccireact.GetLoginWeb',
                'wsccireact.GetDadosContratoWeb',
                'wsccireact.GetPrestacoesDisponiveisWeb',
                'wsccireact.GetDadosDemonstrativoIRWeb',
                'wsccireact.GetTitulosWeb',
                'wsccireact.PutDadosCadastroWeb',
                'wsccireact.GetPrestacoesPagasWeb',
                'wsccireact.PostDadosReciboConsolidadoWeb',
                'wsccireact.GetContratosWeb',
                'wsccireact.PutAlterarSenhaWeb',
                'wsccireact.PutRedefinirSenhaWeb',
                'wsccireact.PostGeraPDFWeb',
                'wsccireact.GetDadosReciboWeb',
                'wsccireact.GetSaldoQuitacaoWeb',
                'wsccireact.PostRegularizarOcupImvWeb',
                'wsccireact.PostRenegociarIsencJurosWeb',
                'wsccireact.GetDadosPretendenteWeb',
                'wsccireact.GetDadosProtocoloWeb',
                'wsccireact.GetDadosArquivoIniWeb',
                'wsccireact.GetRetornaDataRefWeb',
                'wsccireact.GetSaldoQuitacaoImpressaoWeb',
                'wmut.GetContratos',
                'wtela.GetOperacaoCredito1',
                'wtela.GetNomePessoaAssinatura',
                'wtela.PostValidaLoginAssinatura',
                'wtela.TrocaIdContratoAssinatura',
                'wdoc.GetDocumentoOperacaoAssinatura',
                'wdoc.PostDocumentoOperacaoAssinatura',
                'wdoc.GetDocumentoContratoAssinatura',
                'wdoc.PostDocumentoContratoAssinatura',
                'wtela.PostSolicitarRevisaoDocumento',
                'wtela.PostMarcaGridDespesaIncorpora',
                'wtela.GetChecklistLaudosPretendente'
);

procedure Log(fd : integer;Tipo : string;MarcaTempo:TDateTime;
              Tamanho, TamanhoCompactado : longint;obj : string; desc : string = '');
{$IFDEF LINUX}
var
  IP, 
  stlog : string;
{$ENDIF}
begin
{$IFDEF LINUX}
    if fd <> -1 then
    begin
        if ip_usuario > '' then 
          IP := ip_usuario
        else 
          IP := paramstr(2);
        stlog := DateTimeToStr(now)+'|'+Tipo+'|'+
                 getenv('USER') +
                 const_str(' ',12-length(getenv('USER')))+ '|' +
                 IP+'|' +
                 intstr2(getpid(),6)+'|'+
                 FormatDateTime('hh:nn:ss:zzz',now-MarcaTempo)+'|'+
                 intstr2(Tamanho,7) +'|'+ intstr2(TamanhoCompactado,7) + '|' +
                 Paramstr(0)+'|'+obj+'|'+desc+#10;
        __write(fd,stlog[1],length(stlog));
    end;
{$ENDIF}
end;

function AchaMetodoValido(obj:ansistring) : boolean;
var 
  i : integer;
begin
  result := false;
  for i := 1 to length(lista_bloqueio_usuarioweb) do
    if lista_bloqueio_usuarioweb[i] = (ExtractFileName(Paramstr(0))+'.'+obj) then
    begin
      result := true;
      break;
    end;
end;

procedure oserver_transmite_exception( fd : word; message : ansistring);
var
  c  : char;
  l  : longint;
  buf : array [ 1.. 1024] of byte;
  nl,
  nw : integer;
  Stream : TMemoryStream;
begin
  buf[1] := 0;
  fillchar(Buf,sizeof(Buf),0);
  Stream := TMemoryStream.create;
  try
    Stream.writebuffer(message[1],length(message));
    c := EXCEPT_HDR;
    l := htonl (Stream.size);
    {$IFDEF MSWINDOWS}
    SockStream.write (c, 1);
    SockStream.write (l, 4);
    {$ELSE}
    __write (fd, c, 1);
    __write (fd, l, 4);
    {$ENDIF}
    Stream.position := 0;
    repeat 
      nl := Stream.read(buf,1024);
      nw := 0;
      if (nl > 0) then 
         nw := {$IFDEF MSWINDOWS} SockStream.write (buf, nl)
               {$ELSE} __write (fd, buf, nl) {$ENDIF};
      if nw <> nl then raise Exception.Create('Erro transmitindo dados');
    until nL < 1024;
  finally
    Stream.free;
  end;
end;

procedure oserver_transmite( fd, fdlog : word; Stream : TStream; Obj: String);
var
  c  : char;
  l  : longint;
  buf2 : pointer;
  buf : array [ 1.. 1029] of byte;
  nl,
  nw : integer;
  Wstream : TMemoryStream;
  Zstream : TCompressionStream;
  MarcaTempo : TDateTime;
  pbuf : integer ;
begin
  pbuf := 5;
  MarcaTempo := now;
  WStream := TMemoryStream.Create;
  try
    if ToZ then
    begin
        Stream.Position := 0;
        c := DATA_HDR_Z;
        ZStream := TCompressionStream.Create(clMax,WStream);
        try
          getmem(buf2,Stream.Size+1);
          Stream.Read(buf2^,Stream.Size);
          ZStream.Write(buf2^,Stream.Size);
        finally
          ZStream.Free; 
        end;
        WStream.Position := 0;
        l := htonl (WStream.Size);
        Freemem(buf2); 
    end
    else begin 
      c := DATA_HDR;
      l := htonl (Stream.Size);
    end;
    {$IFDEF MSWINDOWS}
//    SockStream.write (c, 1);
//    SockStream.write (l, 4);
    {$ELSE}
//    __write (fd, c, 1);
//    __write (fd, l, 4);
    {$ENDIF}
    buf[1] := ord(c);
    move(l,buf[2],4);
    Stream.position := 0;
    repeat 
      if ToZ then  nl := WStream.read(buf[1+pbuf],1024)
      else  nl := Stream.read(buf[1+pbuf],1024);
      inc(nl,pbuf);
      pbuf := 0;
      nw := 0;
      if (nl > 0) then 
           nw := {$IFDEF MSWINDOWS} SockStream.write (buf, nl)
                 {$ELSE} __write (fd, buf, nl) {$ENDIF};
      if nw <> nl then raise Exception.Create('Erro transmitindo dados');
    until nL < 1024-pbuf;
    Log(fdlog,'TX ',MarcaTempo,Stream.size,WStream.Size,obj);
  finally
    WStream.Free;
  end;
end;

procedure ObtemIPUsuario(Stream : TStream);
var
  pos : longint;
  ListaIn : TpXml;
  aux : string;
  i : integer;
begin
  pos := Stream.position;
  ListaIn := TPXML.create();
  aux := '';
  try
    if ip_usuario = '' then
    try
      //vamos procurar a posição do '<?xml' pois pode ser que as 4 primeiras posicoes do stream
      //sejam o tamanho. Se for o caso temos que ler com LoadFromStreamWithSize.
      Stream.position := 4;
      SetLength(aux, 5);
      Stream.ReadBuffer(aux[1], 5);
      Stream.position := 0;
      //pode ser que seja <?xml...> mas vai ser <PMEMORY> se vier do EVP ou CORP
      if (aux = '<?xml') or (aux = '<PMEM') then
        ListaIn.LoadFromStreamWithSize(Stream)
      else
        ListaIn.LoadFromStream(Stream);
      ip_usuario := listaIn['REMOTE_ADDR'].asString;
    except on e:Exception do begin
    end;
    end;
  finally
    Stream.position := pos;
    ListaIn.free;
  end;
end;

function  oserver_recebe( fd, fdlog : word; Stream : TStream; obj : string): char;
type
  TbufChar = array of char;
var
  TamLidos,
  i, size : longint;
  hdr     : THeader;
  buffer  : array [0..999] of char;
  buf     : TBufChar;
  WStream : TMemoryStream;
  ZStream : TDecompressionStream;
  MarcaTempo : TDateTime;
begin
  hdr.Magic := #0;
  fillchar(hdr,sizeof(hdr),0);
  buffer[0] := #0;
  fillchar(Buffer,sizeof(Buffer),0);
  
  MarcaTempo := now;
  i := 0;
  if (__read (fd, hdr.magic, 1) = -1) then 
    raise Exception.Create('Erro recebendo dados');
  if (hdr.magic < #$F7) or (hdr.magic > #$FE) then 
    raise Exception.Create('Erro recebendo header');
  if (__read (fd, hdr.len, 4) = -1) then
    raise Exception.Create('Erro recebendo tamanho');
  hdr.len := ntohl (hdr.len);
  Buf := default(TBufChar);
  SetLength(Buf,hdr.len);
  Stream.size := 0;
  WStream := TMemoryStream.Create;
  try
    while (i < hdr.len) do begin
      size := __read (fd, Buf[0], hdr.len-i);
      if size = -1 then 
        raise Exception.Create('Erro recebendo dados');
      WStream.write(buf[0],size);
      inc (i, size);
    end;
    WStream.Position := 0;
    if hdr.Magic = DATA_HDR_Z then
    begin
      Stream.Position := 0;
      ZStream := TDecompressionStream.Create(WStream);     
      TamLidos := ZStream.Read(Buffer,1000);
      while TamLidos > 0 do
      begin
            Stream.Write(Buffer,TamLidos);
            TamLidos := ZStream.Read(Buffer,1000);
      end;
      Stream.Position := 0;
    end
    else begin
       if hdr.Magic = DATA_HDR then ToZ := false;
       // Caso receba um pacote descompatado continua 
       Stream.CopyFrom(WStream,0);
    end;
    ObtemIPUsuario(Stream);
    if (hdr.Magic = DATA_HDR) or (hdr.Magic = DATA_HDR_Z) then
      Log(fdlog,'RX ',MarcaTempo,Stream.size,WStream.Size,obj);
  finally
    WStream.Free;
  end;
  oserver_recebe := hdr.magic;
  Stream.Position := 0;
end;

procedure DebugInterno(DebugMessage:AnsiString; Stop:Boolean = false);
var
  c  : char;
  l  : longint;
  buf : array [ 1.. 1024] of byte;
  nl,
  nw : integer;
  Stream : TStringStream;
  Magic : char;
begin
  Magic := #0;
  buf[1] := 0;
  fillchar(Buf,sizeof(Buf),0);
  Stream := TStringStream.Create(DebugMessage);
  try
    if Stop then
      c := DEBUGSTOP_HDR
    else
      c := DEBUG_HDR;
    l := htonl (Length(DebugMessage));
    {$IFDEF MSWINDOWS}
    SockStream.write (c, 1);
    SockStream.write (l, 4);
    {$ELSE}
    __write (fd, c, 1);
    __write (fd, l, 4);
    {$ENDIF}
    Stream.position := 0;
    repeat 
      nl := Stream.read(buf[1],1024);
      nw := 0;
      if (nl > 0) then 
           nw := {$IFDEF MSWINDOWS} SockStream.write (buf, nl)
                 {$ELSE} __write (fd, buf, nl) {$ENDIF};
      if nw <> nl then raise Exception.Create('Erro transmitindo dados');
    until nL < 1024;
    if Stop then { espera a resposta para prosseguir }
    begin
      if (__read (fd, Magic, 1) = -1) then
        raise Exception.Create('Erro esperando resposta de depuração');
      if Magic <> DEBUGCONTINUE_HDR then
        raise Exception.Create('Erro esperando resposta de depuração');
    end;
  finally
    Stream.free;
  end;
end;

procedure Debug(DebugMessage:AnsiString; Stop:Boolean = false);
begin
  if ObjLinhaDeComando <> '' then
    writeln(DebugMessage)
  else
    DebugInterno(DebugMessage, Stop);
end;

procedure StatusMsg(Msg : string);
var
  c  : char;
  l  : longint;
  buf : array [ 1.. 1024] of byte;
  nl,
  nw : integer;
  Stream : TStringStream;
begin
  buf[1] := 0;
  fillchar(Buf,sizeof(Buf),0);
  Stream := TStringStream.Create(Msg);
  try
    c := STATUSMSG_HDR;
    l := htonl (Length(Msg));
    {$IFDEF MSWINDOWS}
    SockStream.write (c, 1);
    SockStream.write (l, 4);
    {$ELSE}
    __write (fd, c, 1);
    __write (fd, l, 4);
    {$ENDIF}
    Stream.position := 0;
    repeat
      nl := Stream.read(buf[1],1024);
      nw := 0;
      if (nl > 0) then
           nw := {$IFDEF MSWINDOWS} SockStream.write (buf, nl)
                 {$ELSE} __write (fd, buf, nl) {$ENDIF};
      if nw <> nl then raise Exception.Create('Erro transmitindo dados');
    until nL < 1024;
  finally
    Stream.free;
  end;
end;
 
procedure Progress(Perc : integer);
var
  c  : char;
  l  : longint;
  buf : array [ 1.. 1024] of byte;
  nl,
  nw : integer;
  Stream : TStringStream;
  wperc : string;
begin
  buf[1] := 0;
  fillchar(Buf,sizeof(Buf),0);
  wperc := inttostr(Perc);
  Stream := TStringStream.Create(wPerc);
  try
    c :=PROGRESSMSG_HDR;
    l := htonl (Length(wPerc));
    {$IFDEF MSWINDOWS}
    SockStream.write (c, 1);
    SockStream.write (l, 4);
    {$ELSE}
    __write (fd, c, 1);
    __write (fd, l, 4);
    {$ENDIF}
    Stream.position := 0;
    repeat
      nl := Stream.read(buf[1],1024);
      nw := 0;
      if (nl > 0) then
           nw := {$IFDEF MSWINDOWS} SockStream.write (buf, nl)
                 {$ELSE} __write (fd, buf, nl) {$ENDIF};
      if nw <> nl then raise Exception.Create('Erro transmitindo dados');
    until nL < 1024;
  finally
    Stream.free;
  end;
end;
 
function getword(Stream : TStream; var obj : String) : boolean;
var { so pega uma palavra se tiver uma , terminando a palavra }
  nl : LongInt;
  ch : char;
begin
        Ch := #0;
        Obj := '';
        nl := Stream.Read(Ch,1);
        while (nl > 0) and ( Ch <> ',' ) do
        begin
          obj := Obj + ch;
          nl := Stream.Read(Ch,1);
        end;
        GetWord := nl > 0;
end;

function ProcuraObj(nome: string) : SmallInt;
var
        ind : SmallInt;
begin
        ind := 1;
        while (ind <= indobj) and (obj_l[ind].nome <> nome) do inc (ind);
        if ind > indobj then ProcuraObj := 0 else ProcuraObj := ind;
end;
                   
procedure InitFD(wfd: SmallInt);
begin
        fd := wfd;
        {$IFDEF MSWINDOWS}
        client := tcustomwinsocket.create(fd);
        client.asyncstyles := [];
        SockStream := TWinSocketStream.Create(client, 60000);
        {$ENDIF}
end;

procedure Registra( Objeto : string; Func : TPtrProc; ComoString : boolean = true);
begin
        indobj := indobj + 1;
        if IndObj > MaxObj then 
          raise exception.create('Limite de métodos atingido');
        obj_l[indobj].nome := Objeto;
        obj_l[indobj].PtrProc := Func;
        obj_l[indobj].PtrProcStream := nil;
        obj_l[indobj].PtrProcJson := nil;
        obj_l[indobj].ComoString := ComoString;
end;

procedure Registra( Objeto : string; Func : TPtrProcStream; ComoString : boolean = true); overload;
begin
        indobj := indobj + 1;
        if IndObj > MaxObj then raise exception.create('Limite de métodos atingido');
        obj_l[indobj].nome := Objeto;
        obj_l[indobj].PtrProc := nil;
        obj_l[indobj].PtrProcStream := Func;
        obj_l[indobj].PtrProcJson := nil;
        obj_l[indobj].ComoString := ComoString;
end;

procedure Registra( Objeto: string; Func: TPtrProcJson; ComoString : boolean = true); overload;
begin
        indobj := indobj + 1;
        if IndObj > MaxObj then raise exception.create('Limite de métodos atingido');
        obj_l[indobj].nome := Objeto;
        obj_l[indobj].PtrProc := nil;
        obj_l[indobj].PtrProcStream := nil;
        obj_l[indobj].PtrProcJson := Func;
        obj_l[indobj].ComoString := ComoString;
end;

procedure RegistraDefault( Objeto : string; Func : TPtrProc);
begin
        RotinaDefault.nome := Objeto;
        RotinaDefault.PtrProc := Func;
        RotinaDefault.PtrProcStream := nil;
        RotinaDefault.PtrProcJson := nil;
end;



procedure ServerRun;
var
        pbufout,
        pbuf : ^TBufTrans;
        jsonIn,
        jsonOut: TpXml;
        lenout : LongInt;
        ind : LongInt;
        obj : string;
        chRet :char;
        StreamIn,
        StreamOut : TMemoryStream;
        ExecutouOk : boolean;
        MarcaTempo : TDateTime;
        fdlog : integer;
{$IFDEF LINUX}
        umasksaved : integer;
        LogFileName : TFileName;
{$ENDIF}
begin
{$IFDEF DESENVOLVIMENTO}
  if DebugMonitor = '' then
    DebugFuncPtr := {$IFDEF FPC}@{$ENDIF}Oserver.Debug;
{$ENDIF}
  lenout := 0;
  obj := '';
  getmem(pbufout,sizeof(TBufTrans));
  getmem(pbuf,sizeof(TBufTrans));
{$IFDEF LINUX}
  umasksaved := umask(0);
  LogFileName := '/var/log/launcher/accesslog.'+FormatDatetime('MMYY',Now);
  fdlog := open(pchar(LogFileName),O_APPEND or O_RDWR or O_CREAT,$1b6); { $1b6 = 0666 = rw-rw-rw- para mascara de criacao do arquivo }
  MarcaTempo := now;
  umask(umasksaved);
{$ELSE}
  MarcaTempo := now;
  fdlog := 0;
{$ENDIF}
  StreamIn := TMemoryStream.Create;
  StreamOut := TMemoryStream.Create;
  try
        if ObjLinhaDeComando <> '' then
          chRet := METD_HDR
        else
          chRet :=  OServer_Recebe(fd,fdlog,StreamIn,'');

        keep := (chRet = METD_HDR_K) or (chRet = METD_HDR_K_Z);
        if (chRet = METD_HDR) or (chRet = METD_HDR_K) or
           (chRet = METD_HDR_Z) or (chRet = METD_HDR_K_Z) then 
          repeat
            if (ObjLinhaDeComando <> '') or getword(StreamIn,obj) then
            begin
                if ObjLinhaDecomando <> '' then begin
                  chRet := DATA_HDR;
                  Obj := ObjLinhaDeComando;
                end else
                  chRet := OServer_Recebe(fd,fdlog,StreamIn,obj);
                MarcaTempo := now;
                if (getenv('USER') = 'usuarioweb') and not (AchaMetodoValido(obj)) then  // Scat 57406
                begin
                  Log(fdlog,'EXP',MarcaTempo,0,0,obj,'Atenção: a função '+ExtractFileName(Paramstr(0))+'.'+obj+' não é permitida para este acesso.');
                  oserver_Transmite_Exception(Fd,'Atenção: a função '+ExtractFileName(Paramstr(0))+'.'+obj+' não é permitida para este acesso.');
                  raise exception.create('Atenção: a função '+ExtractFileName(Paramstr(0))+'.'+obj+' não é permitida para este acesso.');
                end;
                if (chRet = DATA_HDR) or (chRet = DATA_HDR_Z) then
                begin
                  if obj = 'Close_Keep' then 
                  begin
                     keep := false;
                     break; 
                  end; 
                  ind := ProcuraObj(obj);
                  if ind > 0 then 
                  begin
                      Executouok := true;
                      try
                        if assigned(obj_l[ind].PtrProc) then
                        begin
                          if ObjLinhaDeComando <> '' then
                            raise exception.create('Método não suportado. Somente métodos com entrada json');
                          StreamIn.read(pBuf^,StreamIn.size);
                          obj_l[ind].PtrProc(pBuf^,StreamIn.Size,pbufout^,lenout);
                          StreamOut.SetSize(0);
                          StreamOut.write(pbufout^,lenout);
                        end
                        else if assigned(obj_l[ind].PtrProcStream) then begin
                          if ObjLinhaDeComando <> '' then
                            raise exception.create('Método não suportado. Somente métodos com entrada json');
                          StreamOut.size := 0;
                          obj_l[ind].PtrProcStream(StreamIn,StreamOut)
                        end else begin// PtrProxJson
                          jsonIn := TpXml.Create;
                          jsonOut := TpXml.Create;
                          try
                            StreamOut.size := 0;
                            if assigned(JsonInLinhaDeComando) then
                              JsonIn.documentelement.assignAttributesAndChildren(jsonInLinhaDeComando.documentElement)
                            else
                              jsonIn.ParseStream(Streamin);
                            if assigned(obj_l[ind].PtrProcJson) then
                              obj_l[ind].PtrProcJson(jsonIn,jsonOut);
                            if ObjLinhaDeComando <> '' then
                              write(JsonOut.toJson('',false,true,false))
                            else begin
                              if obj_l[ind].ComoString then
                                JsonOut.toJsonStringStream(StreamOut,'')
                              else
                                JsonOut.toJsonStream(StreamOut,'');
                            end;
                          finally
                            jsonIn.free;
                            jsonOut.free;
                          end;
                        end;
                        Log(fdlog,'RUN',MarcaTempo,0,0,obj);
                        MarcaTempo := now;
                      except
                        on e : exception do
                          begin
                            Log(fdlog,'EXP',MarcaTempo,0,0,obj,e.message);
                            OServer_Transmite_Exception(Fd,e.message);
                            ExecutouOk := false; 
                          end;
                      end;
                      if ExecutouOk and (ObjLinhaDeComando = '') then 
                      begin
                        OServer_Transmite(fd,fdlog,StreamOut,obj);
                      end
                  end
                  else begin { Nao encontrou a rotina }
                    Log(fdlog,'EXP',MarcaTempo,0,0,obj,'Rotina nao encontrada');
                    if obj <> '' then 
			Oserver_Transmite_Exception(Fd, 'Rotina '+
                                                   obj+ 
                                                   ' nao encontrada');
                  end
                end
                else  begin { Pparametros incorretos };
                    Log(fdlog,'EXP',MarcaTempo,0,0,obj,'Parametros incorretos');
                    Oserver_Transmite_Exception(Fd,'Parametros incorretos');
                end
            end
            else  begin { Nome do metodo ausente }
              ExecutouOk := false;
              try
                MarcaTempo := now;
                if @RotinaDefault.PtrProc <> nil then
                begin
                  StreamIn.read(pBuf^,StreamIn.size);
                  RotinaDefault.PtrProc(pbuf^,StreamIn.Size,pbufout^,lenout);
                  StreamOut.SetSize(0);
                  StreamOut.write(pbufout^,lenout);
                end;
                ExecutouOk := true;
                Log(fdlog,'RUN',MarcaTempo,0,0,obj);
                MarcaTempo := now;
              except
                on e : exception do
                begin
                  Log(fdlog,'EXP',MarcaTempo,0,0,obj,'Parametros incorretos');
                  if ObjLinhaDeComando = '' then
                    OServer_Transmite_Exception(fd,e.message)
                  else
                    writeln(e.message);
                  MarcaTempo := now;
                end;
              end;
              if ExecutouOk then 
              begin
                if ObjLinhaDeComando = '' then
                  OServer_Transmite(fd,fdlog,StreamOut,'Default');
                Log(fdlog,'TX ',MarcaTempo,StreamOut.size,0,obj);
                MarcaTempo := now;
              end;
            end;
            if keep then
              OServer_Recebe(fd,fdlog,StreamIn,'');
          until not keep;
{$IFDEF LINUX}
    __close(fd);
    __close(fdlog);
{$ELSE}
	Client.close;
{$ENDIF}
  finally
    StreamIn.free;
    StreamOut.free;
    freemem(pbuf);
    freemem(pbufout);
  end;
end;


{$IFDEF MSWINDOWS}
function __read(fd:integer;var buf;qtd:longint) : integer;
begin
    if SockStream.WaitForData(60000) then
    begin
	try
          result := SockStream.Read(Buf, qtd);
          if result = 0 then result := -1;
	except
	  result := -1;
	end;
    end
    else result := -1
end;
{$ENDIF}

procedure Executa(MethodName:AnsiString; jsonIn, jsonOut: TpXml);
var
  ind: Integer;
begin
  if (getenv('USER') = 'usuarioweb') and not (AchaMetodoValido(MethodName)) then  // Scat 57406
    raise exception.create('Atenção: a função '+ExtractFileName(Paramstr(0))+'.'+MethodName+' não é permitida para este acesso.');
  ind := ProcuraObj(MethodName);
  if ind > 0 then 
  begin
    if assigned(obj_l[ind].PtrProcJson) then
    begin
      obj_l[ind].PtrProcJson(jsonIn,jsonOut);
    end
  end
  else
  begin
    raise Exception.Create(MethodName+' não encontrado');
  end;
end;

var
  i,
  IdInput : integer;
  nomeVar,
  Valor : AnsiString;
begin
//        {$IFDEF MSWINDOWS}
//        InitFD(16);
//        {$ELSE}
    ObjLinhaDeComando := '';
    JsonInLinhaDeComando := nil;
    if paramcount >= 1 then
		try
      IdInput := strtoint(paramstr(1));
      if idInput = 0 then begin
        //nao esta sendo chamado pelo launcher
        ObjLinhaDeComando := paramstr(2);
        JsonInLinhaDeComando := TpXml.create;
        fd := 1; //para o canal de saida
        for i := 3 to paramcount do begin
          nomeVar := palavra(paramstr(i), 1, '=', #255, #255);
          valor := palavra(paramstr(i), 2, '=', #255, #255);
          JsonInLinhaDeComando.add(nomeVar).asString := valor;
        end;
      end else
 			  InitFD(IdInput);
    except
			{ ignorado , pois foi chamado de pgm que nao e w }
		end
    else InitFD(4);
//        {$ENDIF}
    ToZ := true;
    indobj := 0;
{        RotinaDefault.Ptr := nil; }
//        DebugFuncPtr := {$IFDEF FPC}@{$ENDIF}Oserver.Debug;
end.


