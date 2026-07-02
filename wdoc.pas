program wdoc;

{ Programa para acessar o módulo de documentos do SCCI }

{$V+}
{$H-}


{$IFDEF FPC}
{$P+}
{$ENDIF}

{$IFDEF MSWINDOWS}
{$M 1638400,104857600}
{$ENDIF}

uses
  {$IFDEF MSWINDOWS} pIniFiles, Winsock, ScktComp,windows,dialogs,ZLib,{$ENDIF}
  {$IFDEF KYLIX}  Libc, ZLib, IdGlobal, {$ENDIF}
  {$IFDEF FPC} cthreads, {$ENDIF}punix, Classes, SysUtils,lib1, implib, scislib, wlmemory, pxmllib, oserver, pdb, DB,xdb,
  bdlib, scciio, XMLDataset, wsistarqlib, aelib,
  smv, sccidef, sccilib, ctrlib,apiscci,synautil,
  stringtransf, datalib, ucontrato, sccisqldef,
  uloglib, urelatorios,  sisatlib, wldoc, umerge, apilib, 
   upretobjs, apifcvs, dadospretendlib,pmerge;
  
const
{$IFDEF LINUX}
        DIR_SEP = '/';
{$ELSE}
        DIR_SEP = '\';
{$ENDIF}

procedure processaPermissoes(usuario:AnsiString; no: TpXmlNode);
var
  i: integer;
begin
  if assigned(no) then // Verifica todos os nós filhos
  begin
    i := 0;
    while (i < no.count) do
    begin
      if (no[i].attributes['permissao'] > '') and 
         (not usuarioTemPerm(usuario,valint(no[i].Attributes['permissao']))) then
      begin // Se o usuário não tem permissão
        no[i].free;
      end
      else
      begin
        processaPermissoes(usuario,no[i]);
        inc(i);
      end;
    end;
  end;
end;

function EImagem(ext : string) : boolean;
begin
  ext := lowercase(ext);
  result := (ext = '.bmp') or
            (ext = '.jpg') or
            (ext = '.jpeg') or
            (ext = '.tif') or
            (ext = '.tiff') or
            (ext = '.tif') or
            (ext = '.gif') or
            (ext = '.png');
end;

function EPDF(ext : string) : boolean;
begin
  ext := lowercase(ext);
  result := ext = '.pdf';
end;

function EHTML(ext : string) : boolean;
begin
  ext := lowercase(ext);
  result := (ext = '.html') or
            (ext = '.htm');
end;

{
function ERTM(ext : string) : boolean;
begin
  ext := lowercase(ext);
  result := ext = '.rtm';
end;
}

