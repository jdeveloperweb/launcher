program sccidoc;
{ Programa para fazer a mudança de protocolo http<->ccp específico para }
{ ler e gravar arquivos no sistema de documentos do SCCI                }
{ Será utilizado especificamente os métodos wdoc/getDoc e wdoc/putDoc   }

 
uses SysUtils, Classes, punix, ucommunication, pxmllib, pIniFiles, pcrypt, lib1, strutils;

type
  Tdebug = Class
    FPID,
    FPath: AnsiString;
    FAberto: boolean;
    FArquivo: Text;
    procedure abre;
    procedure fecha;
    procedure write(msg:AnsiString);
    constructor create;
    destructor destroy; override;
    property PID: AnsiString read FPID write FPID;
    property PATH: AnsiString read FPATH write FPATH;
  end;

  TpWIni = record
             usuarioWeb,
             senhaWeb,
             tokenWeb,
             ambienteOperacional,
             metodosPermitidos,
             HUBSessionKey,
             HUBToken : AnsiString;
           end;

 
var
  Entrada:AnsiString;
  i:integer;
  Debug: TDebug;
  Criptografa: boolean;
  wini: TpWIni;


function DecodeUrl(url: AnsiString): AnsiString;
var
  x: integer;
  ch: string;
  sVal: string;
  Buff: string;
begin
  //Init
  Buff := '';
  x := 1;
  while x <= Length(url) do
  begin
    //Get single char
    ch := url[x];
    if ch = '+' then
    begin
      //Append space
      Buff := Buff + ' ';
    end
    else if ch <> '%' then
    begin
      //Append other chars
      Buff := Buff + ch;
    end
    else
    begin
      //Get value
      sVal := Copy(url, x + 1, 2);
      //Convert sval to int then to char
      Buff := Buff + char(StrToInt('$' + sVal));
      //Inc counter by 2
      Inc(x, 2);
    end;
    //Inc counter
    Inc(x);
  end;
  //Return result
  Result := Buff;
end;

procedure DecodeParams(Entrada:AnsiString; Params:TpXml);
var
 i,f,l,j: integer;
 st: string;
 nome, valor: AnsiString;
begin
  while(Entrada>'') and (entrada[1] = ' ') do delete(entrada,1,1);
  if (Entrada>'') and (copy(Entrada,1,1)[1] in ['{','['] ) then // JSOn
  begin
    Entrada := '{ "PMemory" : ' + Entrada + '}';
    Params.ParseString(Entrada);
    Params.DocumentElement.NodeName := 'PMemory';
  end
  else if (copy(Entrada,1,1) = '<') then //XML
  begin
    Params.ParseString(Entrada);
  end
  else
  begin
    i := 1;
    f := 0;
    l := length(Entrada);
    while (i <= l) do
    begin
      inc(f);
      while (f <= l) and (Entrada[f] <> '&') do inc(f);
      St := copy(Entrada,i,f-i);
      j := pos('=',st);
      if (j > 0) then
      begin
        Nome := copy(st,1,j-1);
        Valor := copy(st,j+1,MaxInt);
      end
      else
      begin
        Nome := st;
        valor := '';
      end;
      if Nome>'' then begin
        Params.add(DecodeURL(Nome)).AsString := utf8toAnsi(DecodeURL(Valor));
      end;
      i := f+1;
    end;
  end;
end;

function GetServerPath(Path_Info:AnsiString):AnsiString;
begin
  i := length(Path_info);
  while(i > 1) and (Path_Info[i] <> '/') do dec(i);
  dec(i);
  while(i > 1) and (Path_Info[i] <> '/') do dec(i);
  result := copy(Path_Info,1,i);    
end;

function NomeProg : ansistring;
begin
  result := ExtractFileName(ParamStr(0));
  if pos('.',result) > 0 then
    result := copy(result,1,pos('.',result)-1);
end;

function codifica(entrada: AnsiString) : AnsiString;
var
  j : byte;
  l : integer;
  i : integer;
begin
  Result := ansiToUtf8(entrada);
  if Criptografa then
  begin
    j := 0;
    l := length(Result);
    for i := 1 to l do 
      // Não altera os caracteres extendidos utf8
      if ((ord(Result[i]) and $80) <> $80) then
      begin
        j := byte(j + 1);
        Result[i] := chr(ord(Result[i]) xor ($70 + (j and 15)));
      end;
    insert('.*(@',result,1);
  end;
end;

function TrataSaidaHUB(saidaStr : Ansistring): ansistring;
var
  Xml,
  XmlAux : TpXml;
  StrAux : AnsiString;
  i,
  count: integer;
begin
  result := saidaStr;
  Xml := TpXml.create;
  XmlAux := TpXml.create;
  try
    Xml.parsestring(saidaStr);
    count := 0;
    StrAux := '';
    for i := 0 to xml.documentelement.count - 1 do begin
      if (xml[i].nodeName = 'PMemory') and (xml[i].isArray) then begin
        inc(count);
        if count > 1 then
          StrAux := StrAux + ',';
        StrAux := StrAux + Copy(Xml[i].toJson(0), length('"PMemory": '), length(Xml[i].toJson(0)));
      end;
    end;
    if count > 0 then
      result := '[' + trim(StrAux) + ']';
  finally
    Xml.free;
    XmlAux.free;
  end;
