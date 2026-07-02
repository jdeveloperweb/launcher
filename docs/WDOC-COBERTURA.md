# Migração do `wdoc` → contexto `documentos` (scci-core) — cobertura das APIs expostas

O `wdoc` publica **~40 métodos** (bloco `Registra(...)` do `wdoc.pas`). Esta matriz mapeia, **na ordem
exposta**, o que foi reimplementado **idiomático em Java** no contexto `scci-core/documentos` e o que
**segue em Pascal** (roteado por flag), com o motivo. Fonte de verdade: `wdoc.pas` + `apilib.pas`.

**Princípio:** só reimplemento fiel o que dá pra ler no fonte. Geração de relatório (Jasper/engine),
merge RTF/HTML, conversão (LibreOffice/ImageMagick), anti-malware e a resolução hierárquica de pasta do
`apilib` **não** são reimplementáveis sem esses engines/units — ficam Pascal (é o ADR-002 na prática).

## Legenda
- ✅ **Java** — reimplementado no scci-core, testado.
- 🟡 **Java-parcial** — precisa de um resolver do `apilib` (árvore de pastas) ou conversão; o core está pronto.
- ⛔ **Pascal** — depende de engine/lib externa (relatório, Jasper, merge, conversão, anti-malware) → fica no launcher (flag).

## Matriz (ordem do `Registra`)

| # | API exposta | Situação | Peça Java / motivo |
|---|---|---|---|
| 1 | `GetDocumento` | ✅ Java | `BaixarDocumento.baixar(id)` → `GET /interno/documentos/{id}` (SISTARQ/controleversao + zlib) |
| 2 | `GetDocumentoVersao` | ✅ Java | `baixarVersao(id,versao)` → `GET /interno/documentos/{id}/versoes/{v}` |
| 3 | `GetDocumentoOperacao` | ✅ Java | resolver `ObtemIDS` portado (`GeraIDPaiDocumentosPretendente` + árvore SISTARQ `LeIDDoPath`) → `GET /interno/documentos/operacao` |
| 4 | `GetDocumentoOperacaoAssinatura` | ✅ Java | mesmo resolver + `download=true` |
| 5 | `GetDocumentoContratoAssinatura` | ✅ Java | id direto + download → `baixar(id, download=true)` |
| 6 | `GetDocumentoSisat` | ✅ Java | resolver `ObtemIDSTarefa` (`GeraIDPaiDocumentosTarefa` + árvore) → `GET /interno/documentos/sisat` |
| 7 | `PostDocumentoOperacao` | ⛔ Pascal | upload: `GravaBinarioVersao` + anti-malware + versionamento (apiscci) |
| 8 | `PostDocumentoOperacaoAssinatura` | ⛔ Pascal | upload + assinatura (anti-malware, img→pdf ImageMagick) |
| 9 | `PostDocumentoContratoAssinatura` | ⛔ Pascal | upload + assinatura |
| 10 | `PostDocumentoSisat` | ⛔ Pascal | upload |
| 11 | `GetRelatorioPdf` | ⛔ Pascal | geração de relatório (engine ANDAMENTO_RELATORIO) |
| 12 | `GetRelatorioCsv` | ⛔ Pascal | geração de relatório |
| 13 | `GetSaidaRelatorio` | ⛔ Pascal | saída de relatório |
| 14 | `GetPasta` | ⛔ Pascal | estrutura de pastas (apilib) |
| 15 | `GetDocumentosOriginacaoPdf` | ⛔ Pascal | merge/geração PDF |
| 16 | `GetDocumentoEmPdf` | 🟡 | id direto pronto; a conversão HTML→PDF (`ConverteHtmlEmPdf`) é externa |
| 17 | `PutTelaDocumento` | ⛔ Pascal | tela/metadados (apiscci) |
| 18-19 | `GetGeraJasper` / `PostGeraJasper` | ⛔ Pascal | **Jasper Reports** |
| 20 | `GetTempFilePdf` | ⛔ Pascal | PDF temporário (geração) |
| 21 | `GetDocumentoTemporario` | ⛔ Pascal | documento temporário (geração) |
| 22 | `GetVTDOC` | ⛔ Pascal | apilib |
| 23 | `GetTelaPorTipoDocumento` | ⛔ Pascal | tela por tipo (apiscci) |
| 24-25 | `TrocaId` / `TrocaIdVersao` | ⛔ Pascal | apilib (troca de id/versão) |
| 26-27 | `GetDocumentoComMergeRtf` / `...HTML` | ⛔ Pascal | **merge de template** RTF/HTML |
| 28-29 | `PutPasta` / `PutNome` | ⛔ Pascal | metadados (apiscci) |
| 30 | `DeleteDocumento` | ✅ Java | `ExcluirDocumento.excluir(id)` → `DELETE /interno/documentos/{id}` (delete controleversao+sistarq) |
| 31 | `PostDocumento` | ⛔ Pascal | upload (apiscci) |
| 32 | `GetDocumentoExport` | ⛔ Pascal | export (apiscci) |
| 33 | `GetEstruturaAtualizada` | ⛔ Pascal | estrutura (apiscci) |
| 34 | `GetGeraTelaImpressao` | ⛔ Pascal | tela de impressão |
| 35 | `GetDocumentoComMergeRtfGen` | ⛔ Pascal | merge gen (apilib) |
| 36-37 | `GetImagemGrupoTipoOperacao` / `Post...` | 🟡/⛔ | GET (imagem blob) portável 🟡; POST (upload) ⛔ |
| 38 | `PutDocumentoOperacaoARISP` | ⛔ Pascal | upload ARISP (img→pdf) |
| 39-40 | `GetImagemSeguradora` / `Post...` | 🟡/⛔ | GET (imagem blob) portável 🟡; POST ⛔ |