procedure GetDocumento (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  ID: Integer;
  NomeDocumento,
  TituloJanela,
  FileNameFinal : AnsiString;
  Aux: String;
  Ctr,
  NuOperacao : String;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  TituloJanela := '';
  Ctr := '';
  NuOperacao := '';
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    NomeDocumento := jsonIn['NomeDocumento'].AsString;
    if NomeDocumento = '' then
      NomeDocumento := jsonIn['nomeDocumento'].AsString;
    if NomeDocumento <> '' then
    begin
      NomeDocumento := StringReplace(NomeDocumento,'\','/',[rfReplaceAll]);
      if copy(NomeDocumento,1,1) <> '/' then NomeDocumento := '/' + NomeDocumento;
      ID := LeIDdoPath(GetSqlConnection(PegaDirTab),NomeDocumento,0);
    end
    else 
      ID := jsonIn['ID'].AsInteger;
    if (not assigned(jsonIn['MODULO_DOCUMENTOS'])) or (not lib1.StrToBool(jsonIn['MODULO_DOCUMENTOS'].asString)) then
      ValidaPermissaoUsuarioDocumento(ID,jsonIn['userName'].asString,jsonIn['CO_CONTRATO'].asString,jsonIn['sessionKey'].asString);
    streamout.size := 0;
    NomeDocumento := StringReplace(RemoveAcento(ExtractFileName(NomeDocumento)),' ','_',[rfReplaceAll]);
    aux := ExtractFileExt(NomeDocumento);
    delete(NomeDocumento,pos(aux,NomeDocumento),length(NomeDocumento));
    if trim(jsonIn['NU_PRETENDENTE'].AsString) > '' then
      TituloJanela := intstr(valint(jsonIn['NU_PRETENDENTE'].asstring))+ '_'+NomeDocumento;
    if trim(jsonIn['NU_OPERACAO'].AsString) > '' then
      TituloJanela := intstr(valint(jsonIn['NU_OPERACAO'].asstring))+ '_'+NomeDocumento;

    if assigned(jsonIn['CO_CONTRATO']) and 
       (jsonIn['CO_CONTRATO'].asString>'') then 
      Ctr := jsonIn['CO_CONTRATO'].asString;
    if assigned(jsonIn['NU_OPERACAO']) and
       (jsonIn['NU_OPERACAO'].asString>'') then
      NuOperacao := jsonIn['NU_OPERACAO'].asString
    else if assigned(jsonIn['NU_PRETENDENTE']) and
            (jsonIn['NU_PRETENDENTE'].asString>'') then
      NuOperacao := jsonIn['NU_PRETENDENTE'].asString;
    FileNameFinal := DefineNomeArqDonwload(Ctr,NuOperacao,'',ExtractFileName(NomeDocumento));
    if (TituloJanela > '') then
      GetDocumentoPorId(ID,StreamOut,false {emPdf},false {Download},FileNameFinal {FileName},TituloJanela)
    else
      GetDocumentoPorId(ID,StreamOut,false);
  finally
    jsonIn.Free;
  end;
end;

procedure GetDocumentoPorIdVersao(Id:longint;Versao:integer;StreamOut:TStream;emPdf: boolean);
var
  Qry          : TSqlQuery;
  Listaout     : TScciMemory;
  fileNameFS   : TFileName;
  FileStream   : TFileStream;
  MemoryStream : TMemoryStream;
  NomeArq,
  FileNamePdf,
  FileNameErr,
  Ext          : AnsiString;
  StreamArq    : TStream;
begin
  NomeArq := MakeTempFileName;
  NomeArq :=  ChangeFileExt(NomeArq,'.html');
  FileNamePdf := ChangeFileExt(NomeArq,'.pdf');
  FileNameErr := ChangeFileExt(NomeArq,'.err');
//  StreamArq.free;
  Qry := TSqlQuery.create(nil);
  ListaOut := TScciMemory.Create;
  try
    scislib.AbreConexao;
    Qry.SqlConnection := SCISConnection;
    Qry.Sql.Text := 'select c.nome,s.nome as NomeSistarq,nu_copias,versao,dado,compactado,tp_gravacao,co_hierarquia_documento from controleversao c,sistarq s '+
                    'where (s.id = :id) and (c.id = s.id) and (c.versao = :versao)'+
                    'order by versao desc';
    Qry.params[0].asinteger := Id;
    Qry.params[1].asinteger := Versao;
    Qry.Open;
    if not Qry.isempty then
    begin
      // Parte 1: Retorna o tipo do documento
      if Qry.FieldByName('NOME').asstring <> '' then begin
         ListaOut.addval('Nome',Qry.FieldByName('NOME').asstring);
         Ext := extractfileext(Qry.FieldByName('NOME').asstring);
      end else begin
        ListaOut.addval('Nome',Qry.FieldByName('NOMESISTARQ').asstring);
        Ext := extractfileext(Qry.FieldByName('NOMESISTARQ').asstring);
      end;
      //if not TipoTemVisualizacao(Ext) then
        //raise exception.create('Visualização não disponível para este tipo de documento');
      if EmPdf and EHtml(Ext) then 
        ListaOut.Addval('Tipo','.pdf')
      else
        ListaOut.addval('Tipo',Ext);
      ListaOut.SaveToStreamWithSize(StreamOut);
  
      // Parte 2: Retorna o binário do arquivo
      if EmPdf and EHTML(Ext) then
      begin
        StreamArq := TFileStream.Create(NomeArq,fmCreate);
      end
      else
        StreamArq := StreamOut;
      try  
        if Qry.fieldbyname('Compactado').asstring = BooleanToSqlboolean(true) then begin
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
            FileStream := TFileStream.create(filenameFS,FmOpenRead);
            try
              DescompactaStream(FileStream,StreamArq);
            finally
              FileStream.free;
            end;
          end
          else begin
            MemoryStream := TMemoryStream.create;
            try
              TBlobField(Qry.fieldbyname('dado')).savetostream(MemoryStream);
              DescompactaStream(MemoryStream,StreamArq);
            finally
              MemoryStream.free;
            end;
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
            FileStream := TFileStream.create(filenameFS,FmOpenRead);
            try
              StreamArq.CopyFrom(FileStream,0);
            finally
              FileStream.free;
            end;
          end
          else
          begin
            TBlobField(Qry.fieldbyname('dado')).savetostream(StreamArq);
          end;
        end;
      finally
        if EmPdf and EHtml(Ext) then
          FreeAndNil(StreamArq);
      end;
      if EmPdf and EHtml(Ext) then // Converte html em pdf
      begin
        scciio.ConverteHtmlEmPdf(NomeArq,FileNamePdf,FileNameErr);
         FileStream := TFileStream.Create(FileNamePdf,fmOpenRead);
        try
          // Parte 2: Retorna o binário do arquivo
          StreamOut.CopyFrom(FileStream,0);
        finally
          if (NomeArq > '') and FileExists(NomeArq) then
            deletefile(NomeArq);
          if (filenamePdf > '') and FileExists(FilenamePDF) then
            deletefile(filenamePdf);
          if (FileNameErr > '') and FileExists(FileNameErr) then
            deletefile(filenameErr);
          freeAndNil(FileStream);
        end;
      end;
    end
    else 
    begin  // O Documento não foi encontrado
      // como o sccidoc já trata a excessão com uma tela certinha
      // alterei para não responder um html e sim abortar
      // se algum outro lugar estiver usando esta rotina fora do sccidoc
      // pode ser necessário voltar atrás
      raise exception.create('Visualização não disponível');

{
      // Parte 1: Retorna o tipo do documento
      ListaOut.addval('Nome',Qry.FieldByName('NOME').asstring);
      ListaOut.addval('Tipo','.html');
      ListaOut.SaveToStreamWithSize(StreamOut);
      Resposta := '<html><head/><body><t2>Visualização não disponível</t2></body></html>';
      StreamOut.writebuffer(Resposta[1],length(Resposta));
}
    end;
    Qry.close;
  finally
    Qry.free;
    ListaOut.Free;
  end;
end;
  
procedure GetDocumentoVersao (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  ID: longint;
  Versao : integer;
  NomeDocumento: AnsiString;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    NomeDocumento := jsonIn['NomeDocumento'].AsString;
    if NomeDocumento = '' then
      NomeDocumento := jsonIn['nomeDocumento'].AsString;
    if NomeDocumento <> '' then
    begin
      NomeDocumento := StringReplace(NomeDocumento,'\','/',[rfReplaceAll]);
      if copy(NomeDocumento,1,1) <> '/' then NomeDocumento := '/' + NomeDocumento;
      ID := LeIDdoPath(GetSqlConnection(PegaDirTab),NomeDocumento,0);
      Versao := 1;
    end
    else begin
      ID := jsonIn['ID'].AsInteger;
      Versao := jsonIn['VERSAO'].AsInteger;
    end;
    streamout.size := 0;
    GetDocumentoPorIdVersao(ID,Versao,StreamOut,false);
  finally
    jsonIn.Free;
  end;
end;

procedure GetDocumentoEmPdf (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
//  Qry : TSqlQuery;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    streamout.size := 0;
    GetDocumentoPorId(jsonIn['ID'].AsInteger,StreamOut,true);
  finally
    jsonIn.Free;
  end;
end;

procedure GetRelatorioPdf( StreamIn, StreamOut : TStream);
// Parametros de entrada
// id
// numeroSaida - Se existir mais de um relatório na saída deverá ser passado o número da saída
var
  ListaIn, 
  ListaOut : TpMemory;
  Usuario : ansistring;
  Qry : TsqlQuery;
  ID : longint;
  Relatorio : TRelatorioGenerico;
  Erro : TStringStream;
  CodTxt : string;
  RegTexto : TpTexto;
  FileName,
  FileNamePdf,
  FileNameErr : AnsiString;
  FileStream: TFileStream;
  NumeroSaida: Integer;
  TamFonte : integer;
  Retrato : boolean;
begin
  AbreTabTxt(PegaDirTab);
  AbreTabImp(PegaDirTab);
  Retrato := false;
  Tamfonte := 5;
  Listain := TpMemory.Create;
  ListaOut := TpMemory.Create;
  Qry := TSqlQuery.create(nil);
  try
    RegTexto := Default(TpTexto);
    ListaIn.LoadFromStreamWithSize(StreamIn);
    usuario := Listain.readval('userName');
    ID := ListaIn.readint('id');
    NumeroSaida := ListaIn.readint('numeroSaida');
    Qry.SqlConnection := getSqlConnection(PegaDirTab);
    Qry.sql.add('SELECT RELATORIO,DIRETORIO,ERRO,EXITCODE,FIM FROM ANDAMENTO_RELATORIO');
    Qry.sql.add('WHERE (USUARIO=:USUARIO) AND (ID = :ID)');
    Qry.ParamByName('Usuario').asstring := usuario;
    Qry.ParamByName('ID').asinteger := ID;
    Qry.Open;     
    if Qry.isempty then
      raise exception.create('Relatório inexistente.');    
    if qry.fieldbyname('FIM').isNull then 
      raise exception.create('Relatório ainda não foi concluído.')
    else if qry.fieldbyname('EXITCODE').asinteger > 0 then 
    begin
      if Qry.FieldByName('Erro').isNull then 
        raise exception.create('Erro desconhecido.')
      else 
      begin
        Erro := TStringStream.create('');
        try
          TBlobField(Qry.FieldByName('ERRO')).SaveToStream(Erro);
            raise exception.create('O seguinte erro ocorreu durante a execução do relatório:'+#13+Erro.DataString);
        finally
          erro.free;
        end;
      end;
    end
    else 
    begin
      Relatorio := TRelatorioGenerico.create(Qry.FieldByName('RELATORIO').asstring);
      try
        if Relatorio.TipoRelat = tipoRelat_Texto then begin 
          if NumeroSaida > Relatorio.SaidasXml.Count - 1 then
          begin
            raise exception.create('Foi solicitada a saída de número '+inttostr(NumeroSaida) +
                                   ' mas só existem saídas até o número '+inttostr(Relatorio.SaidasXml.Count-1));
          end
          else
          begin
            if uppercase(Relatorio.SaidasXml[NumeroSaida].NodeName) = 'ARQUIVO' then 
            begin
              // Relatorio.SaidasXml[NumeroSaida].attributes['Titulo'];
              // Relatorio.SaidasXml[NumeroSaida].attributes['Comando'];
              // Relatorio.SaidasXml[NumeroSaida].attributes['Tipo'];
              // Relatorio.SaidasXml[NumeroSaida].Attributes['nome'];
              if uppercase(Relatorio.SaidasXml[NumeroSaida].attributes['Tipo']) = 'RTM' then 
              begin
                raise exception.create('Não é possível visualizar relatórios RTM');
              end
              else 
              begin
                FileName := Qry.FieldByname('DIRETORIO').asstring + DIR_SEP +
                                               Relatorio.SaidasXml[NumeroSaida].Attributes['nome'];
                CodTxt := Relatorio.SaidasXml[NumeroSaida].Attributes['CodTxt'];
                if trim(CodTxt) = '' then
                  CodTxt := Relatorio.CodTxt;
                if CodTxt > '' then
                  LeTexto(CodTxt,RegTexto)
                else
                  Fillchar(RegTexto,sizeof(TpTexto),0);
                if RegTexto.Codigo > '' then 
                begin
                  // BoolToStr(RegTexto.AutoAjuste);
                  Retrato := RegTexto.Retrato;
                  TamFonte := RegTexto.TamanhoDaFonte;
                  // inttostr(RegTexto.MargemSuperior);
                  // inttostr(RegTexto.MargemEsquerda);
                  // RegTexto.TipoPapel;
                  // inttostr(RegTexto.QtdeLinhas);
                end
                else 
                begin
                  // Relatorio.SaidasXml[NumeroSaida].Attributes['AutoAjuste'];
                  // trim(Relatorio.SaidasXml[NumeroSaida].Attributes['TamanhoDaFonte']);
                  // Relatorio.SaidasXml[NumeroSaida].Attributes['Retrato'];
                  // trim(Relatorio.SaidasXml[NumeroSaida].Attributes['MargemSuperior']);
                  // trim(Relatorio.SaidasXml[NumeroSaida].Attributes['MargemEsquerda']);
                  // Relatorio.SaidasXml[NumeroSaida].Attributes['TipoPapel'];
                  // trim(Relatorio.SaidasXml[NumeroSaida].Attributes['QtdeLinhas']);
                end;

                if uppercase(Relatorio.SaidasXml[NumeroSaida].attributes['ConverteParaPDF']) = 'F' then begin
                  FileStream := TFileStream.Create(FileName,fmOpenRead);
                  try
                    // Parte 1: Retorna o nome e o tipo do arquivo
                    ListaOut.addval('Nome',FileName);
                    ListaOut.addval('Tipo',extractfileext(FileName));
                    ListaOut.SaveToStreamWithSize(StreamOut);
                    // Parte 2: Retorna o binário do arquivo
                    StreamOut.CopyFrom(FileStream,0);
                  finally
                    FileStream.free;
                  end;
                end
                else begin
                  FileNamePdf := FileName+ '.pdf';
                  FileNameErr := FileName+ '.erroconvpdf';

                  apifcvs.ConverteTxtEmPdf(FileName,FileNamePdf,FileNameErr,'',Tamfonte,Retrato);
                  FileStream := TFileStream.Create(FileNamePdf,fmOpenRead);
                  try
                    // Parte 1: Retorna o nome e o tipo do arquivo
                    ListaOut.addval('Nome',FileNamePdf);
                    ListaOut.addval('Tipo',extractfileext(FileNamePdf));
                    ListaOut.SaveToStreamWithSize(StreamOut);
                    // Parte 2: Retorna o binário do arquivo
                    StreamOut.CopyFrom(FileStream,0);
                  finally
                    if (filenamePdf > '') and FileExists(FilenamePDF) then
                      deletefile(filenamePdf);
                    if (FileNameErr > '') and FileExists(FileNameErr) then
                      deletefile(filenameErr);
                    FileStream.free;
                  end;
                end;
              end;
            end;
          end;
        end
        else
          raise exception.create('Tipo de relatório não suportado');
      finally
        Relatorio.free;
      end;
    end;

  finally
    ListaOut.free;
    Qry.free;
    ListaIn.Free;
  end;
end;

procedure GetRelatorioCsv( StreamIn, StreamOut : TStream);
// Parametros de entrada
// id
// numeroSaida - Se existir mais de um relatório na saída deverá ser passado o número da saída
var
  ListaIn, 
  ListaOut : TpMemory;
  Usuario : ansistring;
  Qry : TsqlQuery;
  ID : longint;
  Erro : TStringStream;
  FileName,
  FileNameErr,
  FilePathName,
  FileNameBD,
  ApiKeyS3 : AnsiString;
  FileStream: TFileStream;
  //NumeroSaida: Integer;
  Diretorio : ansistring;
  IDSISTARQ : integer;
  Formato : String;
begin
  AbreTabTxt(PegaDirTab);
  AbreTabImp(PegaDirTab);
  Listain := TpMemory.Create;
  ListaOut := TpMemory.Create;
  Qry := TSqlQuery.create(nil);
  ApiKeyS3 := '';
  try
    ListaIn.LoadFromStreamWithSize(StreamIn);
    usuario := Listain.readval('userName');
    ID := ListaIn.readint('id');
    Formato := ListaIn.readval('FORMATO');
    //NumeroSaida := ListaIn.readint('numeroSaida');
    Qry.SqlConnection := getSqlConnection(PegaDirTab);
    Qry.sql.add('SELECT RELATORIO,DIRETORIO,ERRO,EXITCODE,FIM,TITULO,CO_LOCAL_EXP FROM ANDAMENTO_RELATORIO');
    Qry.sql.add('WHERE (USUARIO=:USUARIO) AND (ID = :ID)');
    Qry.ParamByName('Usuario').asstring := usuario;
    Qry.ParamByName('ID').asinteger := ID;
    Qry.Open;     
    if Qry.isempty then
      raise exception.create('Relatório inexistente.');    
    if qry.fieldbyname('FIM').isNull then 
      raise exception.create('Relatório ainda não foi concluído.')
    else if qry.fieldbyname('EXITCODE').asinteger > 0 then 
    begin
      if Qry.FieldByName('Erro').isNull then 
        raise exception.create('Erro desconhecido.')
      else 
      begin
        Erro := TStringStream.create('');
        try
          TBlobField(Qry.FieldByName('ERRO')).SaveToStream(Erro);
            raise exception.create('O seguinte erro ocorreu durante a execução do relatório:'+#13+Erro.DataString);
        finally
          erro.free;
        end;
      end;
    end
    else begin
      FileName := Qry.FieldByname('RELATORIO').asstring;
      if Formato='CSV' then 
        FileName := FileName + '.csv'
      else if Formato='XLS' then
        FileName := FileName + '.xls'
      else
        FileName := FileName + '.csv';
      Diretorio := Qry.FieldByname('DIRETORIO').asstring;
      try
        if (Qry.FieldByname('CO_LOCAL_EXP').asstring = 'S3') or (Qry.FieldByname('CO_LOCAL_EXP').asstring = 'BD') then begin
          FilePathName := LocalizaArquivoExportado(ID,'',UpStr(Listain.readval('modulo')));
          if FilePathName <> FileName then begin
            FileStream := TFileStream.Create(FilePathName,fmOpenRead or fmShareDenyNone);
            ListaOut.addval('Nome',ExtractFileName(FileName));
            ListaOut.addval('Tipo',extractfileext(FileName));
            ListaOut.SaveToStreamWithSize(StreamOut);
            StreamOut.CopyFrom(FileStream,0);
          end;
        end 
        else if pos('SISTARQ:',Diretorio) > 0 then begin
          try
            IDSISTARQ := strtoint(stringreplace(Diretorio,'SISTARQ:','',[rfReplaceAll]));
            //FileStream := TFileStream.Create(Qry.FieldByname('DIRETORIO').asstring + DIR_SEP +FileName,fmOpenRead);     
            GetDocumentoPorId(IDSISTARQ,StreamOut,false,true,FileName,'',Formato='XLS');  
          except
            raise Exception.Create('Não foi possível obter o arquivo e/ou diretório');
          end;
        end;
      except on
        e : exception do raise Exception.Create('Erro ao recuperar arquivo: '+e.message);
      end;
    end;
  finally
    ListaOut.free;
    Qry.free;
    ListaIn.Free;
  end;
end;

procedure GetSaidaRelatorio( StreamIn, StreamOut : TStream);
// Parametros de entrada
// id
var
  ListaIn,
  ListaOut : TpMemory;
  Usuario : ansistring;
  Qry : TsqlQuery;
  ID : longint;
  Erro : TStringStream;
  FileStream: TFileStream;
  IDSISTARQ : integer;
  Diretorio : ansistring;
  EmPdf,
  Download : boolean;
begin  
  AbreTabTxt(PegaDirTab);
  AbreTabImp(PegaDirTab);
  Listain := TpMemory.Create;
  ListaOut := TpMemory.Create;
  Qry := TSqlQuery.create(nil);
  try
    ListaIn.LoadFromStreamWithSize(StreamIn);
    usuario := Listain.readval('userName');
    ID := ListaIn.readint('id');
    if ListaIn.readval('EMPDF') > '' then 
      EmPdf := ListaIn.readBool('EMPDF')
    else  
      EmPdf := false;
    if ListaIn.readval('DONWLOAD') > '' then 
      Download := ListaIn.readBool('DONWLOAD')
    else  
      Download := true;  
    //NumeroSaida := ListaIn.readint('numeroSaida');
    Qry.SqlConnection := getSqlConnection(PegaDirTab);
    Qry.sql.add('SELECT RELATORIO,DIRETORIO,ERRO,EXITCODE,FIM,TITULO FROM ANDAMENTO_RELATORIO');
    Qry.sql.add('WHERE (USUARIO=:USUARIO) AND (ID = :ID)');
    Qry.ParamByName('Usuario').asstring := usuario;
    Qry.ParamByName('ID').asinteger := ID;
    Qry.Open;
    if Qry.isempty then
      raise exception.create('Relatório inexistente.');
    if qry.fieldbyname('FIM').isNull then
      raise exception.create('Relatório ainda não foi concluído.')
    else if qry.fieldbyname('EXITCODE').asinteger > 0 then
    begin
      if Qry.FieldByName('Erro').isNull then
        raise exception.create('Erro desconhecido.')
      else
      begin
        Erro := TStringStream.create('');
        try
          TBlobField(Qry.FieldByName('ERRO')).SaveToStream(Erro);
            raise exception.create('O seguinte erro ocorreu durante a execução do relatório:'+#13+Erro.DataString);
        finally
          erro.free;
        end;
      end;
    end
    else begin
      Diretorio := Qry.FieldByname('DIRETORIO').asstring;
      IDSISTARQ := strtoint(stringreplace(Diretorio,'SISTARQ:','',[rfReplaceAll]));
      GetDocumentoPorId(IDSISTARQ,StreamOut,EmPdf{emPdf},Download{Download});
    end;
  finally
    ListaOut.free;
    Qry.free;
    ListaIn.Free;
  end;
end;

function DescricaoCheckListDoc(NuOperacao,NuDocumento : integer) : ansistring;
var
  Qry : TSqlQuery;
begin
  result := '';

  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(pegaDirTab);
    Qry.sql.add('select DOC.NU_DOCUMENTO, DOC.NU_PESSOA, PP.NO_PESSOA , DOC.NU_GRUPO_DOCUMENTO,');
    Qry.sql.add('       DOC.NU_DOCUMENTO_GRUPO_DOC, DGO.NO_DOCUMENTO as NO_DOCUMENTO_GRUPO, DOC.NO_DOCUMENTO');
    Qry.sql.add('from documento_operacao DOC');
    Qry.sql.add('LEFT JOIN documento_grupo_documento DGO');
    Qry.sql.add('   ON (  (DOC.NU_GRUPO_DOCUMENTO = DGO.NU_GRUPO_DOCUMENTO)  AND');
    Qry.sql.add('         (DOC.NU_DOCUMENTO_GRUPO_DOC = DGO.NU_DOCUMENTO_GRUPO_DOC)  )');
    Qry.sql.add('LEFT JOIN PESSOA_PRETENDENTE PP');
    Qry.sql.add('   ON ( (DOC.NU_PRETENDENTE = PP.NU_PRETENDENTE) AND');
    Qry.sql.add('        (DOC.NU_PESSOA = PP.NU_PESSOA) )');
    Qry.sql.add('where NU_OPERACAO='+inttostr(NuOperacao)+' and nu_documento='+inttostr(NuDocumento));
    Qry.open;
    if not Qry.isempty then begin
      result := intstr(NuOperacao) + '_';
      if Qry.FieldByname('NU_PESSOA').asinteger > 0 then begin
        // Se o campo NU_PESSOA estiver definido o titulo da janela será composto pela concatenação do Primeiro Nome da Pessoa com o separador " - "  e com o nome do documento.
        result := result + Qry.FieldByname('NO_PESSOA').asstring;
        if pos(' ',result) > 0 then
          result := copy(result,1,pos(' ',result)-1) + ' - '
        else if pos('_',result) > 0 then
          result := copy(result,1,pos('_',result)-1) + ' - ';
      end;

      if Qry.FieldByname('NU_DOCUMENTO_GRUPO_DOC').asinteger <= 0 then
        result := result + Qry.FieldByname('NO_DOCUMENTO').asstring
      else
        result := result + Qry.FieldByname('NO_DOCUMENTO_GRUPO').asstring;
    end;
  finally
    Qry.free;
  end;
end;

procedure MontaHtmlDocumentoIndisponivel(StreamOut: TStream);
var
  NomeArq: AnsiString;
  txt: text;
  FileStream: TFileStream;
  ListaOut: TpMemory;
begin
  NomeArq := ChangeFileExt(MakeTempFileName, '.html');
  assign(txt, NomeArq);
  rewrite(txt);
  write(txt, AnsiToUtf8('<!DOCTYPE html><html lang="pt-BR"><head><meta charset="utf-8">'));
  write(txt, AnsiToUtf8('<title>Documento não disponível</title><style>'));
  write(txt, AnsiToUtf8('body {margin: 0;font-family: Arial, sans-serif;}'));
  write(txt, AnsiToUtf8('.mensagem-container {background-color: #003366;color:'));
  write(txt, AnsiToUtf8(' white;padding: 15px;font-size: 14px;display: flex;'));
  write(txt, AnsiToUtf8(' align-items: center;}.mensagem-container img {width: 16px;'));
  write(txt, AnsiToUtf8(' height: 16px;margin-left: 5px;margin-right: 10px;}'));
  write(txt, AnsiToUtf8(' .mensagem-texto {line-height: 1.4;}'));
  write(txt, AnsiToUtf8(' </style></head><body><div class="mensagem-container">'));
  write(txt, AnsiToUtf8(' <div class="mensagem-texto">'));
  write(txt, AnsiToUtf8(' <strong>Documento não disponível para visualização.</strong>'));
  write(txt, AnsiToUtf8(' <br>Para visualizá-lo, faça upload do arquivo correspondente'));
  write(txt, AnsiToUtf8('  utilizando o botão "Importar", acima.</div></div></body></html>'));
  close(txt);
  FileStream := TFileStream.create(NomeArq, fmOpenRead or fmShareDenyNone);
  ListaOut := TpMemory.create;
  try
    StreamOut.position := 0;
    ListaOut.addval('Nome','DocumentoNaoDisponivel.html');
    ListaOut.addval('Tipo','.html');
    ListaOut.SaveToStreamWithSize(StreamOut);
    StreamOut.CopyFrom(FileStream, 0);
  finally
    FileStream.free;
    ListaOut.free;
  end;
end;

procedure GetDocumentoOperacao (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  NuPretendente,
  NuDocumento,
  NoDocumentoSistArq: AnsiString;
  id : Integer;
  NuOperacao : integer;
  TituloJanela : ansistring;
  SaidaPdf,
  BuscaComCaseSensitive : boolean;
  Linha,
  NomeArq,
  NomeArqErr,
  NomeArqPdf: AnsiString;
  ArqErr: Text;
  ListaOut: TpMemory;
  FileStream: TFileStream;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  BuscaComCaseSensitive := false;
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    NuPretendente := jsonIn['NU_PRETENDENTE'].AsString;
    NuDocumento := jsonIn['NU_DOCUMENTO'].AsString;
    NoDocumentoSistArq := GetNoDucumentoSistArq(NuPretendente,NuDocumento);
    NuOperacao := valint(jsonIn['NU_PRETENDENTE'].asstring);
    TituloJanela := DescricaoCheckListDoc(NuOperacao,valint(NuDocumento));
    BuscaComCaseSensitive := lib1.strToBool(jsonIn.addOrGet('BuscaComCaseSensitive').asString);
    SaidaPdf := lib1.strToBool(jsonIn['IN_SAIDA_PDF'].asString);
    id := obtemIds(NuOperacao,NoDocumentoSistArq,BuscaComCaseSensitive);
    NoDocumentoSistArq := Stringreplace(NoDocumentoSistArq,'\','/',[rfReplaceAll]);
    try
      if (id = -1) and (copy(NoDocumentoSistArq,1,1) = '/') then begin
        NoDocumentoSistArq := copy(NoDocumentoSistArq,2,Length(NoDocumentoSistArq));
        id := obtemIds(NuOperacao,NoDocumentoSistArq,BuscaComCaseSensitive);
      end;
      ValidaPermissaoUsuarioDocumento(ID,jsonIn['userName'].asString,NuPretendente,jsonIn['sessionKey'].asString,true);
      streamout.size := 0;
      if saidaPdf and (Upstr(ExtractFileExt(NoDocumentoSistArq)) <> '.PDF') then begin
        NomeArq := MakeTempFileName;
        NomeArqPdf := ChangeFileExt(NomeArq, '.pdf');
        NomeArqErr := ChangeFileExt(NomeArq, '.err');
        SaveDocumentoToFile(GetSqlConnection(PegaDirAtv), id, NomeArq);
        shell('libreoffice --headless --invisible --norestore --convert-to pdf --outdir '+ExtractFilePath(NomeArq)+' '+ NomeArq +' 2> ' + NomeArqErr);
        assign(ArqErr,NomeArqErr);
        reset(ArqErr);
        if not Eof(ArqErr) then begin
          readln(ArqErr,Linha);
          close(ArqErr);
          if (StripStr(Linha)) <> '' then
            raise exception.create('Ocorreu um erro ao converter o documento: ' + Linha);
        end
        else close(ArqErr);
        ListaOut := TpMemory.create;
        FileStream := TFileStream.create(NomeArqPdf, fmOpenRead or fmShareDenyNone);
        try
          ListaOut.addval('Nome', ExtractFileName(NomeArqPdf));
          ListaOut.addval('Tipo', '.pdf');
          ListaOut.addval('TituloJanela', TituloJanela);
          ListaOut.saveToStreamWithSize(StreamOut);
          StreamOut.copyFrom(FileStream, 0);
        finally
          ListaOut.free;
          FileStream.free;
          if fileexists(NomeArqPDf) then deleteFile(NomeArqPDf);
          if fileexists(NomeArqErr) then deleteFile(NomeArqErr);
        end;
      end else
        GetDocumentoPorId(id,StreamOut,false{emPdf},false{Download},''{FileName},TituloJanela);
    except
      on e:exception do begin
        if e.message = 'Visualização não disponível' then begin
          MontaHtmlDocumentoIndisponivel(StreamOut);
        end else
          raise exception.create(e.message);
      end;
    end;
  finally
    jsonIn.Free;
  end;
end;

procedure GetDocumentoOperacaoAssinatura(StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  NuPretendente,
  NuDocumento,
  NoDocumentoSistArq: AnsiString;
  id : Integer;
  NuOperacao : integer;
  FileName : ansistring;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    NuPretendente := jsonIn['NU_PRETENDENTE'].AsString;
    NuDocumento := jsonIn['NU_DOCUMENTO'].AsString;
    NoDocumentoSistArq := GetNoDucumentoSistArq(NuPretendente,NuDocumento);
    NuOperacao := valint(jsonIn['NU_PRETENDENTE'].asstring);
    id := obtemIds(NuOperacao,NoDocumentoSistArq);
    FileName := NomeDocumento(GetSqlConnection(PegaDirAtv),id);
    streamout.size := 0;
    GetDocumentoPorId(id,StreamOut,false{emPdf},true{Download},FileName,'');
  finally
    jsonIn.Free;
  end;
end;

procedure GetDocumentoContratoAssinatura(StreamIn, StreamOut : TStream);
var
  jsonIn : TpXml;
  Id : integer;
  CoContrato : string;
  FileName : ansistring;
begin
  jsonIn := TpXml.create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    Id := jsonIn['ID'].asinteger;
    FileName := NomeDocumento(GetSqlConnection(PegaDirAtv),Id);
    StreamOut.size := 0;
    GetDocumentoPorId(Id,StreamOut,false{emPdf},true{Download},FileName,'');
  finally
    jsonIn.free;
  end;
end;

function DescricaoCheckListDocTarefa(NuOcorrencia,NuDocumento : integer) : ansistring;
var
  Qry : TSqlQuery;
begin
  result := '';

  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(pegaDirTab);
    Qry.sql.add('select DOS.NU_DOCUMENTO, DOS.NU_TIPO_ATENDIMENTO,');
    Qry.sql.add('       DOS.NU_TIPO_DOCUMENTO, DTA.NO_TIPO_DOCUMENTO as NO_DOCUMENTO_TIPO, DOS.NO_DOCUMENTO');
    Qry.sql.add('from documento_ocorrencia_sisat DOS');
    Qry.sql.add('LEFT JOIN documento_tipo_atendimento DTA');
    Qry.sql.add('   ON (  (DOS.NU_TIPO_ATENDIMENTO = DTA.NU_TIPO_ATENDIMENTO)  AND');
    Qry.sql.add('         (DOS.NU_TIPO_DOCUMENTO = DTA.NU_TIPO_DOCUMENTO)  )');
    Qry.sql.add('where NU_OCORRENCIA='+inttostr(NuOcorrencia)+' and nu_documento='+inttostr(NuDocumento));
    Qry.open;
    if not Qry.isempty then begin
      if Qry.FieldByname('NU_TIPO_ATENDIMENTO').asinteger <= 0 then
        result := result + Qry.FieldByname('NO_DOCUMENTO').asstring
      else
        result := result + Qry.FieldByname('NO_DOCUMENTO_TIPO').asstring;
    end;
  finally
    Qry.free;
  end;
end;

procedure GetDocumentoSisat (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  NuDocumento,
  NoDocumentoSistArq: AnsiString;
  id : Integer;
  NuOcorrencia : integer;
  TituloJanela : ansistring;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    NuOcorrencia := jsonIn['NU_OCORRENCIA'].Asinteger;
    NuDocumento := jsonIn['NU_DOCUMENTO'].AsString;
    NoDocumentoSistArq := GetNoDocumentoSistArqTarefa(NuOcorrencia,NuDocumento);
    TituloJanela := DescricaoCheckListDocTarefa(NuOcorrencia,valint(NuDocumento));
    id := obtemIdsTarefa(NuOcorrencia,NoDocumentoSistArq);
    streamout.size := 0;
    GetDocumentoPorId(id,StreamOut,false{emPdf},false{Download},''{FileName},TituloJanela);
  finally
    jsonIn.Free;
  end;
end;


{
procedure DeleteDocumento(Id:Integer);
var
  Qry: TSqlQuery;
begin
  Qry := TSqlQuery.Create(nil);
  Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
  try
    Qry.Sql.Text := 'delete from CONTROLEVERSAO where id = :id';
    Qry.Params[0].asinteger := Id;
    Qry.ExecSql;
    
    Qry.Sql.Text := 'delete from sistarq where id = :id';
    Qry.Params[0].asinteger := id;
    Qry.ExecSql;
  finally
    Qry.free;
  end;
end;
}

function GetNoPastaDocumento(NuPretendente, NuDocumento: AnsiString):AnsiString;
var
  Qry: TSqlQuery;
begin
  result := '';
  Qry := TSqlQuery.Create(nil);
  try
    Qry.Sql.Add('select NO_PASTA_DOCUMENTO from documento_operacao D');
    Qry.Sql.Add('join GRUPO_DOCUMENTO G ON D.NU_GRUPO_DOCUMENTO = G.NU_GRUPO_DOCUMENTO');
    Qry.Sql.Add('where nu_pretendente = ' + QuotedStr(NuPretendente) + 
                'and nu_documento = ' + QuotedStr(NuDocumento));
    Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
    Qry.Open;
    result := Qry.Fields[0].AsString;
    Qry.close;
  finally
    Qry.free;
  end;
end;

procedure PostDocumentoOperacaoAssinatura(StreamIn, StreamOut : TStream);
var
  f : File of Byte;
  jsonIn,
  jsonOut: TpXml;
  Qry: TSqlQuery;
  IdPai,
  Id,
  IdPasta : Integer;
  caminho,
  TempFileName,
  TempFileNamePdf,
  FileName,
  NomeAntigo,
  NomeNovo,
  NuPretendente,
  NuDocumento: AnsiString;
  NovaVersao: Integer;
  FileStream: TFileStream;
  Versao: Integer;
  Transacao        : TTransactionDesc;
  SqlConnection    : TSqlConnection;
  Resposta: AnsiString;
  Aplic : TLogAplic;
  Len: Integer;
  Ext : ansistring;
  TamArquivo : integer;
  Pretendente : TPretendente;
  index : integer;
  StatusAnt : integer;
  extfile,extfileor,lstext : Ansistring;
  Xml : TpXml;
  Msg : string;
  GravaMiniatura: boolean;
  NuAssinatura,
  NuSeq : integer;
  TemProximoAssinar : boolean;
  Assunto,
  CorpoEmail,
  Destinatario : ansistring;
  QryOp,
  QryU,
  QryR,
  QryC,
  QryEmail,
  QryMerge : TSqlQuery;
  Stream : TMemoryStream;
  Texto : TStringList;
  p : TpXmlNode;
  Merge : TProMerge;
  MergeVersao2,
  MergeVersao3 : boolean;
  CoContratoEmail,
  NuPretendenteEmail : string;
  Smtp,
  Remetente,
  UsuarioSmtp,
  Senha : string;
begin
  Get_hora(HoraH);
  NovaVersao := 0;
  Msg := '';
  jsonIn  := TpXml.Create;
  jsonOut := TpXml.Create;
  Qry := TSqlQuery.create(nil);
  QryOp := TSqlQuery.create(nil);
  QryU := TSqlQuery.create(nil);
  QryR := TSqlQuery.create(nil);
  QryC := TSqlQuery.create(nil);
  QryMerge := TSqlQuery.create(nil);
  QryEmail := TSqlQuery.create(nil);
  TempFileName := makeTempFileName;
  FileStream := TFileStream.Create(TempFileName,fmCreate);
  NomeAntigo := '';
  GravaMiniatura := true;
  try
    Transacao.TransactionID   := (Random(1000) + 2);
    Transacao.IsolationLevel  := xilREADCOMMITTED;
    SqlConnection := GetSqlConnection(PegaDirAtv);
    SqlConnection.StartTransaction (Transacao);
    try
      jsonIn.LoadFromStreamWithSize(StreamIn);

      // Tira do buffer de entrada e joga para o arquivo temporario no disco
      FileStream.CopyFrom(StreamIn,StreamIn.Size-StreamIn.Position);
      TamArquivo := FileStream.size;
      FreeAndNil(FileStream);

      if TamArquivo > ObtemTamMaxUpLoad then
        raise exception.create('Arquivo maior que o limite de upload permitido');

      if not verificacaoAntiMalware(tempFileName, jsonOut) then
        raise exception.create('Não foi possível realizar a verificação no servidor antimalware.');

      NuPretendente := jsonIn['NU_PRETENDENTE'].AsString;
      scislib.AbreConexao;
      FileName := jsonIn['FileName'].AsString;

      extfile := UpperCase(StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      extfileor := (StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      lstext := UpperCase(GetEnv('EXTUPLPERMITIDO'));
      if (trim(lstext) <> '') and  (pos(extfile,lstext) <= 0) then
        raise exception.create('Formato de arquivo não permitido. As extensões permitidas são: '+lstext);

      NuDocumento := jsonIn['NU_DOCUMENTO'].AsString;

      Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
      Qry.Sql.add('select S.IN_OK from documento_operacao D');
      Qry.Sql.add('left join STATUS_DOCUMENTO S on S.CO_STATUS_DOC= D.CO_STATUS_DOC');
      Qry.Sql.add('where NU_OPERACAO = ' + inttostr(valint(NuPretendente)));
      Qry.sql.add('and NU_DOCUMENTO = ' + inttostr(valint(NuDocumento)));
      Qry.open;
      try
        if Qry.isempty then
          raise exception.create('Documento não encontrado');
        if Qry.fields[0].asstring = 'T' then
          raise exception.create('Documento não pode ser anexado, status OK');
      finally
        Qry.close;
      end;

      if NuDocumento >= '' then begin
        NomeAntigo := GetNoDucumentoSistArq(NuPretendente,NuDocumento);
        if RemoveLinkNomeAntigo(valint(NuPretendente),valint(NuDocumento),NomeAntigo) then
          NomeAntigo := '';
      end;

      // Procura ID do diretório
      IDPai := GeraIDPaiDocumentosPretendente(SqlConnection,NuPretendente);
      if NomeAntigo > '' then
        NomeAntigo := '/'+Stringreplace(NomeAntigo,'\','/',[rfReplaceAll]);
      // Pega o caminho da configuração do grupo de documentos
      caminho := '/' + GetNoPastaDocumento(NuPretendente,NuDocumento);
      if Caminho > '' then
        Caminho := Stringreplace(Caminho,'\','/',[rfReplaceAll]);

      IdPasta := ForcaPathDocumento(GetSqlConnection(PegaDirAtv),IdPai,Caminho);

      // Se já existir um documento com o nome antigo, pegar o ID
      // manter o nome criado inicialmente mas importar o conteudo do novo documento
      if NomeAntigo > '' then begin
        ID := LeIdDoPath(GetSqlConnection(PegaDirAtv),NomeAntigo,IdPai);
        Ext := ExtractFileExt(FileName);
        FileName := ExtractFileName(NomeAntigo);
        if compareText(Ext,ExtractFileExt(FileName)) <> 0 then begin
          Filename := ChangeFileExt(FileName,Ext);
          if ID > 0 then begin
            // se a extensão mudou, preciso preservar a extensão nova, ou pode dar
            // zebra na vizualiação, já que os visualizadores usam a extensão
            // para saber como abrir a imagem
            Qry.Sql.clear;
            Qry.Sql.Text := 'update sistarq set nome = ' +
                             quotedStr(FileName) + ' where ID = ' + intstr(ID);
            Qry.execSql;
          end;
        end;
      end
      else
        ID := -1;

      NomeNovo := caminho + '\' + FileName;
      if assigned(jsonIn['IN_TEM_VERSIONAMENTO']) and
         ((uppercase(jsonIn['IN_TEM_VERSIONAMENTO'].AsString) = 'TRUE') or
          (uppercase(jsonIn['IN_TEM_VERSIONAMENTO'].AsString) = 'T')) then begin
        // se controla versão tem que atualizar o campo
        // in_cria_versao_atualizada do sistarq para o documento
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.Sql.Text := 'update sistarq set IN_CRIA_VERSAO_ATUALIZADA = ' +
                         quotedStr('S') + ' where ID = ' + intstr(ID);
        Qry.execSql;
      end;
      Versao := LeVersaoDocumento(GetSqlConnection(PegaDirTab),id);
      GravaBinarioVersao(GetSqlConnection(PegaDirAtv),Id,Versao,TempFileName,NovaVersao, GravaMiniatura);
      NomeAntigo := Stringreplace(NomeAntigo,'/','\',[rfReplaceAll]);
      if (length(NomeAntigo) > 1) and (NomeAntigo[1] = '\') then delete(NomeAntigo,1,1);
      NomeNovo := Stringreplace(NomeNovo,'/','\',[rfReplaceAll]);
      if (length(NomeNovo) > 1) and (NomeNovo[1] = '\') then delete(NomeNovo,1,1);

      // Guarda novo nome se não existia ainda ou ficou diferente
      if (Trim(NomeAntigo) = '') or (trim(NomeAntigo) <> NomeNovo) then begin
        Qry.Sql.clear;
        Qry.Sql.Text := 'update documento_operacao set NO_DOCUMENTO_SISTARQ =' +
        quotedStr(NomeNovo) +
        ' where NU_PRETENDENTE = ' + quotedStr(NuPretendente) +
        ' and NU_DOCUMENTO = ' + quotedStr(NuDocumento);
        Qry.execSql;
      end;

      Msg := 'Alteração de documento no CheckList';
      Aplic := logAplic_AlteracaoDocCheckList;
      if trim(Msg) > '' then begin
        Xml := TpXml.create;
        Pretendente := TPretendente.create;
        try
          Pretendente.le(NuPretendente,SqlConnection);
          Xml.documentelement.nodename := 'LOG';
          Xml.documentelement.addchild('Documento').asstring := NomeNovo;
          Xml.documentelement.addchild('Operacao').asinteger := Pretendente.Operacao.Cad.NU_OPERACAO;
          Xml.documentelement.addchild('Pretendente').asstring := NuPretendente;
          geralog(Aplic,logseveridade_Aviso,PegaUsuario,
                  Msg,'',
                  Xml,NuPretendente,SqlConnection);
        finally
          Xml.free;
          Pretendente.free;
        end;
      end;

      QryOp.SqlConnection := Qry.SqlConnection;
      QryOp.Sql.add('SELECT * FROM PESSOA_PRETENDENTE');
      QryOp.Sql.add('WHERE NU_PRETENDENTE=:NuPretendente');
      QryOp.Sql.add('AND NU_CPFCNPJ=:NuCpfCnpj');
      QryOp.parambyname('NuPretendente').datatype := ftstring;
      QryOp.parambyname('NuCpfCnpj').datatype := ftstring;
      QryOp.prepared := true;

      QryU.SqlConnection := Qry.SqlConnection;
      QryU.Sql.add('SELECT NO_E_MAIL_EMISSAO, NOME, CPF FROM USUARIO');
      QryU.Sql.add('WHERE USUARIO=:Usuario');
      QryU.parambyname('Usuario').datatype := ftstring;
      QryU.prepared := true;

      QryR.SqlConnection := Qry.SqlConnection;
      QryR.Sql.add('SELECT NO_EMAIL FROM REPRESENTANTE_LEGAL');
      qryR.Sql.add('WHERE NU_CPF=:NuCpf');
      QryR.parambyname('NuCpf').datatype := ftstring;
      QryR.prepared := true;

      QryC.SqlConnection := Qry.SqlConnection;
      QryC.Sql.add('SELECT CAD_EMAIL AS EMAIL FROM CADMUT ');
      QryC.Sql.add('WHERE CO_BASE=0 AND CO_CONTRATO=:CoContrato');
      QryC.Sql.add('AND CAD_CPF=:NuCpf');
      QryC.Sql.add('UNION ALL ');
      QryC.Sql.add('SELECT EMAIL AS EMAIL FROM CADRENDA ');
      QryC.Sql.add('WHERE CO_BASE=0 AND CO_CONTRATO=:CoContrato');
      QryC.Sql.add('AND CPF=:NuCpf');
      QryC.parambyname('CoContrato').datatype := ftstring;
      QryC.parambyname('NuCpf').datatype := ftstring;
      QryC.prepared := true;

      Qry.close;
      Qry.Sql.clear;
      Qry.Sql.add('SELECT NU_ASSINATURA FROM DOCUMENTO_A_ASSINAR ');
      Qry.Sql.add('WHERE NU_OPERACAO=:NuOperacao AND NU_DOCUMENTO=:NuDocumento AND');
      Qry.Sql.add('CO_STATUS_ASSINATURA=:CoStatus');
      Qry.parambyname('NuOperacao').asinteger := valint(NuPretendente);
      Qry.parambyname('NuDocumento').asinteger := valint(NuDocumento);
      Qry.parambyname('CoStatus').asstring := 'A';
      Qry.open;
      if not Qry.Eof then begin
        NuAssinatura := Qry.fieldbyname('NU_ASSINATURA').asinteger;
        Qry.close;
        Qry.Sql.clear;
        Qry.Sql.add('UPDATE ASSINATURA_DOCUMENTO SET CO_STATUS_ASSINATURA=:CoStatusNovo,');
        Qry.Sql.add('DT_HORA_ASSINATURA=:DtAssinatura ');
        Qry.Sql.add('WHERE NU_ASSINATURA=:NuAssinatura AND CO_STATUS_ASSINATURA=:CoStatusAnt');
        Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
        Qry.parambyname('CoStatusAnt').asstring := 'A';
        Qry.parambyname('CoStatusNovo').asstring := 'O';
        Qry.parambyname('DtAssinatura').asdatetime := Now();
        Qry.ExecSql;

        Destinatario := '';
        TemProximoAssinar := false;
        NuSeq := 0;
        //procura o próximo a assinar
        Qry.Sql.clear;
        Qry.Sql.add('SELECT AD.NU_SEQUENCIA,AD.CO_STATUS_ASSINATURA,AD.NO_CHAVE_ACESSO,');
        Qry.Sql.add('AD.CO_USUARIO,AD.NU_CPFCNPJ,AD.NU_ORDEM_ASSINATURA,');
        Qry.Sql.add('DA.NU_OPERACAO,DA.CO_CONTRATO, AD.IN_TIPO_ASSINATURA');
        Qry.Sql.add('FROM ASSINATURA_DOCUMENTO AD');
        Qry.Sql.add('LEFT JOIN DOCUMENTO_A_ASSINAR DA ON DA.NU_ASSINATURA=AD.NU_ASSINATURA');
        Qry.Sql.add('WHERE AD.NU_ASSINATURA=:NuAssinatura');
        Qry.Sql.add('ORDER BY AD.NU_ORDEM_ASSINATURA');
        Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
        Qry.open;
        while not Qry.Eof do begin
          if trim(Qry.Fieldbyname('CO_STATUS_ASSINATURA').asstring) = '' then begin
            TemProximoAssinar := true;
            NuSeq := Qry.fieldbyname('NU_SEQUENCIA').asinteger;
            if Qry.fieldbyname('NU_OPERACAO').asinteger > 0 then begin
              NuPretendenteEmail := intstr2(Qry.fieldbyname('NU_OPERACAO').asinteger,9);
              CoContratoEmail := '';
            end
            else begin
              NuPretendenteEmail := '';
              CoContratoEmail := Qry.fieldbyname('CO_CONTRATO').asstring;
            end;
            if (trim(Qry.fieldbyname('CO_USUARIO').asstring) = '') then begin
              if (Qry.fieldbyname('NU_OPERACAO').asinteger > 0) then begin
                QryOp.parambyname('NuPretendente').asstring := intstr2(Qry.fieldbyname('NU_OPERACAO').asinteger,9);
                QryOp.parambyname('NuCpfCnpj').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                QryOp.open;
                if not QryOp.eof then
                  Destinatario := QryOp.fieldbyname('NO_EMAIL').asstring
                else begin
                  QryR.parambyname('NuCpf').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                  QryR.open;
                  if not QryR.eof then
                    Destinatario := QryR.fieldbyname('NO_EMAIL').asstring;
                end;
              end
              else begin
                //***contrato
                QryC.parambyname('CoContrato').asstring := Qry.fieldbyname('CO_CONTRATO').asstring;
                QryC.parambyname('NuCpf').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                QryC.open;
                if not QryC.eof then
                  Destinatario := QryC.fieldbyname('EMAIL').asstring
                else begin
                  QryR.parambyname('NuCpf').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                  QryR.open;
                  if not QryR.eof then
                    Destinatario := QryR.fieldbyname('NO_EMAIL').asstring;
                end;
              end;
            end
            else begin
              QryU.parambyname('Usuario').asstring := Qry.fieldbyname('CO_USUARIO').asstring;
              QryU.open;
              if not QryU.eof then
                Destinatario := QryU.fieldbyname('NO_E_MAIL_EMISSAO').asstring;
            end;
            CorpoEmail := '';
            if scciconf.DocumentoEnviadoCorpoEmail > 0 then begin
              Stream := TMemoryStream.create;
              Texto := TStringList.create;
              try
                SaveDocumentoToStream(Qry.SqlConnection,scciconf.DocumentoEnviadoCorpoEmail,Stream);
                Stream.Position := 0;
                Texto.LoadFromStream(Stream);
                CorpoEmail := Texto.Text;
              finally
                Stream.free;
                Texto.free;
              end;
            end;
            Xml := TpXml.create;
            Merge := TProMerge.create;
            try
              p := Xml.add('dados');
              QryMerge.SqlConnection := Qry.SqlConnection;
              if (Qry.fieldbyname('NU_OPERACAO').asinteger > 0) then begin
                QryMerge.Sql.add('SELECT * FROM OPERACAO_CREDITO');
                QryMerge.Sql.add('WHERE NU_OPERACAO=:NuOperacao');
                QryMerge.parambyname('NuOperacao').asinteger := Qry.fieldbyname('NU_OPERACAO').asinteger;
                QryMerge.open;
                bdlib.DataSetToXml(QryMerge,'OPERACAO_CREDITO.',p);
                p.add('ASSINATURA.CO_IDENT_CLIENTE').asString := QryMerge.fieldByName('NU_PROPOSTA_EXTERNO').asString;
                QryMerge.close;

                if (trim(Qry.fieldbyname('CO_USUARIO').asstring) = '') then begin
                  bdlib.DataSetToXml(QryOp,'PESSOA_PRETENDENTE.',p);
                  p.add('ASSINATURA.NOME').asString := QryOp.fieldByName('NO_PESSOA').asString;
                  p.add('ASSINATURA.CPF').asString := CpfForm2(QryOp.fieldByName('NU_CPFCNPJ').asString);
                  p.add('ASSINATURA.EMAIL').asString := QryOp.fieldByName('NO_EMAIL').asString;
                end else begin
                  bdlib.DataSetToXml(QryU,'USUARIO.',p);
                  p.add('ASSINATURA.NOME').asString := QryU.fieldByName('NOME').asString;
                  p.add('ASSINATURA.CPF').asString := CpfForm2(QryU.fieldByName('CPF').asString);
                  p.add('ASSINATURA.EMAIL').asString := QryU.fieldByName('NO_E_MAIL_EMISSAO').asString;
                end;
                p.add('ASSINATURA.CO_IDENT_SCCI').asString := Qry.fieldByName('NU_OPERACAO').asString;
                p.add('ASSINATURA.CO_TIPO_DOC').asString := 'O';
              end
              else begin
                //**** merge para contrato;
                QryMerge.Sql.add('SELECT * FROM CADMUT');
                QryMerge.Sql.add('WHERE CO_BASE=0 AND CO_CONTRATO=:CoContrato');
                QryMerge.parambyname('CoContrato').asstring := Qry.fieldbyname('CO_CONTRATO').asstring;
                QryMerge.open;
                bdlib.DataSetToXml(QryMerge,'CADMUT.',p);
                p.add('ASSINATURA.NOME').asString := QryMerge.fieldByName('CAD_NOME').asString;
                p.add('ASSINATURA.CPF').asString := CpfForm2(QryMerge.fieldByName('CAD_CPF').asString);
                p.add('ASSINATURA.EMAIL').asString := QryMerge.fieldByName('CAD_EMAIL').asString;
                p.add('ASSINATURA.CO_IDENT_SCCI').asString := Qry.fieldByName('CO_CONTRATO').asString;
                p.add('ASSINATURA.CO_IDENT_CLIENTE').asString := QryMerge.fieldByName('CAD_VTRVELHO').asString;
                p.add('ASSINATURA.CO_TIPO_DOC').asString := 'C';
                QryMerge.close;
                if (trim(Qry.fieldbyname('CO_USUARIO').asstring) <> '') then
                  bdlib.DataSetToXml(QryU,'USUARIO.',p);
              end;
              p.add('NO_CHAVE_ACESSO').asstring := Qry.fieldbyname('NO_CHAVE_ACESSO').asstring;
              p.add('ASSINATURA.NO_TIPO_ASSINATURA').asString := Qry.fieldByName('IN_TIPO_ASSINATURA').asString;
              Merge.LoadFromString(CorpoEmail);
              Merge.dados := p;
              CorpoEmail := Merge.AsString;
              Assunto := scciconf.AssuntoEmailAssinatura;
              MergeVersao2 := (trim(Assunto) > '') and (pos('<<MERGE_VERSAO2>>',Assunto) > 0);
              MergeVersao3 := (trim(Assunto) > '') and (pos('<<MERGE_VERSAO3>>',Assunto) > 0);
              if MergeVersao2 then begin
                Assunto := StringReplace(Assunto,'<<MERGE_VERSAO2>>','',[rfReplaceAll]);
                Assunto := FazMergeAssuntoEmail(Assunto,p,true);
              end
              else if MergeVersao3 then begin
                Assunto := StringReplace(Assunto,'<<MERGE_VERSAO3>>','',[rfReplaceAll]);
                Assunto := FazMergeAssuntoEmail(Assunto,p,true);
              end
              else
                Assunto := FazMergeAssuntoEmail(Assunto,p,false);
            finally
              Xml.free;
              Merge.free;
            end;
            QryOp.close;
            QryR.close;
            QryU.close;
            QryC.close;
            break;
          end;
          Qry.next;
        end;
        Qry.close;
        if TemProximoAssinar then begin
          Qry.Sql.Clear;
          Qry.Sql.add('UPDATE ASSINATURA_DOCUMENTO SET CO_STATUS_ASSINATURA=:CoStatus,');
          Qry.Sql.add('DT_ENVIO_SOLICITACAO=:DtEnvio ');
          Qry.Sql.add('WHERE NU_ASSINATURA=:NuAssinatura AND NU_SEQUENCIA=:NuSequencia');
          Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
          Qry.parambyname('NuSequencia').asinteger := NuSeq;
          Qry.parambyname('CoStatus').asstring := 'A';
          Qry.parambyname('DtEnvio').asdatetime := Now();
          Qry.ExecSql;
          Smtp := '';
          UsuarioSmtp := '';
          Senha := '';
          Remetente := '';
          LeConfigEmissaoEmailUser(Qry.SqlConnection,PegaUsuario,Smtp,Remetente,Senha,UsuarioSmtp);
          Remetente := scciconf.RemetenteEmailAssinatura;
          GravaEmailEnviar(QryEmail,CoContratoEmail,NuPretendenteEmail,0,PegaUsuario,Assunto,Remetente,
                           Destinatario,CorpoEmail,Smtp,UsuarioSmtp,Senha);
          
        end
        else begin
          Qry.Sql.clear;
          Qry.Sql.add('UPDATE DOCUMENTO_A_ASSINAR SET CO_STATUS_ASSINATURA=:CoStatus,');
          Qry.Sql.add('DT_FIM_ASSINATURA=:DtFim ');
          Qry.Sql.add('WHERE NU_ASSINATURA=:NuAssinatura');
          Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
          Qry.parambyname('CoStatus').asstring := 'O';
          Qry.parambyname('DtFim').asdatetime := Now();
          Qry.ExecSql;
        end;
      end;
      SqlConnection.Commit(Transacao);
    except
      SqlConnection.RollBack(Transacao);
      raise;
    end;
    jsonOut.add('success').AsBoolean := true;
    Resposta := jsonOut.toJson;
    Len := length(Resposta);
    StreamOut.writebuffer(Len,4);
    StreamOut.writebuffer(Resposta[1],Len);
  finally
    jsonIn.free;
    jsonOut.free;
    Qry.free;
    QryOp.free;
    QryU.free;
    QryR.free;
    QryC.free;
    QryMerge.free;
    QryEmail.free;
    if assigned(FileStream) then
      FileStream.free;
  end;
end;

procedure PostDocumentoContratoAssinatura(StreamIn, StreamOut : TStream);
var
  f : File of Byte;
  jsonIn,
  jsonOut: TpXml;
  Qry: TSqlQuery;
  Id : integer;
  TempFileName,
  FileName,
  CoContrato : ansistring;
  NovaVersao: Integer;
  FileStream: TFileStream;
  Versao: Integer;
  Transacao        : TTransactionDesc;
  SqlConnection    : TSqlConnection;
  Resposta: AnsiString;
  Len: Integer;
  Ext : ansistring;
  TamArquivo : integer;
  extfile,extfileor,lstext : Ansistring;
  Xml : TpXml;
  Msg : string;
  GravaMiniatura: boolean;
  NuAssinatura,
  NuSeq : integer;
  TemProximoAssinar : boolean;
  Assunto,
  CorpoEmail,
  Destinatario : ansistring;
  QryOp,
  QryU,
  QryR,
  QryC,
  QryEmail,
  QryMerge : TSqlQuery;
  Stream : TMemoryStream;
  Texto : TStringList;
  p : TpXmlNode;
  Merge : TProMerge;
  MergeVersao2,
  MergeVersao3 : boolean;
  CoContratoEmail,
  NuPretendenteEmail : string;
  Smtp,
  Remetente,
  UsuarioSmtp,
  Senha : string;
begin
  Get_hora(HoraH);
  NovaVersao := 0;
  Msg := '';
  jsonIn  := TpXml.Create;
  jsonOut := TpXml.Create;
  Qry := TSqlQuery.create(nil);
  QryOp := TSqlQuery.create(nil);
  QryU := TSqlQuery.create(nil);
  QryR := TSqlQuery.create(nil);
  QryC := TSqlQuery.create(nil);
  QryMerge := TSqlQuery.create(nil);
  QryEmail := TSqlQuery.create(nil);
  TempFileName := makeTempFileName;
  FileStream := TFileStream.Create(TempFileName,fmCreate);
  GravaMiniatura := true;
  try
    Transacao.TransactionID   := (Random(1000) + 2);
    Transacao.IsolationLevel  := xilREADCOMMITTED;
    SqlConnection := GetSqlConnection(PegaDirAtv);
    SqlConnection.StartTransaction (Transacao);
    try
      jsonIn.LoadFromStreamWithSize(StreamIn);

      // Tira do buffer de entrada e joga para o arquivo temporario no disco
      FileStream.CopyFrom(StreamIn,StreamIn.Size-StreamIn.Position);
      TamArquivo := FileStream.size;
      FreeAndNil(FileStream);

      if TamArquivo > ObtemTamMaxUpLoad then
        raise exception.create('Arquivo maior que o limite de upload permitido');

      if not verificacaoAntiMalware(tempFileName, jsonOut) then
        raise exception.create('Não foi possível realizar a verificação no servidor antimalware.');

      CoContrato := jsonIn['CO_CONTRATO'].AsString;
      scislib.AbreConexao;
      FileName := jsonIn['FileName'].AsString;

      extfile := UpperCase(StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      extfileor := (StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      lstext := UpperCase(GetEnv('EXTUPLPERMITIDO'));
      if (trim(lstext) <> '') and  (pos(extfile,lstext) <= 0) then
        raise exception.create('Formato de arquivo não permitido. As extensões permitidas são: '+lstext);

      Id := jsonIn['ID'].Asinteger;

      // Procura ID do diretório
      Versao := LeVersaoDocumento(GetSqlConnection(PegaDirTab),id);
      GravaBinarioVersao(GetSqlConnection(PegaDirAtv),Id,Versao,TempFileName,NovaVersao, GravaMiniatura);

      QryOp.SqlConnection := SqlConnection;
      QryOp.Sql.add('SELECT * FROM PESSOA_PRETENDENTE');
      QryOp.Sql.add('WHERE NU_PRETENDENTE=:NuPretendente');
      QryOp.Sql.add('AND NU_CPFCNPJ=:NuCpfCnpj');
      QryOp.parambyname('NuPretendente').datatype := ftstring;
      QryOp.parambyname('NuCpfCnpj').datatype := ftstring;
      QryOp.prepared := true;

      QryU.SqlConnection := SqlConnection;
      QryU.Sql.add('SELECT NO_E_MAIL_EMISSAO FROM USUARIO');
      QryU.Sql.add('WHERE USUARIO=:Usuario');
      QryU.parambyname('Usuario').datatype := ftstring;
      QryU.prepared := true;

      QryR.SqlConnection := SqlConnection;
      QryR.Sql.add('SELECT NO_EMAIL FROM REPRESENTANTE_LEGAL');
      qryR.Sql.add('WHERE NU_CPF=:NuCpf');
      QryR.parambyname('NuCpf').datatype := ftstring;
      QryR.prepared := true;

      QryC.SqlConnection := SqlConnection;
      QryC.Sql.add('SELECT CAD_EMAIL AS EMAIL FROM CADMUT ');
      QryC.Sql.add('WHERE CO_BASE=0 AND CO_CONTRATO=:CoContrato');
      QryC.Sql.add('AND CAD_CPF=:NuCpf');
      QryC.Sql.add('UNION ALL ');
      QryC.Sql.add('SELECT EMAIL AS EMAIL FROM CADRENDA ');
      QryC.Sql.add('WHERE CO_BASE=0 AND CO_CONTRATO=:CoContrato');
      QryC.Sql.add('AND CPF=:NuCpf');
      QryC.parambyname('CoContrato').datatype := ftstring;
      QryC.parambyname('NuCpf').datatype := ftstring;
      QryC.prepared := true;

      Qry.SqlConnection := SqlConnection;
      Qry.Sql.add('SELECT NU_ASSINATURA FROM DOCUMENTO_A_ASSINAR ');
      Qry.Sql.add('WHERE CO_CONTRATO=:CoContrato AND NU_DOCUMENTO=:NuDocumento AND');
      Qry.Sql.add('CO_STATUS_ASSINATURA=:CoStatus');
      Qry.parambyname('CoContrato').asstring := CoContrato;
      Qry.parambyname('NuDocumento').asinteger := Id;
      Qry.parambyname('CoStatus').asstring := 'A';
      Qry.open;
      if not Qry.Eof then begin
        NuAssinatura := Qry.fieldbyname('NU_ASSINATURA').asinteger;
        Qry.close;
        Qry.Sql.clear;
        Qry.Sql.add('UPDATE ASSINATURA_DOCUMENTO SET CO_STATUS_ASSINATURA=:CoStatusNovo,');
        Qry.Sql.add('DT_HORA_ASSINATURA=:DtAssinatura ');
        Qry.Sql.add('WHERE NU_ASSINATURA=:NuAssinatura AND CO_STATUS_ASSINATURA=:CoStatusAnt');
        Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
        Qry.parambyname('CoStatusAnt').asstring := 'A';
        Qry.parambyname('CoStatusNovo').asstring := 'O';
        Qry.parambyname('DtAssinatura').asdatetime := Now();
        Qry.ExecSql;

        Destinatario := '';
        TemProximoAssinar := false;
        NuSeq := 0;
        //procura o próximo a assinar
        Qry.Sql.clear;
        Qry.Sql.add('SELECT AD.NU_SEQUENCIA,AD.CO_STATUS_ASSINATURA,AD.NO_CHAVE_ACESSO,');
        Qry.Sql.add('AD.CO_USUARIO,AD.NU_CPFCNPJ,AD.NU_ORDEM_ASSINATURA,');
        Qry.Sql.add('DA.NU_OPERACAO,DA.CO_CONTRATO');
        Qry.Sql.add('FROM ASSINATURA_DOCUMENTO AD');
        Qry.Sql.add('LEFT JOIN DOCUMENTO_A_ASSINAR DA ON DA.NU_ASSINATURA=AD.NU_ASSINATURA');
        Qry.Sql.add('WHERE AD.NU_ASSINATURA=:NuAssinatura');
        Qry.Sql.add('ORDER BY AD.NU_ORDEM_ASSINATURA');
        Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
        Qry.open;
        while not Qry.Eof do begin
          if trim(Qry.Fieldbyname('CO_STATUS_ASSINATURA').asstring) = '' then begin
            TemProximoAssinar := true;
            NuSeq := Qry.fieldbyname('NU_SEQUENCIA').asinteger;
            if Qry.fieldbyname('NU_OPERACAO').asinteger > 0 then begin
              NuPretendenteEmail := intstr2(Qry.fieldbyname('NU_OPERACAO').asinteger,9);
              CoContratoEmail := '';
            end
            else begin
              NuPretendenteEmail := '';
              CoContratoEmail := Qry.fieldbyname('CO_CONTRATO').asstring;
            end;
            if (trim(Qry.fieldbyname('CO_USUARIO').asstring) = '') then begin
              if (Qry.fieldbyname('NU_OPERACAO').asinteger > 0) then begin
                QryOp.parambyname('NuPretendente').asstring := intstr2(Qry.fieldbyname('NU_OPERACAO').asinteger,9);
                QryOp.parambyname('NuCpfCnpj').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                QryOp.open;
                if not QryOp.eof then
                  Destinatario := QryOp.fieldbyname('NO_EMAIL').asstring
                else begin
                  QryR.parambyname('NuCpf').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                  QryR.open;
                  if not QryR.eof then
                    Destinatario := QryR.fieldbyname('NO_EMAIL').asstring;
                end;
              end
              else begin
                //***contrato
                QryC.parambyname('CoContrato').asstring := Qry.fieldbyname('CO_CONTRATO').asstring;
                QryC.parambyname('NuCpf').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                QryC.open;
                if not QryC.eof then
                  Destinatario := QryC.fieldbyname('EMAIL').asstring
                else begin
                  QryR.parambyname('NuCpf').asstring := Qry.fieldbyname('NU_CPFCNPJ').asstring;
                  QryR.open;
                  if not QryR.eof then
                    Destinatario := QryR.fieldbyname('NO_EMAIL').asstring;
                end;
              end;
            end
            else begin
              QryU.parambyname('Usuario').asstring := Qry.fieldbyname('CO_USUARIO').asstring;
              QryU.open;
              if not QryU.eof then
                Destinatario := QryU.fieldbyname('NO_E_MAIL_EMISSAO').asstring;
            end;
            CorpoEmail := '';
            if scciconf.DocumentoEnviadoCorpoEmail > 0 then begin
              Stream := TMemoryStream.create;
              Texto := TStringList.create;
              try
                SaveDocumentoToStream(Qry.SqlConnection,scciconf.DocumentoEnviadoCorpoEmail,Stream);
                Stream.Position := 0;
                Texto.LoadFromStream(Stream);
                CorpoEmail := Texto.Text;
              finally
                Stream.free;
                Texto.free;
              end;
            end;
            Xml := TpXml.create;
            Merge := TProMerge.create;
            try
              p := Xml.add('dados');
              QryMerge.SqlConnection := Qry.SqlConnection;
              if (Qry.fieldbyname('NU_OPERACAO').asinteger > 0) then begin
                QryMerge.Sql.add('SELECT * FROM OPERACAO_CREDITO');
                QryMerge.Sql.add('WHERE NU_OPERACAO=:NuOperacao');
                QryMerge.parambyname('NuOperacao').asinteger := Qry.fieldbyname('NU_OPERACAO').asinteger;
                QryMerge.open;
                bdlib.DataSetToXml(QryMerge,'OPERACAO_CREDITO.',p);
                QryMerge.close;

                if (trim(Qry.fieldbyname('CO_USUARIO').asstring) = '') then
                  bdlib.DataSetToXml(QryOp,'PESSOA_PRETENDENTE.',p)
                else
                  bdlib.DataSetToXml(QryU,'USUARIO.',p);
              end
              else begin
                //**** merge para contrato;
                QryMerge.Sql.add('SELECT * FROM CADMUT');
                QryMerge.Sql.add('WHERE CO_BASE=0 AND CO_CONTRATO=:CoContrato');
                QryMerge.parambyname('CoContrato').asstring := Qry.fieldbyname('CO_CONTRATO').asstring;
                QryMerge.open;
                bdlib.DataSetToXml(QryMerge,'CADMUT.',p);
                QryMerge.close;
                if (trim(Qry.fieldbyname('CO_USUARIO').asstring) <> '') then
                  bdlib.DataSetToXml(QryU,'USUARIO.',p);
              end;
              p.add('NO_CHAVE_ACESSO').asstring := Qry.fieldbyname('NO_CHAVE_ACESSO').asstring;
              Merge.LoadFromString(CorpoEmail);
              Merge.dados := p;
              CorpoEmail := Merge.AsString;
              Assunto := scciconf.AssuntoEmailAssinatura;
              MergeVersao2 := (trim(Assunto) > '') and (pos('<<MERGE_VERSAO2>>',Assunto) > 0);
              MergeVersao3 := (trim(Assunto) > '') and (pos('<<MERGE_VERSAO3>>',Assunto) > 0);
              if MergeVersao2 then begin
                Assunto := StringReplace(Assunto,'<<MERGE_VERSAO2>>','',[rfReplaceAll]);
                Assunto := FazMergeAssuntoEmail(Assunto,p,true);
              end
              else if MergeVersao3 then begin
                Assunto := StringReplace(Assunto,'<<MERGE_VERSAO3>>','',[rfReplaceAll]);
                Assunto := FazMergeAssuntoEmail(Assunto,p,true);
              end
              else
                Assunto := FazMergeAssuntoEmail(Assunto,p,false);
            finally
              Xml.free;
              Merge.free;
            end;
            QryOp.close;
            QryR.close;
            QryC.close;
            QryU.close;
            break;
          end;
          Qry.next;
        end;
        Qry.close;
        if TemProximoAssinar then begin
          Qry.Sql.Clear;
          Qry.Sql.add('UPDATE ASSINATURA_DOCUMENTO SET CO_STATUS_ASSINATURA=:CoStatus,');
          Qry.Sql.add('DT_ENVIO_SOLICITACAO=:DtEnvio ');
          Qry.Sql.add('WHERE NU_ASSINATURA=:NuAssinatura AND NU_SEQUENCIA=:NuSequencia');
          Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
          Qry.parambyname('NuSequencia').asinteger := NuSeq;
          Qry.parambyname('CoStatus').asstring := 'A';
          Qry.parambyname('DtEnvio').asdatetime := Now();
          Qry.ExecSql;
          Smtp := '';
          UsuarioSmtp := '';
          Senha := '';
          Remetente := '';
          LeConfigEmissaoEmailUser(Qry.SqlConnection,PegaUsuario,Smtp,Remetente,Senha,UsuarioSmtp);
          Remetente := scciconf.RemetenteEmailAssinatura;
          GravaEmailEnviar(QryEmail,CoContratoEmail,NuPretendenteEmail,0,PegaUsuario,Assunto,Remetente,
                           Destinatario,CorpoEmail,Smtp,UsuarioSmtp,Senha);

        end
        else begin
          Qry.Sql.clear;
          Qry.Sql.add('UPDATE DOCUMENTO_A_ASSINAR SET CO_STATUS_ASSINATURA=:CoStatus,');
          Qry.Sql.add('DT_FIM_ASSINATURA=:DtFim ');
          Qry.Sql.add('WHERE NU_ASSINATURA=:NuAssinatura');
          Qry.parambyname('NuAssinatura').asinteger := NuAssinatura;
          Qry.parambyname('CoStatus').asstring := 'O';
          Qry.parambyname('DtFim').asdatetime := Now();
          Qry.ExecSql;
        end;
      end;
      SqlConnection.Commit(Transacao);
    except
      SqlConnection.RollBack(Transacao);
      raise;
    end;
    jsonOut.add('success').AsBoolean := true;
    Resposta := jsonOut.toJson;
    Len := length(Resposta);
    StreamOut.writebuffer(Len,4);
    StreamOut.writebuffer(Resposta[1],Len);
  finally
    jsonIn.free;
    jsonOut.free;
    Qry.free;
    QryOp.free;
    QryU.free;
    QryR.free;
    QryC.free;
    QryMerge.free;
    QryEmail.free;
    if assigned(FileStream) then
      FileStream.free;
  end;
end;

procedure PutDocumentoOperacaoARISP (jsonIn,jsonOut: TpXml);
var
  f                     : File of Byte;
  Qry: TSqlQuery;
  IdPai,
  Id,
  IdPasta : Integer;
  caminho,
  TempFileName,
  TempFileNamePdf,
  FileName,
  NomeAntigo,
  NomeNovo,
  NuPretendente,
  NuDocumento: AnsiString;
  NovaVersao: Integer;
  FileStream: TFileStream;
  Versao: Integer;
  Transacao        : TTransactionDesc;
  SqlConnection    : TSqlConnection;
  Resposta: AnsiString;
  Aplic : TLogAplic;
  Len: Integer;
  Ext : ansistring;
  StatusAlterado : integer;
  TamArquivo : integer;
  Pretendente : TPretendente;
  index : integer;
  StatusAnt : integer;
  extfile,extfileor,lstext : Ansistring;
  Xml : TpXml;
  Msg : string;
  GravaMiniatura: boolean;
begin
  Get_hora(HoraH);
  NovaVersao := 0;
  Msg := '';
  Qry := TSqlQuery.create(nil);
  NomeAntigo := '';
  GravaMiniatura := true;
  try
    Transacao.TransactionID   := (Random(1000) + 2);
    Transacao.IsolationLevel  := xilREADCOMMITTED;
    SqlConnection := GetSqlConnection(PegaDirAtv);
    SqlConnection.StartTransaction (Transacao);
    try
     tempFileName := jsonin['DOCUMENTO'].asString;
     if not verificacaoAntiMalware(tempFileName, jsonOut) then
        raise exception.create('Não foi possível realizar a verificação no servidor antimalware.');

      NuPretendente := jsonIn['NU_PRETENDENTE'].AsString;
      scislib.AbreConexao;

      FileName := extractfilename(jsonIn['DOCUMENTO'].AsString);

      extfile := UpperCase(StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      extfileor := (StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      lstext := UpperCase(GetEnv('EXTUPLPERMITIDO'));
      if (trim(lstext) <> '') and  (pos(extfile,lstext) <= 0) then
        raise exception.create('Formato de arquivo não permitido. As extensões permitidas são: '+lstext);

      NuDocumento := jsonIn['NU_DOCUMENTO'].AsString;


      if NuDocumento >= '' then begin
        NomeAntigo := GetNoDucumentoSistArq(NuPretendente,NuDocumento);
        if RemoveLinkNomeAntigo(valint(NuPretendente),valint(NuDocumento),NomeAntigo) then
          NomeAntigo := '';
      end;

      // Procura ID do diretório
      IDPai := GeraIDPaiDocumentosPretendente(SqlConnection,NuPretendente);
      if NomeAntigo > '' then
        NomeAntigo := '/'+Stringreplace(NomeAntigo,'\','/',[rfReplaceAll]);

      // Pega o caminho da configuração do grupo de documentos
      caminho := '/' + GetNoPastaDocumento(NuPretendente,NuDocumento);
      if Caminho > '' then
        Caminho := Stringreplace(Caminho,'\','/',[rfReplaceAll]);


      IdPasta := ForcaPathDocumento(GetSqlConnection(PegaDirAtv),IdPai,Caminho);


      if jsonin['IN_CONVERTE_PDF'].asString = 'T' then begin
         if (uppercase(extfile)='JPG') OR (uppercase(extfile)='JPEG') then begin
           tempfilenamepdf := tempfilename;
           tempfilenamePdf := stringreplace(tempfilenamepdf,'.tmp','',[rfReplaceAll]);
           tempfilenamepdf := tempfilenamepdf+'.pdf';
           AssignFile(f, tempfilename);
           Reset(f);
           if  (GetEnv('CONVERT_TAMANHO_MININO')>'') and (FileSize(f) > StrToInt(GetEnv('CONVERT_TAMANHO_MININO'))) then
             rshell('/usr/bin/convert '+GetEnv('CONVERT_IMG2PDF')+' '+GetEnv('CONVERT_RESIZE')+' '+tempfilename +' '+tempfilenamepdf)
           else 
             rshell('/usr/bin/convert '+GetEnv('CONVERT_IMG2PDF')+' '+tempfilename +' '+tempfilenamepdf);
           tempfilename := tempfilenamepdf;
           filename := StringReplace(filename,extfileor,'pdf',[rfReplaceAll]);
         end;
      end;


      // Se já existir um documento com o nome antigo, pegar o ID
      // manter o nome criado inicialmente mas importar o conteudo do novo documento
      if NomeAntigo > '' then begin
        ID := LeIdDoPath(GetSqlConnection(PegaDirAtv),NomeAntigo,IdPai);
        Ext := ExtractFileExt(FileName);
        FileName := ExtractFileName(NomeAntigo);
        if compareText(Ext,ExtractFileExt(FileName)) <> 0 then begin
          Filename := ChangeFileExt(FileName,Ext);
          if ID > 0 then begin
            // se a extensão mudou, preciso preservar a extensão nova, ou pode dar
            // zebra na vizualiação, já que os visualizadores usam a extensão
            // para saber como abrir a imagem
            Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
            Qry.Sql.Text := 'update sistarq set nome = ' +
                             quotedStr(FileName) + ' where ID = ' + intstr(ID);
            Qry.execSql;
          end;
        end;
      end
      else
        ID := -1;

      // se não achou o ID(documento não existe) ou não foi incluido ainda, inclui
      if id < 0 then
        ID := InsereItemNaBaseESeqNome( IdPasta,
                2,  { Tipo }
                FileName,
                ''{Exibe Pastas},
                true{Sequencia Nome});

      NomeNovo := caminho + '\' + FileName;
      if assigned(jsonIn['IN_TEM_VERSIONAMENTO']) and
         ((uppercase(jsonIn['IN_TEM_VERSIONAMENTO'].AsString) = 'TRUE') or
          (uppercase(jsonIn['IN_TEM_VERSIONAMENTO'].AsString) = 'T')) then begin
        // se controla versão tem que atualizar o campo
        // in_cria_versao_atualizada do sistarq para o documento
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.Sql.Text := 'update sistarq set IN_CRIA_VERSAO_ATUALIZADA = ' +
                         quotedStr('S') + ' where ID = ' + intstr(ID);
        Qry.execSql;
      end;
      Versao := LeVersaoDocumento(GetSqlConnection(PegaDirTab),id);
      GravaBinarioVersao(GetSqlConnection(PegaDirAtv),Id,Versao,TempFileName,NovaVersao, GravaMiniatura);
      NomeAntigo := Stringreplace(NomeAntigo,'/','\',[rfReplaceAll]);
      if (length(NomeAntigo) > 1) and (NomeAntigo[1] = '\') then delete(NomeAntigo,1,1);
      NomeNovo := Stringreplace(NomeNovo,'/','\',[rfReplaceAll]);
      if (length(NomeNovo) > 1) and (NomeNovo[1] = '\') then delete(NomeNovo,1,1);

      // Guarda novo nome se não existia ainda ou ficou diferente
      if (Trim(NomeAntigo) = '') or (trim(NomeAntigo) <> NomeNovo) then begin
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.Sql.Text := 'update documento_operacao set NO_DOCUMENTO_SISTARQ =' +
        quotedStr(NomeNovo) +
        ' where NU_PRETENDENTE = ' + quotedStr(NuPretendente) +
        ' and NU_DOCUMENTO = ' + quotedStr(NuDocumento);
        Qry.execSql;
      end;

      // se o documento já existia, alterar o status para alterado
      if Trim(nomeAntigo) > '' then begin
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.sql.text := 'select CO_STATUS_DOC from STATUS_DOCUMENTO where IN_ALTERADO = '+quotedstr('T');
        Qry.open;
        try
          if Qry.isempty then
            StatusAlterado := -1
          else
            StatusAlterado := Qry.fields[0].asinteger;
        finally
          Qry.close;
        end;
        if StatusAlterado >= 0 then begin
          Pretendente := TPretendente.Create;
          try
            if Pretendente.le(NuPretendente,SqlConnection) then begin
              index := Pretendente.DocumentosOperacao.indexof(valint(NuDocumento));
              if index >= 0 then begin
                StatusAnt := Pretendente.DocumentosOperacao[index].doc.CO_STATUS_DOC;
                Pretendente.DocumentosOperacao[index].doc.CO_STATUS_DOC := StatusAlterado;
                Pretendente.grava;
                if StatusAnt <> Pretendente.DocumentosOperacao[index].doc.CO_STATUS_DOC then
                  GeraHistAlteracaoStatusDoc(GetSqlConnection(PegaDirTab),Pretendente.DocumentosOperacao[index].Doc);
              end;
            end;
          finally
            Pretendente.free;
          end;
        end;
      end;

      if trim(NomeAntigo) = ''  then begin
        Msg := 'Inclusão de documento no CheckList';
        Aplic := logAplic_InclusaoDocCheckList;
      end
      else begin
        Msg := 'Alteração de documento no CheckList';
        Aplic := logAplic_AlteracaoDocCheckList;
      end;
      if trim(Msg) > '' then begin
        Xml := TpXml.create;
        Pretendente := TPretendente.create;
        try
          Pretendente.le(NuPretendente,SqlConnection);
          Xml.documentelement.nodename := 'LOG';
          Xml.documentelement.addchild('Documento').asstring := NomeNovo;
          Xml.documentelement.addchild('Operacao').asinteger := Pretendente.Operacao.Cad.NU_OPERACAO;
          Xml.documentelement.addchild('Pretendente').asstring := NuPretendente;
          geralog(Aplic,logseveridade_Aviso,PegaUsuario,
                  Msg,'',
                  Xml,NuPretendente,SqlConnection);
        finally
          Xml.free;
          Pretendente.free;
        end;
      end;


      SqlConnection.Commit(Transacao);
    except
      SqlConnection.RollBack(Transacao);
      raise;
    end;

    jsonOut.add('success').AsBoolean := true;
  finally
    Qry.free;
//    if assigned(FileStream) then
//      FileStream.free;
  end;
end;

procedure PostDocumentoSisat (StreamIn, StreamOut : TStream);
var
   f                     : File of Byte;
  jsonIn,
  jsonOut: TpXml;
  Qry: TSqlQuery;
  IdPai,
  Id,
  IdPasta : Integer;
  caminho,
  TempFileName,
  TempFileNamePdf,
  FileName,
  NomeAntigo,
  NomeNovo : ansistring;
  NuDocumento: integer;
  NuOcorrencia : integer;
  NovaVersao: Integer;
  FileStream: TFileStream;
  Versao: Integer;
  Transacao        : TTransactionDesc;
  SqlConnection    : TSqlConnection;
  Resposta: AnsiString;
  Aplic : TLogAplic;
  Len: Integer;
  Ext : ansistring;
  StatusAlterado : integer;
  TamArquivo : integer;
  DocsOcorrencia : TDocumentosOcorrenciaSisat;
  index : integer;
  StatusAnt : integer;
  extfile,extfileor,lstext : Ansistring;
  Xml : TpXml;
  Msg : string;
  Imv2Pdf : String;
begin
  Get_hora(HoraH);
  NovaVersao := 0;
  Msg := '';
  Caminho := '';
  jsonIn  := TpXml.Create;
  jsonOut := TpXml.Create;
  Qry := TSqlQuery.create(nil);
  TempFileName := makeTempFileName;
  FileStream := TFileStream.Create(TempFileName,fmCreate);
  NomeAntigo := '';
  try
    Transacao.TransactionID   := (Random(1000) + 2);
    Transacao.IsolationLevel  := xilREADCOMMITTED;
    SqlConnection := GetSqlConnection(PegaDirAtv);
    SqlConnection.StartTransaction (Transacao);
    try
      jsonIn.LoadFromStreamWithSize(StreamIn);
      NuOcorrencia := jsonIn['NU_OCORRENCIA'].AsInteger;
      scislib.AbreConexao;
      FileName := jsonIn['FileName'].AsString;

      extfile := UpperCase(StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      extfileor := (StringReplace(ExtractFileExt(FileName),'.','',[rfReplaceAll]));
      lstext := UpperCase(GetEnv('EXTUPLPERMITIDO'));
      if (trim(lstext) <> '') and  (pos(extfile,lstext) <= 0) then
        raise exception.create('Formato de arquivo não permitido. As extensões permitidas são: '+lstext);

      NuDocumento := jsonIn['NU_DOCUMENTO'].AsInteger;

      Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
      Qry.Sql.add('select S.IN_OK from documento_ocorrencia_sisat D');
      Qry.Sql.add('left join STATUS_DOCUMENTO S on S.CO_STATUS_DOC= D.CO_STATUS_DOC');
      Qry.Sql.add('where NU_OCORRENCIA = ' + inttostr(NuOcorrencia));
      Qry.sql.add('and NU_DOCUMENTO = ' + inttostr(NuDocumento));
      Qry.open;
      try
        if Qry.isempty then
          raise exception.create('Documento não encontrado');
        if Qry.fields[0].asstring = 'T' then
          raise exception.create('Documento não pode ser anexado, status OK');
      finally
        Qry.close;
      end;

      if NuDocumento >= 0 then begin
        NomeAntigo := GetNoDocumentoSistArqTarefa(NuOcorrencia,inttostr(NuDocumento));
      end;

      // Procura ID do diretório
      IDPai := GeraIDPaiDocumentosTarefa(SqlConnection,NuOcorrencia);
      if NomeAntigo > '' then
        NomeAntigo := '/'+Stringreplace(NomeAntigo,'\','/',[rfReplaceAll]);

      IdPasta := ForcaPathDocumento(GetSqlConnection(PegaDirAtv),IdPai,Caminho);

      // Tira do buffer de entrada e joga para o arquivo temporario no disco
      FileStream.CopyFrom(StreamIn,StreamIn.Size-StreamIn.Position);
      TamArquivo := FileStream.size;
      FreeAndNil(FileStream);

      if TamArquivo > ObtemTamMaxUpLoad then
        raise exception.create('Arquivo maior que o limite de upload permitido');



      if jsonin['IN_CONVERTE_PDF'].asString = 'T' then begin
         if (uppercase(extfile)='JPG') OR (uppercase(extfile)='JPEG') then begin
           tempfilenamepdf := tempfilename;
           tempfilenamePdf := stringreplace(tempfilenamepdf,'.tmp','',[rfReplaceAll]);
           tempfilenamepdf := tempfilenamepdf+'.pdf';
           AssignFile(f, tempfilename);
           Reset(f);
           if  (GetEnv('CONVERT_TAMANHO_MININO')>'') and (FileSize(f) > StrToInt(GetEnv('CONVERT_TAMANHO_MININO'))) then
             rshell('/usr/bin/convert '+GetEnv('CONVERT_IMG2PDF')+' '+GetEnv('CONVERT_RESIZE')+' '+tempfilename +' '+tempfilenamepdf)
           else 
             rshell('/usr/bin/convert '+GetEnv('CONVERT_IMG2PDF')+' '+tempfilename +' '+tempfilenamepdf);
           tempfilename := tempfilenamepdf;
           filename := StringReplace(filename,extfileor,'pdf',[rfReplaceAll]);
         end;
      end;


      // Se já existir um documento com o nome antigo, pegar o ID
      // manter o nome criado inicialmente mas importar o conteudo do novo documento
      if NomeAntigo > '' then begin
        ID := LeIdDoPath(GetSqlConnection(PegaDirAtv),NomeAntigo,IdPai);
        Ext := ExtractFileExt(FileName);
        FileName := ExtractFileName(NomeAntigo);
        if compareText(Ext,ExtractFileExt(FileName)) <> 0 then begin
          Filename := ChangeFileExt(FileName,Ext);
          if ID > 0 then begin
            // se a extensão mudou, preciso preservar a extensão nova, ou pode dar
            // zebra na vizualiação, já que os visualizadores usam a extensão
            // para saber como abrir a imagem
            Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
            Qry.Sql.Text := 'update sistarq set nome = ' +
                             quotedStr(FileName) + ' where ID = ' + intstr(ID);
            Qry.execSql;
          end;
        end;
      end
      else
        ID := -1;

      // se não achou o ID(documento não existe) ou não foi incluido ainda, inclui
      if id < 0 then
        ID := InsereItemNaBaseESeqNome( IdPasta,
                2,  { Tipo }
                FileName,
                ''{Exibe Pastas},
                true{Sequencia Nome});

      NomeNovo := caminho + '\' + FileName;
      if assigned(jsonIn['IN_TEM_VERSIONAMENTO']) and
         ((uppercase(jsonIn['IN_TEM_VERSIONAMENTO'].AsString) = 'TRUE') or
          (uppercase(jsonIn['IN_TEM_VERSIONAMENTO'].AsString) = 'T')) then begin
        // se controla versão tem que atualizar o campo
        // in_cria_versao_atualizada do sistarq para o documento
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.Sql.Text := 'update sistarq set IN_CRIA_VERSAO_ATUALIZADA = ' +
                         quotedStr('S') + ' where ID = ' + intstr(ID);
        Qry.execSql;
      end;
      Versao := LeVersaoDocumento(GetSqlConnection(PegaDirTab),id);
      GravaBinarioVersao(GetSqlConnection(PegaDirAtv),Id,Versao,TempFileName,NovaVersao);
      NomeAntigo := Stringreplace(NomeAntigo,'/','\',[rfReplaceAll]);
      if (length(NomeAntigo) > 1) and (NomeAntigo[1] = '\') then delete(NomeAntigo,1,1);
      NomeNovo := Stringreplace(NomeNovo,'/','\',[rfReplaceAll]);
      if (length(NomeNovo) > 1) and (NomeNovo[1] = '\') then delete(NomeNovo,1,1);

      // Guarda novo nome se não existia ainda ou ficou diferente
      if (Trim(NomeAntigo) = '') or (trim(NomeAntigo) <> NomeNovo) then begin
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.Sql.Text := 'update documento_ocorrencia_sisat set NO_DOCUMENTO_SISTARQ =' +
        quotedStr(NomeNovo) +
        ' where NU_OCORRENCIA = ' + inttoStr(NuOcorrencia) +
        ' and NU_DOCUMENTO = ' + inttoStr(NuDocumento);
        Qry.execSql;
      end;

      // se o documento já existia, alterar o status para alterado
      if Trim(nomeAntigo) > '' then begin
        Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
        Qry.sql.text := 'select CO_STATUS_DOC from STATUS_DOCUMENTO where IN_ALTERADO = '+quotedstr('T');
        Qry.open;
        try
          if Qry.isempty then
            StatusAlterado := -1
          else
            StatusAlterado := Qry.fields[0].asinteger;
        finally
          Qry.close;
        end;
        if StatusAlterado >= 0 then begin
          DocsOcorrencia := TDocumentosOcorrenciaSisat.Create(nil);
          try
            DocsOcorrencia.le(NuOcorrencia,SqlConnection);
            index := DocsOcorrencia.indexof(NuDocumento);
            if index >= 0 then begin
              StatusAnt := DocsOcorrencia[index].doc.CO_STATUS_DOC;
              DocsOcorrencia[index].doc.CO_STATUS_DOC := StatusAlterado;
              DocsOcorrencia.grava(SqlConnection);
            end;
          finally
            DocsOcorrencia.free;
          end;
        end;
      end;

      // Atualização da DT_RECEBIMENTO para a data de upload do documento
      qry.close;
      qry.sql.clear;
      qry.sql.add('UPDATE DOCUMENTO_OCORRENCIA_SISAT SET');
      qry.sql.add('DT_RECEBIMENTO = :DT_RECEBIMENTO');
      qry.sql.add('WHERE NU_OCORRENCIA = :NU_OCORRENCIA');
      qry.sql.add('  AND NU_DOCUMENTO = :NU_DOCUMENTO');
      qry.paramByName('DT_RECEBIMENTO').dataType := ftDatetime;
      qry.paramByName('NU_OCORRENCIA').dataType := ftInteger;
      qry.paramByName('NU_DOCUMENTO').dataType := ftInteger;
      Qry.parambyname('DT_RECEBIMENTO').asDatetime := Now();
      qry.paramByName('NU_OCORRENCIA').asInteger := NuOcorrencia;
      qry.paramByName('NU_DOCUMENTO').asInteger := NuDocumento;
      Qry.execSql;

      SqlConnection.Commit(Transacao);
    except
      SqlConnection.RollBack(Transacao);
      raise;
    end;
    jsonOut.add('success').AsBoolean := true;
    Resposta := jsonOut.toJson;
    Len := length(Resposta);
    StreamOut.writebuffer(Len,4);
    StreamOut.writebuffer(Resposta[1],Len);
  finally
    jsonIn.free;
    jsonOut.free;
    Qry.free;
    if assigned(FileStream) then
      FileStream.free;
  end;
end;

procedure GetPasta(jsonIn,jsonOut : TpXml);
var
  lixeira,
  dados, 
  dir: tpXmlNode;
  i,id: integer;
  ApenasPastas : Boolean;
begin
  dir := tpXmlNode.Create(nil);
  lixeira := nil;
  ApenasPastas := lib1.strToBool(jsonIn['ApenasPastas'].AsString);
  if jsonIn['node'].AsString = 'root' then id := 0
  else id := jsonIn['node'].asInteger;
  try 
    MontaFilhosDoId(GetSqlConnection(PegaDirTab), false, id, dir, false,false,false,true,false,true);
    for i := 0 to dir.count-1 do
    begin
      if dir[i].attributes['TIPO'] = '3' then // Inclui a lixeira por último
      begin
        lixeira := dir[i];
      end
      else if (Not ApenasPastas) then begin
        dados := jsonOut.add('dados');
        dados.add('text').asString := dir[i].attributes['NOME'];
        dados.add('leaf').asBoolean := dir[i].attributes['TIPO'] <> '1';
        if dir[i].attributes['TIPO'] <> '1' then
          dados.add('iconCls').asString := 'icone-46';
        dados.add('id').asString := dir[i].attributes['ID'];
        dados.add('EXT').asString := apilib.GetExtensaoArquivo(StrToInt(dir[i].attributes['ID']));
      end
      else if (dir[i].attributes['TIPO'] = '1') then begin
        dados := jsonOut.add('dados');
        dados.add('text').asString := dir[i].attributes['NOME'];
        dados.add('leaf').asBoolean := false;
        if dir[i].attributes['TIPO'] <> '1' then
          dados.add('iconCls').asString := 'icone-46';
        dados.add('id').asString := dir[i].attributes['ID'];
      end;
    end;
    if assigned(lixeira) then
    begin
      dados := jsonOut.add('dados');
      dados.add('text').asString := lixeira.attributes['NOME'];
      dados.add('id').asString := lixeira.attributes['ID'];
      dados.add('iconCls').asString := 'icone-60';
      dados.add('EXT').asString := apilib.GetExtensaoArquivo(StrToInt(lixeira.attributes['ID']));
    end;
  finally
    dir.free;
  end;

end;

procedure LeOperacao(Qry : TSqlQuery;Inscricao : string;var TipoOperacao : string;var CoSeguradora : integer);
begin
  Qry.Sql.add('SELECT CO_TIPO_OPERACAO,CO_SEGURADORA FROM OPERACAO_CREDITO');
  Qry.Sql.add('WHERE NU_OPERACAO=:NuOperacao');
  Qry.ParamByName('NuOperacao').asInteger := ValInt(Inscricao);
  Qry.open;
  if not Qry.eof then begin
    TipoOperacao := Qry.FieldByName('CO_TIPO_OPERACAO').asstring;
    CoSeguradora := Qry.FieldByName('CO_SEGURADORA').asinteger;
 end;

  Qry.close;
end;


procedure CPFPessoas(Inscricao : string;Lista :TStringList);
var qry : TsqlQuery;
begin
  qry := TsqlQuery.create(nil);
  try
    qry.sqlconnection := sisatlib.Getconexao;
    Qry.Sql.add('SELECT * FROM PESSOA_PRETENDENTE');
    Qry.Sql.add('WHERE NU_PRETENDENTE ='+QuotedStr(Inscricao));
    Qry.Sql.add('AND (IN_TIPO_PESSOA='+QuotedStr('P'));
    Qry.Sql.add('OR IN_TIPO_PESSOA='+QuotedStr('U')+')');
    Qry.Sql.add(' ORDER BY NU_PESSOA');
    Qry.open;
    while not Qry.eof do begin
      if (Qry.fieldbyname('NU_CONJUGE').asInteger > 0) AND (Qry.fieldbyname('NU_CONJUGE').asInteger > Qry.fieldbyname('NU_PESSOA').asInteger) then    
        Lista.add(Qry.fieldbyname('NU_CPFCNPJ').asString+'=P')
      else
        Lista.add(Qry.fieldbyname('NU_CPFCNPJ').asString+'=C');
     qry.next;
   end;
  finally
    qry.free;
  end;
end;

function pessoatemfgts(pretendente,cpf : string): boolean;
var 
    
  Qry      : TSqlQuery;
begin
  result := false;
  Qry        := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := sisatlib.GetConexao;
    Qry.Sql.add(' SELECT * ');
    Qry.Sql.add(' FROM CONTAOPERFGTS F');
    Qry.Sql.add(' JOIN OPERFGTS O ON O.CODUTILIZACAO = F.CODUTILIZACAO AND O.SEQ = F.SEQ AND O.USADAMP3 = F.USADAMP3');
    Qry.Sql.add(' WHERE F.CPF=:CPF AND O.PRETENDENTE=:PRETENDENTE');
    Qry.ParamByName('CPF').AsString := cpf;
    Qry.ParamByName('PRETENDENTE').AsString := pretendente;
    qry.open;
    if not qry.eof then
    result := true;
  finally
    Qry.free;
  end;
end;


procedure AdicionaDocumentoFgts(
                            pretendente : String;
                            IdDoc : Integer;
                            NomeArq : AnsiString; 
                            Texto : TStringlist;
                            TextoMerge,
                            LstCpf : TStringlist;
                            EdocRtf: Boolean);
var Stream : TMemoryStream;
    i,p : integer;
    subdom,
    cpf,tipopessoa  : String;
begin
  for i := 0 to LstCpf.Count -1 do begin 
    p :=0;
    cpf := palavra(LstCpf[i],1,'=',#255,#255);
    tipopessoa := palavra(LstCpf[i],2,'=',#255,#255);
    if pessoatemfgts(pretendente,cpf) then begin
      if (tipopessoa = 'P') or ((LstCpf.count = 1) and (tipopessoa='C')) then begin
        inc(P);
        subdom := '';
      end else
         subdom := 'Conj';
      if p=0 then p:=1;
      Stream := TMemoryStream.create;
      try
        SaveDocumentoToStream(GetConexao, IDDoc, Stream);
        Stream.Position := 0;
        Texto.loadfromstream(Stream);      
        if subdom <> '' then
          texto.text := StringReplace(texto.text,'P1CONJ_','PX_',[rfReplaceAll,rfIgnoreCase] );
        texto.text := StringReplace(texto.text,'P1_','P'+intstr(p)+subdom+'_',[rfReplaceAll,rfIgnoreCase] );
        if subdom <> '' then
          texto.text := StringReplace(texto.text,'PX_','P'+intstr(p)+'_',[rfReplaceAll,rfIgnoreCase] );
 
      finally
        Stream.free;
      end;  
      umerge.CaracteresDeMerge := ['<'];
      if eDocRtf then
        umerge.LeText(Texto,'.rtf')
      else
        umerge.LeText(Texto);
      umerge.FazMerge(TextoMerge);
      TextoMerge.SaveToFile(NomeArq);
    end;
  end;
end;


function DocSeguroOuFGTS(
                          Diretorio : ansistring;
                          coSeguradora,
                          ndoc : integer): String;
var
  lista : TStringList;
  i : integer;
  idpai,idpaiprincipal,id : integer;
  Pasta : String;

begin
  Pasta := 'ORIGINAÇÃO';
  idpai := LeIDdoDiretorio(sisatlib.Getconexao,Pasta);
  id := LeIDdoDiretorio(sisatlib.Getconexao,Diretorio,IDPAI);
  idpaiprincipal := id;

  if idpaiprincipal > 0 then begin
    lista := TStringList.create;
    try
      ListaArquivosDoDiretorio(GetConexao,idpaiprincipal,Lista);
      if Diretorio = 'Obrigatórios' then begin
        lista.clear;
        id := LeIDdoDiretorio(Getconexao,'Seguros',idpaiprincipal);
        idpai := id;
        id := LeIDdoDiretorio(Getconexao,intStr2(CoSeguradora,3),IDPAI);
        ListaArquivosDoDiretorio(GetConexao,id,Lista);
        result := '';
        for i := 0 to Lista.Count -1 do
           if lib1.palavra(Lista[i],2,'=',#255,#255) = inttostr(ndoc) then
              result := 'S';
        lista.clear;
        id :=LeIDdoDiretorio(Getconexao,'FGTS',idpaiprincipal);
        ListaArquivosDoDiretorio(GetConexao,Id,Lista);
        for i := 0 to Lista.Count -1 do
           if lib1.palavra(Lista[i],2,'=',#255,#255) = inttostr(ndoc) then
              result := 'F';      
      end;
       
    finally
      lista.Free;
    end;
  end
end;

procedure AdicionaDocumento(IdDoc : Integer;
                            NomeArq : AnsiString; 
                            Texto : TStringlist;
                            TextoMerge : TStringlist;
                            EDocRtf: Boolean);
var Stream : TMemoryStream;
begin
    Stream := TMemoryStream.create;
    try
      SaveDocumentoToStream(GetConexao, IDDoc, Stream);
      Stream.Position := 0;
      Texto.loadfromstream(Stream);      
      texto.text := StringReplace(texto.text,'P1','P1CONJ',[rfReplaceAll] );
    finally
      Stream.free;
    end;  
    umerge.CaracteresDeMerge := ['<'];
    if eDocRtf then
      umerge.LeText(Texto,'.rtf')
    else
      umerge.LeText(Texto);
    umerge.FazMerge(TextoMerge);
    TextoMerge.SaveToFile(NomeArq);
end;

function LimpaEspeciais(st : ansistring) : ansistring;
var
  i : integer;
  qtd : integer;
begin
  if st > '' then begin
    result := '';
    qtd := 0;
    setLength(result,length(st)); // alocar o espaço máximo por eficiência de gerenciamento de memória
    for i := 1 to length(st) do
      if (ord(st[i]) >= 32{espaço}) or (ord(st[i]) = 13{Enter}) or (ord(st[i]) = 10{linefeed}) then begin
        inc(qtd);
        result[qtd] := st[i];
      end;
    setLength(result,qtd); // libera o espaço que não foi usado
  end;
end;

procedure PostGeraJasper(jsonIn, jsonOut : TpXml );
// Gera o relatorio e devolve uma tela com o nome de arquivo temporário
var
  frame, iframe: tpXmlNode;
  tela,funcoes,ledados,
  processatela,botoes,botao,dadosOut : TpXmlNode;
  FileName,
  FileNamePdf,
  FileNameErr,
  FileNameFinal: AnsiString;
  Dados: TpXml;
  DadosJson,
  Msg,Aux: AnsiString;
  ErroStr:TStringList;
  f:text;
  sucesso: boolean;
  NomeTela : ansistring;
  CoContrato,
  NuOperacao,
  relatorio : string;
  JsonAux : TpXml;
  PathScciDir : ansistring;
begin
  NomeTela := '';
  FileName := ChangeFileExt(MakeTempFileName,'.json');
  FileNamePdf := ChangeFileExt(FileName,'.pdf');
  FileNameErr := ChangeFileExt(FileName,'.err');
  Msg := '';
  sucesso := true;
  dados := tpXml.Create;
  Aux:='';
  try
    dados.add(jsonIn['dados']);
    dados.documentElement.NodeName := 'dados';

    CoContrato := dados['CO_CONTRATO'].AsString;
    NuOperacao := dados['NU_OPERACAO'].AsString;
    if NuOperacao='' then
      NuOperacao := dados['NU_PRETENDENTE'].AsString;
    if trim(NuOperacao) = '' then
      if trim(dados['NU_PRETENDENTE'].asstring) > '' then
        NuOperacao := intstr(valint(jsonIn['NU_PRETENDENTE'].asstring));
    nomeTela := dados['nomeTela'].AsString;
    relatorio := EliminaEntradaNaoPermitida(JsonIn['relatorio'].AsString);
    if (nomeTela = 'lancamentoVoucher') then
      FileNameFinal := DefineNomeArqDonwload('','','','VOUCHER',false,'')
    else begin
      if (relatorio = 'EXTRATOFGTS.jasper') then
        FileNameFinal := DefineNomeArqDonwload(CoContrato,NuOperacao,scciconf.NSerie,'EXTRATOFGTS',false,'.pdf',true)
      else if (relatorio = 'extrato.jasper') then
        FileNameFinal := DefineNomeArqDonwload(CoContrato,NuOperacao,scciconf.NSerie,'EXTRATO_PRESTACOES_DISPONIVEIS',false,'.pdf',true)
      else if (relatorio = 'prazos.jasper') then
        FileNameFinal := DefineNomeArqDonwload('',NuOperacao,scciconf.NSerie,'PRAZO',false,'.pdf',true)
      else if (relatorio = 'simulacao.jasper') then
        FileNameFinal := DefineNomeArqDonwload('',NuOperacao,scciconf.NSerie,'SIMULACAO',false,'.pdf',true)
      else if (relatorio = 'simulacao_sintetica.jasper') then
        FileNameFinal := DefineNomeArqDonwload('',NuOperacao,scciconf.NSerie,'SIMULACAOSINTETICA',false,'.pdf',true)
      else if (relatorio = 'matriz_risco.jasper') then
        FileNameFinal := DefineNomeArqDonwload('',NuOperacao,scciconf.NSerie,'MATRIZ_RISCO',false,'.pdf',true)
      else if (relatorio = 'LaudoContratacao.jasper') then
        FileNameFinal := DefineNomeArqDonwload('',NuOperacao,scciconf.NSerie,'LAUDO_CONTRATACAO',false,'.pdf',true)
      else
        FileNameFinal := FileNamePdf;
    end;
    nomeTela := '';
    Aux:= AnsiToUtf8(dados.toJson);
    Aux := LimpaEspeciais(Aux);
//    Aux:=stringreplace(Aux, #1, '',[rfReplaceAll, rfIgnoreCase]);
    DadosJson :=Aux;
    assign(f,FileName);
    rewrite(f);
    write(f,DadosJson);
    close(f);
    RodaGeraRelGraficoJar(FileName,
                          Relatorio,
                          FileNamePdf,
                          ''{recordPath},
                          ''{porta},
                          ''{formatoSaida},
                          FileNameErr);
    if FileExists(FileNameErr) then begin
      ErroStr := Tstringlist.create;
      try
        ErroStr.LoadFromFile(FileNameErr);
        if trim(ErroStr.text) > '' then
        begin
          sucesso := false;
          Msg :=  ErroStr.text;
        end;
      finally
        ErroStr.free;
      end;
    end;
  finally
    dados.free;
    (*if (FileName > '') and FileExists(FileName) then
      deletefile(FileName);
    if (FileNameErr > '') and FileExists(FileNameErr) then
      deletefile(FileNameErr);*)
  end;
  jsonOut.add('success').AsBoolean := sucesso;
  
  if (sucesso) then
  begin
    if assigned(jsonIn['tela']) and (jsonIn['tela'].asString > '') then begin
      NomeTela := jsonIn['tela'].asString;
      tela := jsonOut.add('tela');
      funcoes := tela.add('funcoes');
      ledados:= funcoes.add('ledados');
      ledados.attributes.add('unixmtd','GetDadosEntrada');
      processatela := funcoes.add('processatela');
      processatela.attributes.add('unixmtd','PostGeraRelatorioArqsHtml');
      frame := tela.add('frame');
      frame.attributes['titulo'] := ChangeFileExt(jsonIn['relatorio'].AsString,'');
      frame.attributes['maximizado'] := 'T';
      frame.add('width').asString := '2000';
      frame.add('height').asString := '1000';
      botoes := tela.add('botoes');
      botao  := botoes.add('botao');
      botao.attributes.add('titulo','Enviar Email');
      botao.attributes.add('imagem','39');
      botao.attributes.add('hint','Encaminhar documentos por email');
      botao.attributes.add('permissao','2087');
      if UsaDocumentoTemporarioNoBD then
        botao.attributes.add('acao','RModal:wtela/getTela?tela='+nometela+'&amp;NOME=@ID_DOCUMENTO_TEMPORARIO@&amp;CO_CONTRATO=$CO_CONTRATO')
      else
        botao.attributes.add('acao','RModal:wtela/getTela?tela='+nometela+'&amp;NOME='+FileNamePdf+'&amp;CO_CONTRATO=$CO_CONTRATO');
      iframe := frame.add('iframe');
      iframe.add('src').asString := sccidef.PontoMontagemIntegracao+'/sccidoc/wdoc/TempFilePdf?nome=@NOME@&amp;REMOVETEMP=@REMOVETEMP@';
    end
    else begin
      frame:= jsonOut.add('tela').add('frame');
      iframe := frame.add('iframe');
      frame.attributes['titulo'] := ChangeFileExt(jsonIn['relatorio'].AsString,'');
      frame.attributes['emAlteracao'] := 'F';
      frame.add('width').asString := '2000';
      frame.add('height').asString := '1000';
      iframe.add('src').asString := sccidef.PontoMontagemIntegracao+'/sccidoc/wdoc/TempFilePdf?nome=@NOME@&amp;REMOVETEMP=@REMOVETEMP@';
    end;
    JsonAux := TpXml.create;
    try
      JsonAux.add('FILE_NAME').asString := FileNamePdf;
      JsonAux.add('EXT').asString := '.PDF';
      JsonAux.add('NOME_DOWNLOAD').asString := ExtractFileName(FileNameFinal);
      JsonAux.add('SESSIONKEY').asString := jsonIn['sessionKey'].AsString;
      GeraArqComIframe(JsonAux,JsonOut);
      DadosOut := JsonOut.addOrGet('dados');
      if assigned(DadosOut['ID_DOCUMENTO_TEMPORARIO']) and (length(botao.attributes['acao'])>0) then begin
        botao.attributes['acao'] := StringReplace(botao.attributes['acao'],'@ID_DOCUMENTO_TEMPORARIO@',DadosOut['ID_DOCUMENTO_TEMPORARIO'].asString,[rfReplaceAll])
      end;
    finally
      JsonAux.free;
    end;
  end
  else
  begin
    jsonOut.add('message').asString := 'Erro ao criar o relatório';
//    frame.attributes['titulo'] := 'Erro ao criar o relatório';
    jsonOut.add('erro').asString := Msg;
  end;
end;

procedure GetDocumentoTemporario(StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
begin
  jsonIn := TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    if assigned(jsonIn['nome']) and assigned(jsonIn['SESSIONKEY']) then begin
      if (pos('@',jsonIn['nome'].AsString)<=0) and (pos('@',jsonIn['SESSIONKEY'].AsString)<=0) then begin
        SaveDocumentoTemporarioToStream(jsonIn['nome'].AsInteger{ID},jsonIn['SESSIONKEY'].AsString,1{Versao},StreamOut);
      end;
    end;
  finally
    jsonIn.free;
  end;
end;

procedure GetTempFilePdf(StreamIn, StreamOut : TStream);
// Devolve o arquivo pdf e remove o arquivo.
var 
  FileStream: TFileStream;
  FileNamePdf: AnsiString;
  ListaOut: TpMemory;
  jsonIn: TpXml;
  Nome : ansistring;
begin
  jsonIn := TpXml.Create;
  ListaOut := TpMemory.Create;
  try
    if UsaDocumentoTemporarioNoBD then
      GetDocumentoTemporario(StreamIn, StreamOut)
    else begin
      jsonIn.LoadFromStreamWithSize(StreamIn);
      Nome := EliminaEntradaNaoPermitida(jsonIn['nome'].AsString);
      FileNamePdf := extractFilePath(MakeTempFileName)+Nome;
      FileStream := TFileStream.Create(FileNamePdf,fmOpenRead);
      try
        // Parte 1: Retorna o nome e o tipo do arquivo
        if assigned(jsonIn['NomeArqDownload']) then begin
          if pos('@',jsonIn['NomeArqDownload'].AsString)<=0 then begin
            ListaOut.addval('Nome',jsonIn['NomeArqDownload'].AsString);
          end
          else begin
            ListaOut.addval('Nome',jsonIn['nome'].AsString);
          end;
        end
        else begin
          ListaOut.addval('Nome',jsonIn['nome'].AsString);
        end;
        ListaOut.addval('Tipo',extractfileext(FileNamePdf));
        ListaOut.SaveToStreamWithSize(StreamOut);
        // Parte 2: Retorna o binário do arquivo
        StreamOut.CopyFrom(FileStream,0);
      finally
        if jsonin['REMOVETEMP'].AsString <> 'NAO' then begin
          if (filenamePdf > '') and FileExists(FilenamePDF) then
            deletefile(filenamePdf);
        end;
        FileStream.free;
      end;
    end;
  finally
    ListaOut.free;
    JsonIn.free;
  end  
end;




procedure GetDocumentosOriginacaoPdf(StreamIn, StreamOut : TStream);
var
  NuPretendente : ansistring;
  UsaConj : str1;
  Qry : TSqlQuery;
  ListaOut,
  Dados : TpMemory;
  ListaDocs : TStringList;
  NomeArq : ansistring;
  Texto : TStringlist;
  TextoMerge : TStringlist;
  Stream : TStream;
  FileStream : TFileStream;
  i,j,
  IDDoc : integer;
  jsonIn: TpXml;
  diretorio : AnsiString;
  coseguradora : integer;
  tipooperacao : String;
  tipodoc : String;
  LstCpf : TStringList;
  FileNamePdf,
  FileNameErr,
  NomeDoc : String;
  CodHierarquia: Integer;
  EDocRtf: Boolean;
begin
  coseguradora := 0;
  CodHierarquia:= 0;
  tipooperacao := '';
  NomeDoc := '';
  EDocRtf := false;
  jsonIn := TpXml.Create;
  NomeArq := MakeTempFileName;
  FileNamePdf := ChangeFileExt(NomeArq,'.pdf');
  FileNameErr := ChangeFileExt(NomeArq,'.err');
  ListaDocs := TStringlist.create;
  ListaDocs.sorted := true;
  Texto := TStringlist.create;
  TextoMerge := TStringlist.create;
  LstCpf := TStringlist.create;
  Dados := TpMemory.create;
  ListaOut := TpMemory.create;
  Qry := TSqlQuery.create(nil);
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);

    Diretorio := jsonIn['DIRETORIO'].asstring;
    NuPretendente := jsonIn['NU_PRETENDENTE'].asstring;
    UsaConj := jsonIn['USA_CONJ'].asstring;
    Qry.SqlConnection := sisatlib.GetConexao;
    CPFPessoas(NuPretendente,LstCpf);
    LeOperacao(Qry,NuPretendente,TipoOperacao,CoSeguradora);
    if diretorio = '' then
      diretorio := 'Obrigatórios';   
    for i := 0 to jsonIn.documentelement.count-1 do begin
      if uppercase(jsonIn[i].nodename)=uppercase('NU_DOCUMENTO') then begin
        ListaDocs.add(jsonIn[i].nodevalue+'='+
         DocSeguroOuFGTS(Diretorio,coSeguradora,jsonIn[i].asInteger));
      end;
    end;
    DadosPretendente(NuPretendente,Qry.SqlConnection,dados);
    DadosDoOriginacaoFinanc(Qry.SqlConnection,'FINANC.',NuPretendente,Dados);
    try
      for i := 0 to Dados.count -1 do
        umerge.Incluivar(stringreplace(Dados.getvar(i),'.','_',[rfReplaceAll]),
                         Dados.readval(Dados.getvar(i)));
      for j := 0 to ListaDocs.count -1 do begin
        IDDoc := valint(palavra(ListaDocs[j],1,'=',#255,#255));
        TipoDoc := (palavra(ListaDocs[j],2,'=',#255,#255));
        LeDetalhesDocumento( GetConexao, IDDoc, NomeDoc, CodHierarquia);
        EDocRtf :=  extractfileext(NomeDoc) = '.rtf';
        if EDocRtf then
          NomeArq :=  ChangeFileExt(NomeArq,'.rtf')
        else
          NomeArq :=  ChangeFileExt(NomeArq,'.html');

        if TipoDoc = 'F' then begin
          adicionadocumentofgts(NuPretendente,iddoc,nomeArq,texto,textomerge,lstcpf,eDocRtf); 
        end else begin
          Stream := TMemoryStream.create;
          try
            SaveDocumentoToStream(GetConexao, IDDoc, Stream);
            Stream.Position := 0;
            Texto.loadfromstream(Stream);      
          finally
            Stream.free;
          end;  
          umerge.CaracteresDeMerge := ['<'];
          umerge.LeText(Texto, extractfileext(NomeDoc));
          umerge.FazMerge(TextoMerge);
          TextoMerge.SaveToFile(NomeArq);      
          if TipoDoc = 'S' then begin
            if dados.readval('p1conj.IN_EADQUIRENTE') = 'T' then
              adicionadocumento(iddoc,nomeArq,texto,textomerge,eDocRtf); 
          end;     
        end; 
      end;
    finally
      RemoveVars;
      RemoveText;
    end;
    if EDocRtf then
      ConverteRtfEmPdf(NomeArq,FilenameErr)
    else
      ConverteHtmlEmPdf(NomeArq,FileNamePdf,FileNameErr);
    FileStream := TFileStream.Create(FileNamePdf,fmOpenRead);
    try
      // Parte 1: Retorna o nome e o tipo do arquivo
      ListaOut.addval('Nome',FileNamePdf);
      ListaOut.addval('Tipo',extractfileext(FileNamePdf));
      ListaOut.SaveToStreamWithSize(StreamOut);
      // Parte 2: Retorna o binário do arquivo
      StreamOut.CopyFrom(FileStream,0);
    finally
      if (filenamePdf > '') and FileExists(FilenamePDF) then
        deletefile(filenamePdf);
      if (FileNameErr > '') and FileExists(FileNameErr) then
        deletefile(filenameErr);
      FileStream.free;
    end;

  finally
    LstCpf.free;
    Qry.free;
    ListaDocs.free;
    Dados.free;
    Texto.free;
    TextoMerge.free;
    jsonIn.free;
    ListaOut.free;
  end;
  DeleteFile(NomeArq);
end;

procedure PutTelaDocumento( jsonIn, jsonOut : TpXml );
var
  NVersao : Integer;
  SqlConnection : TSqlConnection;
  ID: Integer;
  StringStream : TStringStream;
begin
  SqlConnection := GetSqlConnection(PegaDirTab);
  ID := jsonIn['dados']['ID'].AsInteger;
  NVersao := NovaVersao(SqlConnection,ID);
  StringStream := TStringStream.Create(jsonIn['dados']['TE_DOCUMENTO'].AsString);
  try
    GravaBinarioVersao(SqlConnection,ID,NVersao-1,StringStream,NVersao);
    jsonOut.add('success').AsBoolean := true;
  finally
    StringStream.free;
  end;
end;

function AcharIDPai(SqlConnection : TSqlConnection;Id:Integer):Integer;
var
  Qry : TSqlQuery;
begin
  result := 0;
  Qry := TSqlQuery.create(nil);
  try
    Qry.SqlConnection := SqlConnection;
    Qry.sql.add('SELECT IDPAI FROM SISTARQ');
    Qry.sql.add('WHERE ID = :id');
    Qry.ParamByName('id').AsInteger := Id;
    Qry.open;
    try
      if not Qry.isEmpty then
        result := Qry.FieldByName('IDPAI').AsInteger;
    finally
      Qry.close;
    end;
  finally
    Qry.Free;
  end;
end;

procedure GetTelaPorTipoDocumento( jsonIn, jsonOut: TpXml );
var
  SqlConnection: TSqlConnection;
  ID,
  IDPai : longint;
  TipoDocumento: AnsiString;
  XmlFileName: AnsiString;
  Xml: TpXml;
  iframe,
  funcoes,
  dados: TpXmlNode;
  i,IdFilho: integer;
  Stream : TMemoryStream;
  temStream,Modificou : boolean;
  jsoInAux,
  jsonOutAux:TPXML;
  Filename,
  FileNamePdf,
  FileNameErr : ansistring;
  NomeArqXml : ansistring;
begin
  //testa de foi passado um id valido
  if SoNum(jsonIn['ID'].AsString) <> '' then
  begin
    if assigned(jsonIn['arquivoxml']) and (jsonIn['arquivoxml'].asstring <> '') then
      NomeArqXml := jsonIn['arquivoxml'].asstring
    else
      NomeArqXml := 'frameimagem.xml';
    Stream := TMemoryStream.create;
    temStream := false;
    SqlConnection := GetSqlConnection(PegaDirTab);
    ID := jsonIn['ID'].AsInteger;
    IDPai := AcharIDPai(SqlConnection,ID);
    TipoDocumento := extractfileext(NomeDocumento(GetSqlConnection(PegaDirTab),ID));
    
    Dados := JsonOut['dados'];
    if not assigned(dados) then
      Dados := JsonOut.add('dados');    
    dados.add('EXT').asString := apilib.GetExtensaoArquivo(ID);
    jsonOut.add('EXT').asString := apilib.GetExtensaoArquivo(ID);
    Modificou:=false;
    if((UpCase(TipoDocumento)='.TXT') or (UpCase(TipoDocumento)='.HTML') or (UpCase(TipoDocumento)='.HTM')) then begin
      Modificou:=true;
      Filename := stringreplace(NomeDocumento(GetSqlConnection(PegaDirTab),ID),' ','_',[rfReplaceAll]);
      Filename := stringreplace(Filename,'(','_',[rfReplaceAll]);
      Filename := stringreplace(Filename,')','_',[rfReplaceAll]);
      Filename := '/var/tmp/'+Filename;
      shell('> '+quotedstr(Filename));
      SaveDocumentoToFile(GetSqlConnection(PegaDirTab),ID,Filename);
      FileNamePdf := FileName+ '.pdf';
      FileNameErr := FileName+ '.erroconvpdf';
      if(UpCase(TipoDocumento)='.TXT') then begin
        ConverteTxtEmPdf(FileName,FileNamePdf,FileNameErr,'TEMPPDF.pdf',9)
      end else begin
        shell('> '+quotedstr(FileNamePdf));
        shell('> '+quotedstr(FileNameErr));
        ConverteHtmlEmPDF(FileName,FileNamePdf,FileNameErr);
      end;
      IdFilho:=InsereArquivoVersao(GetSqlConnection(PegaDirTab),IDPai,'TEMPPDF.pdf',FileNamePdf);
      ID:=IdFilho;
      TipoDocumento := extractfileext(NomeDocumento(GetSqlConnection(PegaDirTab),ID));
      jsonIn.addOrget('ID').AsInteger:=ID;
      deletefile(FileNamePdf);
      deletefile(FileName);
      deletefile(FileNameErr);
    end;
    if EImagem(TipoDocumento) or EPdf(TipoDocumento) then
    begin
      xml := TpXml.Create;
      try
        // Lê xml da tela do editor de HTML
       if not LeArqsXml(GetConexao,NomeArqXml,'xmltelas_cliente',Stream) then begin
         if not LeArqsXml(GetConexao,NomeArqxml,'xmltelas',Stream) then begin
           XmlFileName := PegaDirArqs+PathDelim+'xmltelas_cliente'+PathDelim+NomeArqXml;
           if not FileExists(XmlFileName) then
              XmlFileName := PegaDirArqs+PathDelim+'xmltelas'+PathDelim+NomeArqxml;

         end else begin
            XmlFileName := '';
            temStream := true;
         end
        end else begin
            XmlFileName := '';
            temStream := true;
        end;

        if XmlFileName <> '' then
          xml.XmlParseFile(XmlFileName)
        else if temStream then xml.XmlParseStream(Stream);
        processaPermissoes(jsonIn['userName'].AsString,xml.DocumentElement);
        jsonOut.add('tela').AssignAttributesAndChildren(Xml.DocumentElement);
        if (assigned(jsonIn['MODULO_DOCUMENTOS'])) and (lib1.StrToBool(jsonIn['MODULO_DOCUMENTOS'].asString)) then begin
          iframe := jsonOut['tela']['frame']['iframe'];
          if assigned(iframe) then
            iframe.Attributes['src'] := iframe.Attributes['src'] + '&MODULO_DOCUMENTOS=T'
        end;
        // Processa as opções leDados
        funcoes := jsonOut['tela']['funcoes'];
        for i := 0 to funcoes.count-1 do
        begin
          if (funcoes[i].NodeName = 'ledados') or (funcoes[i].NodeName = 'processatela') then
          begin
            Executa(funcoes[i].attributes['unixmtd'],jsonIn,jsonOut);
          end;
        end;
        if not assigned(jsonOut['success']) then
          jsonOut.add('success').AsBoolean := true;
      finally
        Stream.free;
        xml.free;
      end;
    end
    else if EHtml(TipoDocumento) then
    begin
      temStream := false;
      xml := TpXml.Create;
      try
        // Lê xml da tela do editor de HTML
       if not Learqsxml(getconexao,'framedocumentohtml.xml','xmltelas_cliente',Stream) then begin
          if not Learqsxml(getconexao,'framedocumentohtml.xml','xmltelas',Stream) then begin
            XmlFileName := PegaDirArqs+PathDelim+'xmltelas_cliente'+PathDelim+'framedocumentohtml.xml';
            if not FileExists(XmlFileName) then
              XmlFileName := PegaDirArqs+PathDelim+'xmltelas'+PathDelim+'framedocumentohtml.xml';
          end else begin
           temStream := true;
           XmlFileName := '';
          end
       end else begin
           XmlFileName := '';
           temStream := true;
       end;
        If XmlFileName <> '' then
           xml.XmlParseFile(XmlFileName)
        else if temStream then xml.XmlParseStream(Stream);

        processaPermissoes(jsonIn['userName'].AsString,xml.DocumentElement);
        jsonOut.add('tela').AssignAttributesAndChildren(Xml.DocumentElement);
        if (assigned(jsonIn['MODULO_DOCUMENTOS'])) and (lib1.StrToBool(jsonIn['MODULO_DOCUMENTOS'].asString)) then begin
          iframe := jsonOut['tela']['frame']['iframe'];
          if assigned(iframe) then
            iframe.Attributes['src'] := iframe.Attributes['src'] + '&MODULO_DOCUMENTOS=T'
        end;
        GetFormDocumento(jsonIn,jsonOut);
      finally
        xml.free;
      end;
    end
    else
    begin
      jsonOut.add('tela').add('frame').add('label').attributes['texto'] := 'Visualização Não disponível';
      jsonOut.add('success').AsBoolean := true;
    end;
  end
  else
    JsonOut.add('success').AsBoolean := true;
end;

procedure GetTelaDocumentoVersao( jsonIn, jsonOut: TpXml );
var
  SqlConnection: TSqlConnection;
  ID: Longint;
  TipoDocumento: AnsiString;
  XmlFileName: AnsiString;
  Xml: TpXml;
  funcoes: TpXmlNode;
  i: integer;
  Stream : TMemoryStream;
  temStream : boolean;
begin
  Stream := TMemoryStream.create;
  temStream := false;

  SqlConnection := GetSqlConnection(PegaDirTab);
  ID := jsonIn['ID'].AsInteger;
  TipoDocumento := extractfileext(NomeDocumento(SqlConnection,ID));
  if EImagem(TipoDocumento) or EPdf(TipoDocumento) then
  begin
    xml := TpXml.Create;
    try
      // Lê xml da tela do editor de HTML
     if not LeArqsXml(GetConexao,'frameimagemversao.xml','xmltelas_cliente',Stream) then begin
       if not LeArqsXml(GetConexao,'frameimagemversao.xml','xmltelas',Stream) then begin
         XmlFileName := PegaDirArqs+PathDelim+'xmltelas_cliente'+PathDelim+'frameimagemversao.xml';
         if not FileExists(XmlFileName) then
            XmlFileName := PegaDirArqs+PathDelim+'xmltelas'+PathDelim+'frameimagemversao.xml';

       end else begin
          XmlFileName := '';
          temStream := true;
       end
      end else begin
          XmlFileName := '';
          temStream := true;
      end;

      if XmlFileName <> '' then
        xml.XmlParseFile(XmlFileName)
      else if temStream then xml.XmlParseStream(Stream);
      processaPermissoes(jsonIn['userName'].AsString,xml.DocumentElement);
      jsonOut.add('tela').AssignAttributesAndChildren(Xml.DocumentElement);
      // Processa as opções leDados
      funcoes := jsonOut['tela']['funcoes'];
      for i := 0 to funcoes.count-1 do
      begin
        if (funcoes[i].NodeName = 'ledados') or (funcoes[i].NodeName = 'processatela') then
        begin
          Executa(funcoes[i].attributes['unixmtd'],jsonIn,jsonOut);        
        end;
      end;
      if not assigned(jsonOut['success']) then
        jsonOut.add('success').AsBoolean := true;
    finally
      Stream.free; 
      xml.free;
    end;
  end
  else if EHtml(TipoDocumento) then
  begin
    temStream := false;
    xml := TpXml.Create;
    try
      // Lê xml da tela do editor de HTML
     if not Learqsxml(getconexao,'framedocumentohtmlversao.xml','xmltelas_cliente',Stream) then begin
        if not Learqsxml(getconexao,'framedocumentohtmlversao.xml','xmltelas',Stream) then begin
          XmlFileName := PegaDirArqs+PathDelim+'xmltelas_cliente'+PathDelim+'framedocumentohtmlversao.xml';
          if not FileExists(XmlFileName) then
            XmlFileName := PegaDirArqs+PathDelim+'xmltelas'+PathDelim+'framedocumentohtmlversao.xml';
        end else begin
         temStream := true;
         XmlFileName := '';
        end
     end else begin
         XmlFileName := '';
         temStream := true;
     end;
      If XmlFileName <> '' then
         xml.XmlParseFile(XmlFileName)
      else if temStream then xml.XmlParseStream(Stream);

      processaPermissoes(jsonIn['userName'].AsString,xml.DocumentElement);
      jsonOut.add('tela').AssignAttributesAndChildren(Xml.DocumentElement);
      GetFormDocumentoVersao(jsonIn,jsonOut);
    finally
      xml.free;
    end;
  end
  else 
  begin
    jsonOut.add('tela').add('frame').add('label').attributes['texto'] := 'Visualização Não disponível';
    jsonOut.add('success').AsBoolean := true;
  end;
end;



procedure GetVTDOC(StreamIn, StreamOut : TStream);
// Devolve o arquivo pdf e remove o arquivo.
var 
  FileStream: TFileStream;
  FileName: AnsiString;
  ListaOut: TpMemory;
  jsonIn: TpXml;
begin
  jsonIn := TpXml.Create;
  ListaOut := TpMemory.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
//    FileName := '/u10/intermedium2/suporte/scat59434/users/supervisor/OPER0000168561006';
    FileName := JSonIn['arquivo'].AsString;
    FileStream := TFileStream.Create(FileName,fmOpenRead);
    try
      // Parte 1: Retorna o nome e o tipo do arquivo
      ListaOut.addval('Nome',FileName);
      ListaOut.addval('Tipo','.bin');
      ListaOut.SaveToStreamWithSize(StreamOut);
      // Parte 2: Retorna o binário do arquivo
      StreamOut.CopyFrom(FileStream,0);
    finally
      FileStream.free;
    end;
  finally
    ListaOut.free;
    JsonIn.free;
  end  
end;

procedure GetGeraTelaImpressao(JsonIn, JsonOut: TpXml);
var
 i :integer;
 frame : TPXmlNode;
begin
   GetTelaPorTipoDocumento(JsonIn,JsonOut);
   if assigned(JsonOut['tela']) then begin
     frame := procuraNoXml(JsonOut['tela'],'frame');
     //frame.add('width').asString  := '1200';
     //frame.add('height').asString := '700';
     frame.add('maximizado').asString := 'T';
     frame.add('inibeBotaoSalvar').asString := 'T';
   end else raise exception.create('Não foi possível imprimir o documento');
   JsonOut.addorget('success').asBoolean := true;
end;

procedure pegaIdsDocumentosPorGrupo(var ListaIds  : TStringList;
                                    NuGrupoDoc    : Integer; 
                                    NuPretendente : String);
var
  Qry1: TSqlQuery;
  IDPai: integer;
  Caminho: AnsiString;
begin
  IdPai := 0;
  Qry1 := TsqlQuery.create(nil);
  try
    Qry1.SqlConnection := GetSqlConnection(PegaDirTab);

    Qry1.Sql.Add('SELECT ID,NO_DOCUMENTO_SISTARQ');
    Qry1.Sql.Add('FROM DOCUMENTO_OPERACAO');
    Qry1.Sql.Add('WHERE NU_OPERACAO = :NU_OPERACAO');
    Qry1.Sql.Add('AND NO_DOCUMENTO_SISTARQ IS NOT NULL');
    Qry1.Sql.Add('AND NU_GRUPO_DOCUMENTO = :NU_GRUPO_DOCUMENTO');
    Qry1.paramByName('NU_OPERACAO').DataType := ftInteger;
    Qry1.paramByName('NU_GRUPO_DOCUMENTO').DataType := ftInteger;
    Qry1.paramByName('NU_OPERACAO').asInteger := ValInt(NuPretendente);
    Qry1.paramByName('NU_GRUPO_DOCUMENTO').asInteger := NuGrupoDoc;

    IDPai := GeraIDPaiDocumentosPretendente(Qry1.SqlConnection, NuPretendente);
    Qry1.open;
    While (not Qry1.Eof) do begin
      Caminho := Qry1.fieldByName('NO_DOCUMENTO_SISTARQ').asString;
      caminho := '/'+Stringreplace(caminho,'\','/',[rfReplaceAll]);
      ListaIds.add(inttostr(LeIdDoPath(Qry1.sqlConnection, Caminho, IdPai)));
      Qry1.next;
    end;
    Qry1.close;
  finally
    Qry1.free;
  end;
end;

procedure GetDocumentoPorIdParaImpressao(Id:Integer;
                                         var NomeArqSaida : Ansistring;
                                         Primeiro : Boolean = true);
var
  NomeArq,
  FileNamePdf,
  FileNameErr,
  Ext          : AnsiString;
begin
  NomeArq := MakeTempFileName;
  FileNamePdf := ChangeFileExt(NomeArq,'.pdf');
  FileNameErr := ChangeFileExt(NomeArq,'.err');
  try  
    Ext := uppercase(ExtensaoDocumentoID(GetSqlConnection(PegaDirTab),Id));
    if (Ext = '.PDF') then
      wsistarqlib.SaveDocumentoToFile(GetSqlConnection(PegaDirTab),Id,FileNamePdf)
    else
      wsistarqlib.SaveDocumentoToFile(GetSqlConnection(PegaDirTab),Id,NomeArq);

    if (Ext = '.HTML') or
       (Ext = '.HTM') then
      scciio.ConverteHtmlEmPdf(NomeArq,FileNamePdf,FileNameErr)
    else if (Ext = '.RTF') then
      ConverteRtfEmPdf(NomeArq,FileNameErr)
    else if EImagem(Ext) then
      apilib.ConverteImagemEmPdf(NomeArq,FileNamePdf,FileNameErr)
    else if (Ext = '.TXT') then
      apiscci.ConverteTxtEmPdf(NomeArq,FileNamePdf,FileNameErr);

    if primeiro then
      shell('cp '+FileNamePdf+' '+NomeArqSaida + ' 2>'+filenameErr)
    else
      catPdf(FileNamePdf,NomeArqSaida,filenameErr);
  finally
    if (NomeArq > '') and FileExists(NomeArq) then
      deletefile(NomeArq);
    if (filenamePdf > '') and FileExists(FilenamePDF) then
      deletefile(filenamePdf);
    if (FileNameErr > '') and FileExists(FileNameErr) then
      deletefile(filenameErr);
  end;
end;

procedure GetTodosDocumentosOperacaoPorDiretorio(StreamIn, StreamOut : TStream);
var
  JsonIn         : TpXml;
  i,
  Id,
  NuGrupoDoc     : Integer;
  NuPretendente  : String;
  ListaIds       : TStringList;
  Primeiro       : boolean;
  FileStream     : TFileStream;
  ListaOut       : TPMemory;
  TituloJanela,
  NomeArqTempPdf : AnsiString;
begin
  ListaIds := TStringList.create;
  NomeArqTempPdf := ChangeFileExt(MakeTempFileName,'.pdf');
  Primeiro := true;
  ListaOut := TPMemory.create;
  jsonIn:= TpXml.Create;
  try
    JsonIn.LoadFromStreamWithSize(StreamIn);

    NuGrupoDoc := JsonIn['NU_GRUPO_DOCUMENTO'].asInteger;
    NuPretendente := JsonIn['NU_PRETENDENTE'].asString;
    TituloJanela := 'Documentos Proponente';
    pegaIdsDocumentosPorGrupo(ListaIds,NuGrupoDoc,NuPretendente);
    for i:=0 to ListaIds.count-1 do begin
      GetDocumentoPorIdParaImpressao(StrToInt(ListaIds[i]),NomeArqTempPdf,Primeiro);
      Primeiro := false;
    end;
    FileStream := TFileStream.create(NomeArqTempPdf,fmOpenRead or fmShareDenyNone);
    ListaOut.addval('Nome',TituloJanela);
    ListaOut.addval('Tipo',extractfileext(NomeArqTempPdf));
    ListaOut.addval('Titulo',TituloJanela);
    ListaOut.SaveToStreamWithSize(StreamOut);
    StreamOut.CopyFrom(FileStream,0);
  finally
    jsonIn.Free;
    ListaOut.free;
    if (NomeArqTempPdf > '') and FileExists(NomeArqTempPdf) then
      deletefile(NomeArqTempPdf);
  end;
end;

// Pega um documento e retorna o documento em StreamOut:
//   1. O nome do arquivo dentro de um xml em o tamanho na primeira posição
//   2. O binário do arquivo
procedure GetDocumentoPorCoGrupoTipoOperacao(CoGrupoTipoOperacao:String;
                                             StreamOut:TStream);
var
  Qry          : TSqlQuery;
  Listaout     : TScciMemory;
  MemoryStream : TMemoryStream;
  StreamArq    : TStream;
begin
  Qry := TSqlQuery.create(nil);
  ListaOut := TScciMemory.Create;
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirAtv);
    Qry.Sql.Text := 'select * from GRUPO_TIPO_OPERACAO '+
                    'where CO_GRUPO_TIPO_OPERACAO=:CO_GRUPO_TIPO_OPERACAO';
    Qry.ParamByName('CO_GRUPO_TIPO_OPERACAO').DataType := ftString;
    Qry.ParamByName('CO_GRUPO_TIPO_OPERACAO').asString := CoGrupoTipoOperacao;
    Qry.Open;
    if not Qry.Eof then begin
      ListaOut.Addval('Tipo','.png');
      ListaOut.Addval('nome',CoGrupoTipoOperacao+'.png');
      ListaOut.SaveToStreamWithSize(StreamOut);
  
      StreamArq := StreamOut; 
      try  
        TBlobField(Qry.fieldbyname('IM_GRUPO_TIPO_OPERACAO')).savetostream(StreamArq);
      finally
      end;
    end else begin  // O Documento não foi encontrado
      raise exception.create('Visualização não disponível');
    end;
    Qry.close;
  finally
    Qry.free;
    ListaOut.Free;
  end;
end;

procedure GetImagemGrupoTipoOperacao (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  CoGrupoTipoOperacao: String;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    CoGrupoTipoOperacao := jsonIn['CO_GRUPO_TIPO_OPERACAO'].AsString;
    streamout.size := 0;
    GetDocumentoPorCoGrupoTipoOperacao(CoGrupoTipoOperacao,StreamOut);
  finally
    jsonIn.Free;
  end;
end;

procedure GetXmlContratoArisp (StreamIn, StreamOut : TStream);
var
  jsonIn: TpXml;
  contrato: String;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    contrato := jsonIn['CO_CONTRATO'].AsString;
    streamout.size := 0;
    apilib.GetGeraInterfaceArisp(StreamIn,StreamOut);
  finally
    jsonIn.Free;
  end;
end;



procedure PostImagemGrupoTipoOperacao (StreamIn, StreamOut : TStream);
var
  Qry : TsqlQuery;
  JsonIn,
  JsonOut : TpXml;
  CoGrupoTipoOperacao : String;
  FileName,
  Resposta : Ansistring;
  FileStream : TFileStream;
  Len : Integer;
begin
  JsonIn := TpXml.Create;
  JsonOut := TpXml.Create;

  Qry   := TsqlQuery.create(nil);
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    CoGrupoTipoOperacao := jsonIn['CO_GRUPO_TIPO_OPERACAO'].AsString;
    
    FileName := makeTempFileName;
    FileStream := TFileStream.create(FileName,fmCreate or fmOpenRead or FmShareDenyNone);
    FileStream.CopyFrom(StreamIn,StreamIn.Size-StreamIn.Position);

    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.sql.add('UPDATE GRUPO_TIPO_OPERACAO');
    Qry.sql.add('SET IM_GRUPO_TIPO_OPERACAO=:IM_GRUPO_TIPO_OPERACAO');
    Qry.sql.add('WHERE CO_GRUPO_TIPO_OPERACAO=:CO_GRUPO_TIPO_OPERACAO');

    Qry.ParamByName('IM_GRUPO_TIPO_OPERACAO').DataType := ftBlob;
    Qry.ParamByName('CO_GRUPO_TIPO_OPERACAO').DataType := ftString;
    if (FileStream <> nil) then
      Qry.ParamByName('IM_GRUPO_TIPO_OPERACAO').loadfromstream(FileStream,ftblob)
    else Qry.ParamByName('IM_GRUPO_TIPO_OPERACAO').asBlob := BytesOf( '');
    Qry.ParamByName('CO_GRUPO_TIPO_OPERACAO').asString := CoGrupoTipoOperacao;

    Qry.ExecSql;
  finally
    Qry.free;
    FileStream.free;
  end;
  jsonOut.add('success').AsBoolean := true;
  Resposta := JsonOut.toJson;
  Len := length(Resposta);
  StreamOut.writebuffer(Len,4);
  StreamOut.writebuffer(Resposta[1],Len);
end;

procedure GetImagemSeguradora (StreamIn, StreamOut : TStream);
var
  jsonIn        : TpXml;
  CoSeguradora  : String;
  Qry           : TSqlQuery;
  ListaOut      : TScciMemory;
  MemoryStream  : TMemoryStream;
  StreamArq     : TStream;
begin
// Este protocolo é diferente. Na entrada e saida espera-se um xml ou json precedido do tamanho de caracteres
// seguido do arquivo binário
  jsonIn:= TpXml.Create;
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    CoSeguradora := jsonIn['CO_SEGURADORA'].AsString;
    streamout.size := 0;
    Qry := TSqlQuery.create(nil);
    ListaOut := TScciMemory.Create;
    try
      Qry.SqlConnection := GetSqlConnection(PegaDirTab);
      Qry.Sql.Add('SELECT IM_SEGURADORA FROM SEGURA');
      Qry.Sql.Add('WHERE CODIGO=:coSeguradora');
      Qry.ParamByName('coSeguradora').DataType := ftInteger;
      Qry.ParamByName('coSeguradora').asInteger := ValInt(CoSeguradora);
      Qry.Open;
      if not Qry.eof then begin
        ListaOut.Addval('Tipo','.png');
        ListaOut.Addval('nome',CoSeguradora+'.png');
        ListaOut.SaveToStreamWithSize(StreamOut);
        StreamArq := StreamOut;
        try
          TBlobField(Qry.fieldByName('IM_SEGURADORA')).saveToStream(StreamArq);
        finally
        end;
      end else begin //Documento nao encontrato
        raise exception.create('Visualização não disponível');
      end;
      Qry.close;
    finally
      Qry.free;
      ListaOut.free;
    end;
  finally
    jsonIn.Free;
  end;
end;

procedure PostImagemSeguradora (StreamIn, StreamOut : TStream);
var
  Qry : TsqlQuery;
  JsonIn,
  JsonOut : TpXml;
  CoSeguradora : String;
  FileName,
  Resposta : Ansistring;
  FileStream : TFileStream;
  Len : Integer;
begin
  JsonIn := TpXml.Create;
  JsonOut := TpXml.Create;

  Qry   := TsqlQuery.create(nil);
  try
    jsonIn.LoadFromStreamWithSize(StreamIn);
    CoSeguradora := jsonIn['CO_SEGURADORA'].asString;

    FileName := makeTempFileName;
    FileStream := TFileStream.create(FileName,fmCreate or fmOpenRead or FmShareDenyNone);
    FileStream.CopyFrom(StreamIn,StreamIn.Size-StreamIn.Position);

    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    Qry.sql.add('UPDATE SEGURA');
    Qry.sql.add('SET IM_SEGURADORA=:IM_SEGURADORA');
    Qry.sql.add('WHERE CODIGO=:CO_SEGURADORA');

    Qry.ParamByName('IM_SEGURADORA').DataType := ftBlob;
    Qry.ParamByName('CO_SEGURADORA').DataType := ftInteger;
    if (FileStream <> nil) then
      Qry.ParamByName('IM_SEGURADORA').loadfromstream(FileStream,ftblob)
    else Qry.ParamByName('IM_SEGURADORA').asBlob := BytesOf( '');
    Qry.ParamByName('CO_SEGURADORA').asInteger := ValInt(CoSeguradora);

    Qry.ExecSql;
  finally
    Qry.free;
    FileStream.free;
  end;
  jsonOut.add('success').AsBoolean := true;
  Resposta := JsonOut.toJson;
  Len := length(Resposta);
  StreamOut.writebuffer(Len,4);
  StreamOut.writebuffer(Resposta[1],Len);
end;

procedure GeraArqTmp(Id : Integer;var fileNameFS : TFileName;Formato : string = '');
var
 FileStream   : TFileStream;
begin
  try
    FileNameFS := MakeTempFileName;
    if Formato='TXT' then FileNameFS := ChangeFileExt(FileNameFS,'.txt');
    try
      SaveDocumentoToFile(GetSqlConnection(PegaDirTab), Id, FileNameFS);
      FileStream := TFileStream.create(FileNameFS,fmOpenRead or fmShareDenyNone);
      FileStream.free;
    except
    end;    
  finally
  end;
end;

procedure GetSaidaRelatorioIframe(JsonIn,JsonOut : TpXml);
var
  Usuario,
  Diretorio : ansistring;
  ID : longint;
  i,
  IDSISTARQ : integer;
  Ma : TMes_Ano;
  Qry : TsqlQuery;
  Erro : TStringStream;
  Split : TStringArray;
  fileNameFS   : TFileName;
begin
  Ma := default(TMes_Ano);  
  fileNameFS := '';
  AbreTabTxt(PegaDirTab);
  AbreTabImp(PegaDirTab);
  Qry := TSqlQuery.create(nil);
  try
    usuario := JsonIn['userName'].asString;
    ID := JsonIn['id'].asInteger;
    Qry.SqlConnection := getSqlConnection(PegaDirTab);
    Qry.sql.add('SELECT RELATORIO,DIRETORIO,ERRO,EXITCODE,FIM,TITULO FROM ANDAMENTO_RELATORIO');
    Qry.sql.add('WHERE (USUARIO=:USUARIO) AND (ID = :ID)');
    Qry.ParamByName('Usuario').asstring := usuario;
    Qry.ParamByName('ID').asinteger := ID;
    Qry.Open;
    if Qry.isempty then
      raise exception.create('Relatório inexistente.');
    if qry.fieldbyname('FIM').isNull then
      raise exception.create('Relatório ainda não foi concluído.')
    else if qry.fieldbyname('EXITCODE').asinteger > 0 then
    begin
      if Qry.FieldByName('Erro').isNull then
        raise exception.create('Erro desconhecido.')
      else
      begin
        Erro := TStringStream.create('');
        try
          TBlobField(Qry.FieldByName('ERRO')).SaveToStream(Erro);
            raise exception.create('O seguinte erro ocorreu durante a execução do relatório:'+#13+Erro.DataString);
        finally
          erro.free;
        end;
      end;
    end
    else begin
      Diretorio := Qry.FieldByname('DIRETORIO').asstring;
      Diretorio := stringreplace(Diretorio,'SISTARQ:','',[rfReplaceAll]);
      if pos(':',Diretorio)>0 then begin
        Split := Diretorio.Split(':');
        for i:=0 to length(split)-1 do begin
          if Split[i] > '' then begin
            IDSISTARQ := StrToInt(Split[i]);
            GeraArqTmp(IDSISTARQ,fileNameFS,JsonIn['FORMATO'].asString);
            GetMontaTelaEspelhoLote(MA, fileNameFS, Qry.FieldByname('RELATORIO').asstring, 5.9, jsonOut,JsonIn['sessionKey'].asString,JsonIn['FORMATO'].asString);
            if (trim(JsonIn['FORMATO'].asString)='') and FileExists(FileNameFS) then deletefile(FileNameFS);
          end;
        end;  
      end else begin
        IDSISTARQ := strtoint(Diretorio);
        GeraArqTmp(IDSISTARQ,fileNameFS,JsonIn['FORMATO'].asString);
        GetMontaTelaEspelhoLote(MA, fileNameFS, Qry.FieldByname('RELATORIO').asstring, 5.9, jsonOut,JsonIn['sessionKey'].asString,JsonIn['FORMATO'].asString);
        if (trim(JsonIn['FORMATO'].asString)='') and FileExists(FileNameFS) then deletefile(FileNameFS);
      end;
    end;
  finally
    Qry.free;
  end;
end;

procedure RetornaDadosArvorePorNome(DadosArquivos: TpXmlNode ; StringBusca : String);
var
  Qry : TFastSqlQuery;
  Dados : TpXmlNode;
begin
  Qry := TFastSqlQuery.create(nil);
  try
    Qry.SqlConnection := GetSqlConnection(PegaDirTab);
    if (uppercase(Qry.SqlConnection.DriverName) = 'INTERBASE') or (uppercase(Qry.SqlConnection.DriverName) = 'POSTGRES') then
      Qry.sql.add('WITH RECURSIVE arvore_documentos(id, idpai, nome,tipo,nivel) AS (')
    else
      Qry.sql.add('WITH arvore_documentos(id, idpai, nome,tipo,nivel) AS (');
    Qry.sql.add('SELECT id, idpai, nome, tipo, 0 AS nivel');
    Qry.sql.add('FROM SISTARQ');
    Qry.sql.add('WHERE UPPER(nome) LIKE :QUERY_STRING AND IDPAI >= 0');
    Qry.sql.add('UNION ALL');
    Qry.sql.add('SELECT s.id, s.idpai, s.nome, s.tipo, ad.nivel + 1');
    Qry.sql.add('FROM SISTARQ s');
    Qry.sql.add('JOIN arvore_documentos ad ON s.id = ad.idpai');
    Qry.sql.add('WHERE s.id <> s.idpai )');
    Qry.sql.add('SELECT DISTINCT  id, idpai, nome, tipo, nivel');
    Qry.sql.add('FROM arvore_documentos');
    Qry.sql.add('ORDER BY nivel DESC');
    Qry.ParamByName('QUERY_STRING').asString := '%'+StringBusca+'%';
    Qry.open;
    while not Qry.eof do begin
      Dados := DadosArquivos.add('DADOS_SISTARQ');
      Dados.attributes['NOME'] := Qry.fieldByName('nome').asString;
      Dados.attributes['ID'] := Qry.fieldByName('id').asString;
      Dados.attributes['IDPAI'] := Qry.fieldByName('idpai').asString;
      Dados.attributes['TIPO'] := Qry.fieldByName('tipo').asString;
      Dados.attributes['NIVEL'] := Qry.fieldByName('nivel').asString;
      Qry.next;
    end;
  finally
    Qry.free;
  end;
end;

procedure MontaArvoreDeDocumentos(NoRaiz,Pai,DadosArquivos :TpxmlNode ;  meuIdx : LongInt);
var
  i : LongInt;
  dados,
  NO : TpXmlNode;
begin
  No := DadosArquivos[meuIdx];
  if No.attributes['IDPAI'] = '0' then
    dados := NoRaiz.add('children')
  else if Assigned(Pai) then
    dados := Pai.add('children')
  else
    dados := NoRaiz.add('children');
  dados.add('text').asString := No.attributes['NOME'];
  if No.attributes['TIPO'] = '3' then begin
    dados.add('leaf').asBoolean:= false;
    dados.add('iconCls').asString := 'icone-60';
    dados.add('expanded').asBoolean:= true;
  end
  else if No.attributes['TIPO'] <> '1' then begin
    dados.add('leaf').asBoolean:= true;
    dados.add('iconCls').asString := 'icone-46';
    dados.add('expanded').asBoolean:= true;
  end
  else begin
    dados.add('leaf').asBoolean:= false;
    dados.add('expanded').asBoolean:= true;
  end;
  dados.add('id').asString := No.attributes['ID'];
  dados.add('EXT').asString := uppercase(ExtractFileExt(No.attributes['NOME']));
  for i := meuIdx +1 to DadosArquivos.count -1 do begin
    if No.attributes['ID'] = DadosArquivos[i].attributes['IDPAI'] then  
      MontaArvoreDeDocumentos(NoRaiz,dados,DadosArquivos,i)
    else if DadosArquivos[i].attributes['IDPAI'] = '0' then
      MontaArvoreDeDocumentos(NoRaiz,dados,DadosArquivos,i);
  end;
end;

procedure GetDocumentosSistArq(JsonIn,JsonOut : TpXml);
var
  Qry : TFastSqlQuery;
  DadosArquivos,
  NoRaiz,DadosRaiz: TpXmlNode;
  search : String;
  id_raiz : LongInt;
begin
  DadosArquivos := TpXmlNode.create(nil);
  DadosRaiz := TpXmlNode.create(nil);
  if Assigned(JsonIn['search']) then
    search := upStr(Trim(JsonIn['search'].asString))
  else
    search := '';
  if Assigned(JsonIn['IDRAIZ']) then
    id_raiz := JsonIn['IDRAIZ'].asInteger
  else
    id_raiz := 0;
  if Length(search) > 2 then
  begin
    try
      RetornaDadosArvorePorNome(DadosArquivos,search);
      if DadosArquivos.count > 0 then begin
        if DadosArquivos.count < 150 then begin
          MontaRaiz(GetSqlConnection(PegaDirTab),False,DadosRaiz,id_raiz, false,true);
          NoRaiz := jsonOut.add('dados');
          NoRaiz.add('expanded').asBoolean := true;
          NoRaiz.add('text').asString :=DadosRaiz[0].attributes['NOME'];
          MontaArvoreDeDocumentos(NoRaiz,nil,DadosArquivos,id_raiz);
        end else begin
          jsonOut.addOrGet('success').AsBoolean := false;
          jsonOut.addOrGet('message').asString := 'Desculpe, muitos resultados encontrados. Tente uma palavra menos abrangente.';
        end;
      end;
    finally
      DadosArquivos.free;
    end;
  end else begin
    jsonOut.addOrGet('message').asString := 'Busque uma palavra com mais de 3 caracteres!';
    jsonOut.addOrGet('success').AsBoolean := false;
  end;
  if not Assigned(jsonOut['success']) then jsonOut.add('success').AsBoolean := true;
end;

procedure PostExportarDocumentoIFrame(StreamIn, StreamOut: TStream);
var
  jsonIn,
  JsonOut : TpXml;

  FileStream: TFileStream;
  TempFileName,
  AuxFileName,
  FileName, Resposta : AnsiString;
  Len : Longint;
  dados : TPXMLNode;
  aux: AnsiString;
  i : integer;
begin
  JsonIn := TPXML.Create;
  JsonOut := TPXML.Create;
  try
    JsonIn.LoadFromStreamWithSize(StreamIn);
    aux:= JsonIn['NomeArqDownload'].AsString;
    if aux = '' then raise exception.create('Erro ao obter o nome do Arquivo!'); 
    AuxFileName := makeTempFileName;
    TempFileName := ExtractFilePath(AuxFileName)+aux;
    FileStream := TFileStream.Create(TempFileName,fmCreate or fmOpenRead or fmShareDenyNone);
    try
      FileStream.CopyFrom(StreamIn,StreamIn.Size-StreamIn.Position);
    finally
      FileStream.Free;
    end;
    JsonIn.AddOrGet('FilePathName').asString := TempFileName;
    PostExportarDocumento(JsonIn,JsonOut);
    Resposta := jsonOut.toJson;
    Len := length(Resposta);
    StreamOut.writebuffer(Len,4);
    StreamOut.writebuffer(Resposta[1],Len);

  finally
    JsonOut.Free;
    JsonIn.Free;
  end;
end;

procedure GetDocumentoOperacaoPorGrupo(StreamIn, StreamOut : TStream);
var
  JsonIn: TpXml;
  Qry : TSqlQuery;
  NuDocumento: integer;
  StreamAux: TMemoryStream;
begin
  Qry := TSqlQuery.create(nil);
  NuDocumento := 0;
  jsonin := TpXml.create;
  StreamAux := TMemoryStream.create;
  try
    jsonIn.loadFromStreamWithSize(StreamIn);
    Qry.sqlConnection := GetSqlConnection(PegaDIrTab);
    Qry.sql.add('SELECT NU_DOCUMENTO FROM DOCUMENTO_OPERACAO');
    Qry.sql.add('WHERE NU_DOCUMENTO_GRUPO_DOC=:num');
    Qry.sql.add('AND NU_PRETENDENTE=:pret');
    Qry.paramByName('num').asInteger := JsonIn['NU_DOCUMENTO_GRUPO_DOC'].asInteger;
    Qry.paramByName('pret').asString := JsonIn['NU_PRETENDENTE'].asString;
    Qry.open;
    if not Qry.eof then begin
      nuDocumento := Qry.fieldBYName('NU_DOCUMENTO').asInteger;
    end;
    Qry.close;
    if NuDocumento > 0 then begin
      jsonIn.add('NU_DOCUMENTO').asInteger := NuDocumento;
      JsonIn.saveToStreamWithSize(StreamAux);
      StreamAux.position := 0;
      GetDocumentoOperacao(StreamAux, StreamOut);
    end;
  finally
    Qry.free;
    jsonIn.free;
    StreamAux.free;
  end;
end;

{--------------------------------------------------------------------------}
begin
  Registra ('GetDocumento',{$IFDEF FPC}@{$ENDIF}GetDocumento);
  Registra ('GetDocumentoVersao',{$IFDEF FPC}@{$ENDIF}GetDocumentoVersao);
  Registra ('GetDocumentoOperacao',{$IFDEF FPC}@{$ENDIF}getDocumentoOperacao);
  Registra ('GetDocumentoOperacaoAssinatura',{$IFDEF FPC}@{$ENDIF}getDocumentoOperacaoAssinatura);
  Registra ('GetDocumentoContratoAssinatura',{$IFDEF FPC}@{$ENDIF}getDocumentoContratoAssinatura);
  Registra ('GetDocumentoSisat',{$IFDEF FPC}@{$ENDIF}getDocumentoSisat);
  Registra ('PostDocumentoOperacao',{$IFDEF FPC}@{$ENDIF}PostDocumentoOperacao);
  Registra ('PostDocumentoOperacaoAssinatura',{$IFDEF FPC}@{$ENDIF}PostDocumentoOperacaoAssinatura);
  Registra ('PostDocumentoContratoAssinatura',{$IFDEF FPC}@{$ENDIF}PostDocumentoContratoAssinatura);
  Registra ('PostDocumentoSisat',{$IFDEF FPC}@{$ENDIF}PostDocumentoSisat);
  Registra ('GetRelatorioPdf',{$IFDEF FPC}@{$ENDIF}GetRelatorioPdf);
  Registra ('GetRelatorioCsv',{$IFDEF FPC}@{$ENDIF}GetRelatorioCsv);
  Registra ('GetSaidaRelatorio',{$IFDEF FPC}@{$ENDIF}GetSaidaRelatorio);
  Registra ('GetPasta',{$IFDEF FPC}@{$ENDIF}GetPasta);
  Registra ('GetDocumentosOriginacaoPdf',{$IFDEF FPC}@{$ENDIF}GetDocumentosOriginacaoPdf);
  Registra ('GetDocumentoEmPdf',{$IFDEF FPC}@{$ENDIF}GetDocumentoEmPdf);
  Registra ('PutTelaDocumento',{$IFDEF FPC}@{$ENDIF}PutTelaDocumento);
  Registra ('GetGeraJasper',{$IFDEF FPC}@{$ENDIF}PostGeraJasper);
  Registra ('PostGeraJasper',{$IFDEF FPC}@{$ENDIF}PostGeraJasper);
  Registra ('GetTempFilePdf',{$IFDEF FPC}@{$ENDIF}GetTempFilePdf);
  Registra ('GetDocumentoTemporario',{$IFDEF FPC}@{$ENDIF}GetDocumentoTemporario);
  Registra ('GetVTDOC',{$IFDEF FPC}@{$ENDIF}GetVTDOC);
  Registra ('GetTelaPorTipoDocumento',{$IFDEF FPC}@{$ENDIF}GetTelaPorTipoDocumento);
  Registra ('TrocaId',{$IFDEF FPC}@{$ENDIF}apilib.TrocaId);
  Registra ('TrocaIdVersao',{$IFDEF FPC}@{$ENDIF}apilib.TrocaIdVersao);
  Registra ('GetDocumentoComMergeRtf',{$IFDEF FPC}@{$ENDIF}apilib.GetDocumentoComMergeRtf);
  Registra ('GetDocumentoComMergeHTML',{$IFDEF FPC}@{$ENDIF}apilib.GetDocumentoComMergeHTML);
  Registra ('PutPasta',{$IFDEF FPC}@{$ENDIF}apiscci.PutPasta);
  Registra ('PutNome',{$IFDEF FPC}@{$ENDIF}apiscci.PutNome);
  Registra ('DeleteDocumento',{$IFDEF FPC}@{$ENDIF}apiscci.DeleteDocumento);
  Registra ('PostDocumento',{$IFDEF FPC}@{$ENDIF}apiscci.PostDocumento);
  Registra ('GetDocumentoExport',{$IFDEF FPC}@{$ENDIF}apiscci.GetDocumentoExport);
  Registra ('GetEstruturaAtualizada',{$IFDEF FPC}@{$ENDIF}apiscci.GetEstruturaAtualizada);
  Registra ('GetGeraTelaImpressao',{$IFDEF FPC}@{$ENDIF}GetGeraTelaImpressao);
  Registra ('GetDocumentoComMergeRtfGen',{$IFDEF FPC}@{$ENDIF}apilib.GetDocumentoComMergeRtfGen);
  Registra ('GetImagemGrupoTipoOperacao',{$IFDEF FPC}@{$ENDIF}GetImagemGrupoTipoOperacao);
  Registra ('PostImagemGrupoTipoOperacao',{$IFDEF FPC}@{$ENDIF}PostImagemGrupoTipoOperacao);
  Registra ('PutDocumentoOperacaoARISP',{$IFDEF FPC}@{$ENDIF}PutDocumentoOperacaoARISP);
  Registra ('GetImagemSeguradora',{$IFDEF FPC}@{$ENDIF}GetImagemSeguradora);
  Registra ('PostImagemSeguradora',{$IFDEF FPC}@{$ENDIF}PostImagemSeguradora);
  Registra ('GetDocumentoOperacaoPorGrupo',{$IFDEF FPC}@{$ENDIF}GetDocumentoOperacaoPorGrupo);
 
  // Rotinas acessíveis para a GetDocumentoComMergeRtf
  Registra('GetPretendenteParaImpressaoCompleta',{$IFDEF FPC}@{$ENDIF}dadospretendlib.GetPretendenteParaImpressaoCompleta);
  Registra('GetPretendenteParaImpressao',{$IFDEF FPC}@{$ENDIF}dadospretendlib.GetPretendenteParaImpressao);
  Registra('GetPretendente',{$IFDEF FPC}@{$ENDIF}dadospretendlib.GetPretendente1);
  Registra('GetTelaDocumentoVersao',{$IFDEF FPC}@{$ENDIF}GetTelaDocumentoVersao);
  Registra('GetGerarDocumentoCRIM',{$IFDEF FPC}@{$ENDIF}apilib.GetDownloadDocumentosPretendente);
  Registra('GetTodosDocumentosOperacaoPorDiretorio',{$IFDEF FPC}@{$ENDIF}GetTodosDocumentosOperacaoPorDiretorio);
  Registra('GetXmlContratoArisp',{$IFDEF FPC}@{$ENDIF}GetXmlContratoArisp);
  Registra('GetDemonstrativoCET',{$IFDEF FPC}@{$ENDIF}apilib.GetDemonstrativoCET);
  Registra('GetPermissaoAssinaturaDocumento',{$IFDEF FPC}@{$ENDIF}apilib.GetPermissaoAssinaturaDocumento);
  Registra('TrocaIdContratoAssinatura',{$IFDEF FPC}@{$ENDIF}apilib.TrocaIdContratoAssinatura);
  Registra('GetSaidaRelatorioIframe',{$IFDEF FPC}@{$ENDIF}GetSaidaRelatorioIframe);
  Registra('GetDocumentosSistArq',{$IFDEF FPC}@{$ENDIF}GetDocumentosSistArq);
  Registra('PostExportarDocumentoIFrame',{$IFDEF FPC}@{$ENDIF}PostExportarDocumentoIFrame);
  Registra('GetRenegFinancParaImpressao',{$IFDEF FPC}@{$ENDIF}apilib.GetRenegFinancParaImpressao);
  ServerRun;
end.