end;

procedure DecodeProgramNameAndMethod(Path_Info:AnsiString; out ProgramName,MethodName:AnsiString);
var
  i : Integer;
  st : TStringList;
  index : integer;
begin
{
  exemplos de PATH_INFO no windows e linux

   windows
     PathInfo=/corpweb/rest/sccidoc/wdoc/TempFilePdf

   Linux
      PathInfo=/wdoc/TempFilePdf
}

  ProgramName := '';
  MethodName := '';

  st := TStringList.create;
  try
    st.delimiter := '/';
    st.DelimitedText := Path_Info;
    // encontra o nome do programa no pathinfo
    index := -1;
    for i := 0 to st.count-1 do
      if comparetext(st[i],NomeProg) = 0 then begin
        index := i;
        break;
      end;

    // se não achou o programa, utiliza o primeiro e segundo valores (0 seria o que vem antes da primeira "/")
    if index < 0 then begin
     if st.count > 1 then
       Programname := st[1];
     if st.count > 2 then
       MethodName := st[2];
    end
    else begin // utiliza os parâmetros seguintes ao nome do programa
      if index+1 < st.count then
        ProgramName := st[index+1];
      if index+2 < st.count then
        MethodName := st[index+2];
    end;
  finally
    st.free;
  end;
  if (length(ProgramName)>0) and (ProgramName[1] = '/') then delete(ProgramName,1,1);
  if (length(ProgramName)>0) and (ProgramName[length(ProgramName)] = '/') then delete(ProgramName,length(ProgramName),1);
  if (length(MethodName)>0) and (MethodName[1] = '/') then delete(MethodName,1,1);
  if (length(MethodName)>0) and (MethodName[length(MethodName)] = '/') then delete(MethodName,length(MethodName),1);
  if (length(MethodName)>0) then MethodName[1] := UpCase(MethodName[1]);
end;

procedure LeConfig(out Server, Port, Contexto:AnsiString; out wini: TpWini);
var
  Ini : TMemIniFile;
begin
  Ini := TMemIniFile.Create('w.ini');
  try
    Server := Ini.ReadString('Servidor','Servidor','');
    Port := Ini.ReadString('Servidor','Porta','');
    Contexto := Ini.ReadString('Servidor','Contexto','');
    Criptografa := Ini.ReadString('Servidor','Criptografa','F') = 'T';
    wini.UsuarioWeb := Ini.ReadString('Simulador','usuarioweb','usuarioweb');
    wini.senhaWeb := Ini.ReadString('Simulador','senhaweb','branco');
    wini.tokenweb := Ini.ReadString('Simulador','tokenweb','MDNKMIMJPOPDPDPLOKOLOPBO');
    wini.ambienteOperacional := Ini.ReadString('Servidor', 'AmbienteOperacional', '');
    if wini.ambienteOperacional = '' then
      wini.ambienteOperacional := Ini.ReadString('Servidor', 'ambienteOperacional', '');
    wini.metodosPermitidos := Ini.ReadString('Servidor', 'Metodos', '');
    wini.HUBToken := Ini.readstring('ApiSeg', 'hub_token', '');
    wini.HUBSessionKey := Ini.readstring('ApiSeg', 'hub_senha', '');
  finally
    Ini.free;
  end;
end;

procedure  decodeServerPath(Entrada:AnsiString; out Server,Port,ServerPath:AnsiString);
var
  i,j: integer;
begin
  Server := '';
  Port := '';
  ServerPath := '';
  if copy(Entrada,length(Entrada),1) <> '/' then
      Entrada := Entrada + '/';
  i := pos('/',Entrada);
  if (i > 1) then
  begin
    Server := copy(Entrada,1,i-1);
    j := pos(':',Server);
    Port := copy(Server,j+1,MaxInt);
    Server := copy(Server,1,j-1);
    Serverpath := copy(Entrada,i,MaxInt); // Inclui a barra
  end
  else
    Serverpath := Entrada;
end;

constructor TDebug.Create;
begin
  inherited;
  FAberto := false;
end;

procedure TDebug.abre;
begin
  if not FAberto then
  begin
    assign(FArquivo,FPath+PathDelim+'debug'+FPID+'.txt');
    append(FArquivo);
    fAberto := true;
  end;
end;

procedure TDebug.fecha;
begin
  if fAberto then
    close(FArquivo);
end;

destructor TDebug.destroy;
begin
  fecha;
  inherited;
end;

procedure TDebug.write(Msg: AnsiString);
begin
  if not faberto then Abre;
  writeln(FArquivo,Msg);
  flush(FArquivo);
end;

function GetLine(var st:AnsiString):AnsiString;
var
  i : integer;