## Resumo

- ✅ **Reimplementado em Java (testado):** toda a família de **LEITURA + EXCLUSÃO** —
  `GetDocumento`, `GetDocumentoVersao`, `GetDocumentoContratoAssinatura`, **`GetDocumentoOperacao`,
  `GetDocumentoOperacaoAssinatura`, `GetDocumentoSisat`** (com o resolver de árvore do SISTARQ portado do
  `wsistarqlib`: `GeraIDPaiDocumentos*` + `LeIDDoPath`/`LeIDdoDiretorio`/`LeIDdoItem`) e `DeleteDocumento`.
  É o caminho de download/visualização/exclusão — o de maior volume e o que mais ganha com escala.
- 🟡 **Uploads (Post\*) — write-storage em Java:** portado o núcleo de gravação **e a criação de documento
  novo**: `PostDocumento`→`InsereArquivoVersao`→(acha o nó `NOME`+`IDPAI` ou cria via `InsereItemNaBase`,
  TIPO=2, herdando flags da pasta-pai + generator `id_SistArq`)→`GravaBinarioVersao`/`InsereVersaoBinario`
  (`VerificaCriterios` + INSERT nova versão/UPDATE última em `CONTROLEVERSAO`, DB-blob + zlib). Peças:
  `ArmazenadorDocumentoJdbc` (`gravarVersao` por id, `inserirArquivoVersao` por pasta) + `EnviarDocumentoService`.
  REST: `POST /interno/documentos` (por pasta) e `POST /interno/documentos/{id}/versoes` (por id).
  O **anti-malware** e a **conversão imagem→PDF** são **ports/hooks** (`AntiMalware`, `ConversorImagemPdf`)
  — hoje **no-op** (placeholder honesto) até plugar o scanner/ImageMagick real (units não estão no repo).
  Pendências p/ live: (a) impls reais dos hooks; (b) rotear o upload do `/sccidoc` → scci-core (o roteador
  hoje cobre só o download). Testes: `EnviarDocumentoServiceTest` (por id + por pasta + anti-malware).
- ✅ **Relatórios Jasper — reimplementados em Java (JasperReports):** `GeraJasper` roda **nativo em Java**
  (`GeradorRelatorioJasper`: compila `.jrxml` + `JsonDataSource` → PDF), com use case `GerarRelatorioPdf`
  + REST `POST /interno/relatorios/{nome}/pdf`. Subreports precisam estar compilados no `SUBREPORT_DIR`.
  Teste: `GeradorRelatorioJasperTest` (gera PDF real). **Muda a ADR-002 para relatórios Jasper** — Jasper
  já era Jasper, agora roda dentro do Java.
- ✅ **Conversão imagem→PDF — lib Java pura (openpdf):** `ConversorImagemPdfOpenPdf` (@Primary) substitui o
  hook no-op, sem ImageMagick (mantém o scci-core thin). Plugado no upload.
- ⛔ **Ainda em Pascal (por flag):** merges de template RTF/HTML, geração de relatório NÃO-Jasper (o engine
  que produz o arquivo), e ops de metadados do apiscci ainda não portadas (`PutPasta`/`PutNome`/
  `GetEstruturaAtualizada` — tratáveis, próximo passo). Anti-malware segue hook (scanner externo).

## Storage
- Coberto: **BLOB em banco** (`dado`) + descompressão **zlib**.
- Ponto de extensão: **FileSystem/S3** (`tp_gravacao`) — `RetornaFileSystemName`/`LeArquivoAmazonS3` (units externas). O adapter (`RepositorioDocumentoJdbc`) lança erro claro quando o binário está fora do banco.
- Nota de conexão: os documentos vivem na base de **atividade (PegaDirAtv/SCIS)**; o adapter usa a conexão do ambiente (launcherenv) — se o cliente separar a base, o ajuste é neste adapter.