begin
  result := '';
  i := pos(#10,st);
  if (i > 0) then 
  begin
    result := copy(st,1,i-1);
    if (result[length(result)] = #13) then system.delete(result,length(result),1);
    system.delete(st,1,i);
  end;
end;

function GetFileName(st:AnsiString):AnsiString;
begin
  result := '';
  i := pos('filename="',st);
  if i > 0 then
  begin
    result := copy(st,i+10,MaxInt);
    i := pos('"',result);
    if i > 0 then
      system.delete(result,i,MaxInt);
  end;
end;

procedure DoMultiPartRemoteCall(Server,Port,ServerPath,ProgramName,MethodName,Entrada:AnsiString;Params: TpXml; Boundary:AnsiString);
var
  pCCPClient : TpCCPClient;
  BufInOut : TStringStream;
  i, j, k: integer;
  LServer,
  LPort: AnsiString;
  LPid : AnsiString;
  St, FileName: AnsiString;
  OutPutStream: THandleStream;
  Usuario,
  Senha,
  Resposta: AnsiString;
  comecoDoBundary:integer;
  chegouNoFim:Boolean;
  listaRes : TStringList;
  p, dados : TpXmlNode;
  jsonAux,
  jsonOut : TpXml;
  HttpMessage,
  HttpStatus : AnsiString;
begin
  Usuario := '';
  pCCPClient := TpCCpClient.create(nil);
  OutputStream := THandleStream.Create(STDOUTPUTHANDLE);
  listaRes := TStringList.create;
  jsonOut := TpXml.create;
  try
    try
      Usuario := Params['userName'].AsString;
      pCCPClient.Params.Values['User'] := Usuario;
      p := Params['sessionKey'];
      LPID := '';
      Senha := '';

      if assigned(p) then
      begin
        if (Usuario = 'loginpoupex') or (Usuario = 'loginintegracao') then
          Senha := p.AsString
        else begin
          Senha := webDeCrypt(copy(p.AsString,6,255));
          LPID := copy(p.AsString,1,5);
        end;
      end
      else begin
        if Usuario = wini.usuarioWeb then
        Senha :=  '[' + webDeCrypt(wini.tokenWeb) + ']'; //webDeCrypt(wini.tokenWeb);
      end ;
      pCCPClient.Params.Values['Password'] := Senha;
      p := Params['ambienteOperacional'];
      if Params['ambienteOperacional'].AsString = '' then
        raise Exception.Create('Parametro ambienteOperacional é obrigatório');
      if assigned(p) then
      begin
        decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
        if (LPort > '') then
          pCCPClient.Params.Values['Socket'] := LPort
        else
          pCCPClient.Params.Values['Socket'] := Port;
        if (LServer > '') then
          pCCPClient.Params.Values['Server'] := LServer
        else
          pCCPClient.Params.Values['Server'] := Server;
        pCCPClient.Params.Values['Serverpath'] := ServerPath;
      end;
      Debug.Path := '.';
      chegouNoFim:=false;
      Debug.PID := LPID;
      pCCPClient.onDebug := @Debug.write;
      st := GetLine(Entrada);
      st := GetLine(Entrada);
      FileName := GetFileName(St);
      st := GetLine(Entrada);
      st := GetLine(Entrada);
      comecoDoBundary := pos(#13#10 + '--' + boundary,entrada);
      if(comecoDoBundary=0) then
        comecoDoBundary:= length(entrada)
      else
      comecoDoBundary:=comecoDoBundary-1;
    while not (chegouNoFim) do begin
      // writeln('ponto 4:',i, 'tamanho:',length(entrada));
      Params.DocumentElement.NodeName := 'PMEMORY';
      Params.AddOrGet('FileName').AsString := extractFileName(FileName);
      BufInOut := TStringStream.Create(st);
      if wini.HUBToken > '' then
        TStream(BufInOut).writeAnsiString(Params.ToJson)
      else
        TStream(BufInOut).writeAnsiString(Params.Code);
      BufInOut.writeBuffer(entrada[1],comecoDoBundary);
      pCCPClient.exec(Programname+'.'+Methodname,BufInOut);
      Resposta := TStream(BufInOut).ReadAnsiString;
      system.delete(Entrada,1,comecoDoBundary);
      st := GetLine(Entrada);
      st := GetLine(Entrada);
      st := GetLine(Entrada);
      FileName := GetFileName(St);
      st := GetLine(Entrada);
      st := GetLine(Entrada);
      comecoDoBundary := pos(#13#10 + '--' + boundary,entrada);
      if(comecoDoBundary=0) then
        comecoDoBundary:= length(entrada)
      else
        comecoDoBundary:=comecoDoBundary-1;

      if (copy(Resposta,1,1) = '{') then
        listaRes.add(Resposta);

      if(trim(FileName)='') then begin
         chegouNoFim:=True;
      end;
    end;
    for j := 0 to listaRes.Count - 1 do begin
      jsonAux := TpXml.create;
      //a rotina TpXml.ParseString tem um comportamento estranho: Ao enviar uma str json com apenas 1 valor 
      //por ex: '{ "success": true }', não é possível acessar jsonAux['success']...
      //vamos adicionar um elemento <response> como raiz do json para garantir que será interpretado corretamente
      listaRes[j] := '{"response": ' + listaRes[j] + '}';
      jsonAux.ParseString(listaRes[j]);
      if wini.HUBToken > '' then begin
        for k := 0 to jsonAux.documentElement.count - 1 do begin
          p := jsonOut.add(jsonAux[k].nodeName);
          p.assignAttributesAndChildren(jsonAux[k]);
        end;
      end
      else if assigned(jsonAux['dados']) then begin
        dados := jsonOut.addorget('dados');
        for k := 0 to jsonAux['dados'].count - 1 do begin
          p := dados.add(jsonAux['dados'][k].nodeName);
          p.assign(jsonAux['dados'][k]);
        end;
      end;
      if assigned(jsonAux['success']) then
        jsonOut.addorget('success').asBoolean := jsonAux['success'].asBoolean;
      if assigned(jsonAux['message']) and not assigned(jsonOut['message']) and
         (jsonAux['message'].asString > '') then
        jsonOut.add('message').asString := jsonAux['message'].asString;
      if jsonAux['HTTPSTATUS'].asString > '' then
        HttpStatus := jsonAux['HTTPSTATUS'].asString
      else if jsonAux['HUBHTTPSTATUS'].asString > '' then
        HttpStatus := jsonAux['HUBHTTPSTATUS'].asString;
      if jsonAux['HTTPMESSAGE'].asString > '' then
        HttpMessage := jsonAux['HTTPMESSAGE'].asString
      else if jsonAux['HUBHTTPMESSAGE'].asString > '' then
        HttpMessage := jsonAux['HUBHTTPMESSAGE'].asString;
    end;

    // if HttpStatus > '' then begin
    //   writeln;
    //   write('Status: '+httpStatus+HttpMessage);
    // end;
    if (pos('Chrome',getenv('HTTP_USER_AGENT')) > 0) or
      (pos('Safari',getenv('HTTP_USER_AGENT')) > 0) or
      (pos('Firefox',getenv('HTTP_USER_AGENT')) > 0) then
        writeln('Content-Type: application/json; charset=utf-8',#10#13)
    else
      writeln('Content-Type: text/json; charset=utf-8',#10#13);
    if wini.HUBToken > '' then
      write(codifica(TrataSaidaHUB(jsonOut.toJson)))
    else if (copy(Resposta,1,1) = '{') then
      write(codifica(jsonOut.toJson))
    else
      writeln(Resposta);

      flush(output);
    except
      on E:Exception do
      begin
        p := tpxmlnode.create(nil);
        p.nodeName := '';
        if (pos('Chrome',getenv('HTTP_USER_AGENT')) > 0) or
           (pos('Safari',getenv('HTTP_USER_AGENT')) > 0) or
           (pos('Firefox',getenv('HTTP_USER_AGENT')) > 0) then
          writeln('Content-Type: application/json; charset=utf-8',#10#13)
        else
          writeln('Content-Type: text/json; charset=utf-8',#10#13);
        p.addChild('success').AsBoolean := false;
        p.addChild('message').AsString := E.Message;;
        write(codifica(p.tojson(0,false)));
        p.free;
      end;
    end;
  finally
     pCCPClient.free;
     OutputStream.free;
  end;
end;

procedure DoRawRemoteCall(Server,Port,ServerPath,ProgramName,MethodName,Entrada:AnsiString;Params: TpXml);
var
  pCCPClient : TpCCPClient;
  BufInOut : TStringStream;
  p: Tpxmlnode;
  LServer,
  LPort: AnsiString;
  Usuario,
  Senha,
  LPid : AnsiString;
  OutPutStream: THandleStream;
  Resposta: TpXml;
  Ch10 : string;
  ext : ansistring;
  TituloJanela : ansistring;
begin
  pCCPClient := TpCCpClient.create(nil);
  OutputStream := THandleStream.Create(STDOUTPUTHANDLE);
  Resposta := TpXml.Create;
  try
    try
      Usuario := Params['userName'].AsString;
      pCCPClient.Params.Values['User'] := Usuario;
      p := Params['sessionKey'];
      LPID := '';
      Senha := '';

      if assigned(p) and (p.asstring > '') then
      begin
        if (Usuario = 'loginpoupex') or (Usuario = 'loginintegracao') then
          Senha := p.AsString
        else begin
          Senha := webDeCrypt(copy(p.AsString,6,255));
          LPID := copy(p.AsString,1,5);
        end;
      end
      else begin
        if Usuario = wini.usuarioWeb then
          Senha :=  '[' + webDeCrypt(wini.tokenWeb) + ']'; //webDeCrypt(wini.tokenWeb);
      end ;
      pCCPClient.Params.Values['Password'] := Senha;


      p := Params['ambienteOperacional'];
      if Params['ambienteOperacional'].AsString = '' then
        raise Exception.Create('Parametro ambienteOperacional é obrigatório');
      if assigned(p) then
      begin
        decodeServerPath(Params['ambienteOperacional'].AsString,LServer,LPort,ServerPath);
        if (LPort > '') then
          pCCPClient.Params.Values['Socket'] := LPort
        else
          pCCPClient.Params.Values['Socket'] := Port;
        if (LServer > '') then
          pCCPClient.Params.Values['Server'] := LServer
        else
          pCCPClient.Params.Values['Server'] := Server;
        pCCPClient.Params.Values['Serverpath'] := ServerPath;
      end;
      Debug.Path := '.';
      Debug.PID := LPID;
      pCCPClient.onDebug := @Debug.write;
      Params.DocumentElement.NodeName := 'PMEMORY';
      BufInOut := TStringStream.Create(Entrada);
      if wini.HUBToken > '' then
        TStream(BufInOut).writeAnsiString(Params.ToJson)
      else
        TStream(BufInOut).writeAnsiString(Params.Code);
      BufInOut.position := 0;
      pCCPClient.exec(Programname+'.'+Methodname,BufInOut);
// writeln('Content-Type: text/html; charset=iso-8859-1'#10);
//writeln(programname+'.'+Methodname);
      Resposta.ParseString(TStream(BufInOut).ReadAnsiString);
//writeln(upstr(Resposta['Tipo'].AsString));

      // novos mimes do link: http://stackoverflow.com/questions/4212861/what-is-a-correct-mime-type-for-docx-pptx-etc

      if Resposta['Nome'].AsString > '' then // se tiver o nome a enviar, usar o #10 só depois do nome
        Ch10 := ''
      else
        Ch10 := #10;
      {
        112369
        se retornar application/xml, o serviço do cliente CDHU reclama que não é text/xml,
        por isso troquei o tipo no wintegracaoCDHU para retornar .TEXT/XML ao invés de .XML.
      }
      case upstr(Resposta['Tipo'].AsString) of
        '.PDF' : writeln('Content-Type: application/pdf;',Ch10);
        '.XML' : writeln('Content-Type: application/xml;',Ch10);
        '.TEXT/XML' : writeln('Content-Type: text/xml;',Ch10);
        '.JPG' : writeln('Content-Type: image/jpeg',Ch10);
        '.JPEG': writeln('Content-Type: image/jpeg',Ch10);
        '.BMP' : writeln('Content-Type: image/bmp;',Ch10);
        '.PNG' : writeln('Content-Type: image/png;',Ch10);
        '.TIF' : writeln('Content-Type: image/tif;',Ch10);
        '.TIFF': writeln('Content-Type: image/tiff;',Ch10);
        '.GIF' : writeln('Content-Type: image/gif;',Ch10);
        '.HTM' : writeln('Content-Type: text/html',Ch10);
        '.HTML': writeln('Content-Type: text/html',Ch10);
        '.RTF' : writeln('Content-Type: text/rtf;',Ch10);
        '.TXT' : writeln('Content-Type: text/plain;',Ch10);
        '.CSV' : writeln('Content-Type: text/csv;',Ch10);
        '.OGG' : writeln('Content-Type: audio/ogg;',Ch10);
        '.MP4' : writeln('Content-Type: video/mp4;',Ch10);
        '.XLSX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',Ch10);
        '.XLTX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.template',Ch10);
        '.POTX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.presentationml.template',Ch10);
        '.PPSX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.presentationml.slideshow',Ch10);
        '.PPTX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.presentationml.presentation',Ch10);
        '.SLDX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.presentationml.slide',Ch10);
        '.DOCX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document',Ch10);
        '.DOTX' : writeln('Content-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.template',Ch10);
        '.XLAM' : writeln('Content-Type: application/vnd.ms-excel.addin.macroEnabled.12',Ch10);
        '.XLSB' : writeln('Content-Type: application/vnd.ms-excel.sheet.binary.macroEnabled.12',Ch10);
        '.XLSM' : writeln('Content-Type: application/vnd.ms-excel.sheet.macroEnabled.12',Ch10);
        '.DOC' : writeln('Content-Type: application/msword',Ch10);
        '.DOT' : writeln('Content-Type: application/msword',Ch10);
        '.XLS' : writeln('Content-Type: application/vnd.ms-excel',Ch10);
        '.XLT' : writeln('Content-Type: application/vnd.ms-excel',Ch10);
        '.XLA' : writeln('Content-Type: application/vnd.ms-excel',Ch10);
        '.PPT' : writeln('Content-Type: application/vnd.ms-powerpoint',Ch10);
        '.POT' : writeln('Content-Type: application/vnd.ms-powerpoint',Ch10);
        '.PPS' : writeln('Content-Type: application/vnd.ms-powerpoint',Ch10);
        '.PPA' : writeln('Content-Type: application/vnd.ms-powerpoint',Ch10);
        '.BIN' : writeln('Content-Type: application/octet-stream',Ch10);
        '.ODT' : writeln('Content-Type: application/vnd.oasis.opendocument.text',Ch10);
        '.OTT' : writeln('Content-Type: application/vnd.oasis.opendocument.text-template',Ch10);
        '.ODS' : writeln('Content-Type: application/vnd.oasis.opendocument.spreadsheet',Ch10);
        '.OTS' : writeln('Content-Type: application/vnd.oasis.opendocument.spreadsheet-template',Ch10);
        '.ODF' : writeln('Content-Type: application/vnd.oasis.opendocument.formula',Ch10);
        '.ODP' : writeln('Content-Type: application/vnd.oasis.opendocument.presentation',Ch10);
        '.ODC' : writeln('Content-Type: application/vnd.oasis.opendocument.chart',Ch10);
        '.ODM' : writeln('Content-Type: application/vnd.oasis.opendocument.text-master',Ch10);
        '.BASE64' : writeln('Content-Type: text/plain;',Ch10);
        '.ZIP': writeln('Content-Type: application/zip',Ch10);
      end;
      if Resposta['Nome'].AsString > '' then begin
         TituloJanela := StringReplace(Resposta['TituloJanela'].AsString,'.',' ',[rfreplaceall]); // não pode ter ponto na string, ou vai confundir com a extensão
         ext := Extractfileext(Resposta['Nome'].AsString); // pega a extensão do arquivo original, para manter o tipo do arquivo
         if trim(TituloJanela) > '' then // Se tem titulo na janela, troca a extensão para o tipo original do arquivo
           TituloJanela := changeFileExt(TituloJanela,ext);
         if (Resposta['DOW'].Asboolean) then begin
            if trim(TituloJanela) > '' then
               writeln('Content-Disposition:attachment; filename="'+TituloJanela+'"'#10)
            else if Params['title'].AsString <> '' then
                writeln('Content-Disposition:attachment; filename="'+Params['title'].AsString+'"'#10)
            else
               writeln('Content-Disposition:attachment; filename="'+Resposta['Nome'].AsString+'"'#10)
         end else
            if trim(TituloJanela)> '' then
               writeln('Content-Disposition: filename="'+TituloJanela+'"'#10)
            else if Params['title'].AsString <> '' then
               writeln('Content-Disposition: filename="'+Params['title'].AsString+'"'#10)
            else
               writeln('Content-Disposition: filename="'+Resposta['Nome'].AsString+'"'#10);
      end;
      flush(output);
        OutputStream.copyFrom(BufInOut,BufInOut.size - BufInOut.position);
    except
      on E:Exception do
      begin
        p := tpxmlnode.create(nil);
        p.nodeName := '';
        writeln('Content-Type: text/html; charset=utf-8',#10#13);
        writeln(ansiToUtf8('<html><head></head><body><h3>Não foi possível gerar o documento.</h3>'));
        if (Params['Nome'].asString > '') and
           (not FileExists(Params['Nome'].AsString)) and
           (pos('Unable to open file',e.message) > 0) then
          writeln(ansiToUtf8('Unable to open file "'+extractFileName(Params['Nome'].AsString)+'"'))
        else
           writeln(ansiToUtf8(e.message));
        writeln('</body></html>');
        p.free;
      end;
    end;
  finally
     pCCPClient.free;
     OutputStream.free;
     Resposta.free;
  end;
end;

function GetBoundary(str:AnsiString):AnsiString;
begin
  result := '';
  i := pos('boundary=',str);
  if (i>=0) then
    result := copy(str,i+9,MaxInt);
end;

function ValidaMetodo(ProgramName, MethodName : AnsiString):boolean;
var
  i: integer;
  permite : boolean;
  st, 
  metodo,
  programa : ansistring;
begin
  permite := false;
  if wini.metodosPermitidos > '' then begin
    for i := 1 to NumPalavras(wini.metodosPermitidos, ';', #255, #255) do begin
      st := palavra(wini.metodosPermitidos, i, ';', #255, #255);
      if pos('/', st) > 0 then begin
        programa := palavra(st, 1, '/', #255, #255);
        metodo := palavra(st, 2, '/', #255, #255);
        if (programa = ProgramName) and (metodo = MethodName) then
          permite := true;
      end;
    end;
    if permite then 
      result := true
    else begin
      result := false;
      writeln('Content-Type: text/html; charset=utf-8');
      writeln('Status: 403 Forbidden');
      writeln(#10#13);
      writeln('<h1>Forbidden</h1>');
    end;
  end else
    result := true;
end;

procedure DecodeParamsToNode(Entrada: AnsiString; Node: TpXmlNode);
var
  params: TpXml;
begin
  params := TpXml.create;
  try
    DecodeParams(Entrada, Params);
    if (assigned(Params['PMemory'])) and (Params['PMemory'].isArray) then begin
      Node.assignAttributesAndChildren(Params['PMemory']);
      Node.isArray := true;
    end else
      Node.assignAttributesAndChildren(Params.DocumentElement);
  finally
    params.free;
  end;
end;

procedure IncluiHeaders(Node : TpXmlNode);
var
  i : integer;
  nome,
  valor: AnsiString;
begin
  for i := 0 to EnvVars.count - 1 do begin
    if pos('HTTP_', EnvVars[i]) = 1 then begin
      nome := palavra(EnvVars[i], 1, '=', #255, #255);
      valor := EnvVars.values[nome];
      nome := copy(Nome, 6, length(Nome)); //remover o HTTP_
      nome := StringReplace(Nome,'_','-',[rfReplaceAll]); //substitui todos os _ por -
      Node.add(nome).asString := valor;
    end;
  end;
end;

var
  PathInfo,
  ContentType : AnsiString;
  RequestMethod,
  MethodName,
  ProgramName,
  Server,
  ServerPath,
  Contexto,
  Port: AnsiString;
  P: TpXmlNode;
  Params: TpXml;
  f: file;
  Tamanho,
  Posicao,
  TamanhoFaltando,
  TamanhoLido: Integer;
  ParamsStr: AnsiString;
  EstaCripto: Boolean;
  Cookies : TStringList;
begin
  LeConfig(Server,Port,Contexto,wini);
  Debug := TDebug.Create;
  EstaCripto := false;
  // set a cookie (must come before content-type line below)
  // don't forget to change the expires date
  //writeln('Set-cookie:widget=value; path=/; expires= Mon, 21-Mar-2005  18:37:00 GMT');
{
  // demonstrate get cookies
  a:= GetEnv('HTTP_COOKIE');
//  writeln('cookies:',a);
 
}
{  // demonstrate GET result
  a:='';
  a:= GetEnv('QUERY_STRING');
  writeln('GET: ',a);
}  

  try
    // for I := 0 to GetEnvironmentVariableCount-1 do 
    // begin
    //  debug.write(GetEnvironmentString(I));
    // end;
    PathInfo := GetEnv('Path_Info');
    DecodeProgramNameAndMethod(PathInfo,ProgramName,MethodName);
    ServerPath := GetServerPath(PathInfo);
    RequestMethod := GetEnv('REQUEST_METHOD');
    ContentType := GetEnv('CONTENT_TYPE');
    if (wini.HUBToken > '') and (wini.HUBToken <> GetEnv('http_prognum_hub_token')) then begin
      writeln('Content-Type: text/html; charset=utf-8');
      writeln('Status: 401 Unauthorized');
      writeln(#10#13);
      writeln('<h1>Unauthorized</h1>');
      exit;
    end;
    if criptografa and (RequestMethod <> 'POST') then
       raise Exception.Create('Requisição inválida');
    // Lê a entrada
    Entrada := '';
    tamanhoLido := 0;
    if  GEtEnv('CONTENT_LENGTH') > '' then
    begin
      Tamanho := strtoint( GEtEnv('CONTENT_LENGTH'));
      if Tamanho > 0 then
      begin
        FileMode := fmOpenRead;
        assignfile(f,'');
        reset(f,1);
        setlength(Entrada,tamanho);
        posicao := 1;
        tamanhoFaltando := tamanho;
        repeat 
          blockread(f,Entrada[posicao],tamanhofaltando,tamanhoLido);
          posicao := posicao + tamanhoLido;
          tamanhofaltando := tamanhofaltando - tamanhoLido;
        until tamanhoFaltando=0;
        close(f);
      end;
    end;
    if (copy(entrada,1,4) = '____') then begin
      Entrada := utf8toansi(DescriptografaAES(Entrada));
      EstaCripto := true;
    end
    else
    begin  // Só é permitido em modo de desenvolvimento sem criptografia
      if criptografa and (copy(ContentType,1,9) <> 'multipart') then
          raise Exception.Create('Requisição inválida');
      if (GetEnv('CONTENT_TYPE')='application/octet-stream') then begin
        Entrada := utf8toansi(Entrada);
      end;
    end;
    Params := TpXml.Create;
    try
      ParamsStr := GetEnv('HTTP_APPLICATION_DATA');
      if ParamsStr = '' then begin
        ParamsStr := convBarraU(GetEnv('QUERY_STRING'));
      end;
      if (copy(ParamsStr,1,4) = '____') then begin
        ParamsStr := utf8toansi(DescriptografaAES(ParamsStr));
      end;

      if EstaCripto then
        if wini.HUBToken > '' then
          DecodeParamsToNode(Entrada, Params.add('corpo_req'))
        else
          DecodeParams(Entrada,Params);

      DecodeParams(ParamsStr,Params);

      if (requestMethod <> 'GET') and (copy(ContentType,1,9) <> 'multipart') then
        DecodeParams(Entrada,Params);
      if trim(GetEnv('HTTP_userName')) > '' then
        Params.addOrGet('USERNAME').asstring := GetEnv('HTTP_userName');
      if trim(GetEnv('HTTP_sessionKey')) > '' then
        Params.addorGet('SESSIONKEY').asstring := GetEnv('HTTP_sessionKey');
      if trim(GetEnv('HTTP_ambienteOperacional')) > '' then
        Params.addOrGet('AMBIENTEOPERACIONAL').asstring := GetEnv('HTTP_ambienteOperacional');
      if trim(GetEnv('HTTP_username')) > '' then
        Params.addOrGet('USERNAME').asstring := GetEnv('HTTP_username');
      if trim(GetEnv('HTTP_sessionkey')) > '' then
        Params.addorGet('SESSIONKEY').asstring := GetEnv('HTTP_sessionKey');

      Params.Add('REMOTE_ADDR').AsString := GetEnv('REMOTE_ADDR');
      Cookies := TStringList.Create;
      Cookies.delimiter := ';';
      Cookies.delimitedText := delSpace(getEnv('HTTP_COOKIE'));

      if trim(Params['USERNAME'].asString) = '' then
        Params.addOrGet('USERNAME').asString := cookies.values['userName'];
      if trim(Params['AMBIENTEOPERACIONAL'].asString) = '' then
        Params.addorget('AMBIENTEOPERACIONAL').asString := cookies.values['ambienteOperacional'];
      if trim(Params['SESSIONKEY'].asString) = '' then
        Params.addorget('SESSIONKEY').asString := cookies.values['sessionKey'];
      if trim(Params['CONTEXTO'].asString) = '' then
        Params.addorget('CONTEXTO').asString := cookies.values['contexto'];
      if assigned(Params['requestMethod']) then 
        RequestMethod := Params['requestMethod'].AsString;
      if assigned(Params['programName']) then
        ProgramName := params['programName'].AsString;
      if assigned(Params['methodName']) then
        MethodName := params['methodName'].AsString;
      if (length(MethodName)>0) then MethodName[1] := UpCase(MethodName[1]);

      if (wini.HUBToken > '') then begin
        Params.add('query_string').asString := GetEnv('QUERY_STRING');
        Params.addorget('USERNAME').asString := 'loginintegracao';
        Params.addorget('SESSIONKEY').asString := wini.HUBSessionKey;
        Params.add('url_whub').asString := GetEnv('SERVER_NAME')+GetEnv('REQUEST_URI');
        if GetEnv('http_prognum_hub_integration') > '' then
          Params.add('NU_INTEGRACAO').asInteger := StrToInt(GetEnv('http_prognum_hub_integration'))
        else
          raise exception.create('Necessário informar o código da integração.');
        IncluiHeaders(Params.add('headers'));
      end;

      if      (RequestMethod = 'GET')    then MethodName := 'Get' + MethodName
      else if (RequestMethod = 'POST')   then MethodName := 'Post' + MethodName
      else if (RequestMethod = 'PUT')    then MethodName := 'Put' + MethodName
      else if (RequestMethod = 'DELETE') then MethodName := 'Delete' + MethodName
      else if (RequestMethod = 'HEAD')   then MethodName := 'Head' + MethodName
      else if (RequestMethod = 'OPTIONS')then MethodName := 'Options' + MethodName;

      //validar o ambiente informado contra a definição no w.ini
      if wini.ambienteOperacional > '' then begin
        if (length(params['AMBIENTEOPERACIONAL'].asString)>0) and 
           (copy(params['AMBIENTEOPERACIONAL'].asString,length(params['AMBIENTEOPERACIONAL'].asString),length(params['AMBIENTEOPERACIONAL'].asString))='/') then
          params['AMBIENTEOPERACIONAL'].asString := copy(params['AMBIENTEOPERACIONAL'].asString,1,length(params['AMBIENTEOPERACIONAL'].asString)-1);
        if (length(wini.ambienteOperacional)>0) and 
          (copy(wini.ambienteOperacional,length(wini.ambienteOperacional),length(wini.ambienteOperacional))='/') then
          wini.ambienteOperacional := copy(wini.ambienteOperacional,1,length(wini.ambienteOperacional)-1);
        if params['AMBIENTEOPERACIONAL'].asString = '' then
          params.AddOrGet('AMBIENTEOPERACIONAL').asString := wini.ambienteOperacional
        else if params['AMBIENTEOPERACIONAL'].asString <> wini.ambienteOperacional then
          raise Exception.Create('Ambiente operacional inválido.');
      end;
      if Params['USERNAME'].asString = '' then
        Params.addorget('USERNAME').asString := wini.usuarioWeb;
      if ValidaMetodo(ProgramName, MethodName) then
        if copy(ContentType,1,9) = 'multipart' then
          DoMultiPartRemoteCall(Server,Port,ServerPath,ProgramName,MethodName,Entrada,Params,GetBoundary(ContentType))
        else
          DoRawRemoteCall(Server,Port,ServerPath,ProgramName,MethodName,Entrada,Params);
  {
  // Variáveis de ambiente
    writeln('Environment');
    for I := 0 to GetEnvironmentVariableCount-1 do 
    begin
      writeln(GetEnvironmentString(I));
    end;
  }
    finally
      Params.free;
      Cookies.free;
    end;
  except
    on E:Exception do
    begin
      p := tpxmlnode.create(nil);
      p.nodeName := '';
      p.addChild('success').AsBoolean := false;
      p.addChild('message').AsString := E.Message;
      writeln('Content-Type: application/json; charset=utf-8',#10#13);
      writeln(ansiToUtf8(p.tojson(0,false)));
      p.free;
    end;
  end;
  Debug.free;
end.
