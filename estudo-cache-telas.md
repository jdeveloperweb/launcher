# Estudo — Cache de Telas (wtela / GetTela) no SCCI

> Objetivo: avaliar, de forma concreta e honesta, se e como dá pra cachear a **abertura de telas**
> do SCCI (endpoint `wtela/tela` → Pascal `GetTela`) usando Redis, com foco em ganho de performance
> para telas abertas por muitos usuários. Documento-base para continuar o estudo.
>
> Base de código analisada: `apilib.pas` (GetTela, LeXml), `originacaolib.pas` (processaPermissoes),
> `domlib.pas`. Ambiente medido: tst (gateway Docker :8083 → scci-core nativo :8090 → Pascal).

---

## 1. Medição de referência (números reais, medidos)

Cada request hoje **spawna um processo Pascal novo** (`posix_spawn` + protocolo oserver + conexão ao
banco). Round-trip medido (3x cada, via gateway :8083):

| Operação | Round-trip |
|---|---|
| `wtela/tela` (incluirtaxascontrato) | ~**320–335 ms** |
| `wpretendente/dominios` (um combo) | ~**110–115 ms** |

Leitura:
- **~115 ms é o "piso"** de qualquer chamada: overhead Java (gateway+scci-core) + **spawn do Pascal +
  conexão ao banco** + uma query leve.
- A **tela gasta ~210 ms A MAIS** que o piso: montar o layout (ler+parsear XML) + processar os `leDados`
  (queries do dado) + serializar um payload maior.

**Consequência central:** qualquer estratégia de cache só dá ganho **expressivo** quando consegue
**pular o spawn inteiro** (servir do Redis, ~2–5 ms). Se o spawn continuar acontecendo, o teto de
ganho é pequeno (`≤ 210 ms`, e na prática bem menos).

---

## 2. Anatomia do `GetTela` (o que é estático vs dinâmico)

`apilib.pas:102371` — fluxo real, resumido:

```pascal
procedure GetTela(jsonIn, jsonOut: TpXml);
begin
  NomeTela := ExtractFileName(jsonIn['tela']);

  // (1) GATE DE PERMISSÃO — case NomeTela -> código de permissão
  case NomeTela of
    'frameEntidades': Permissao := 5;  'frameUsuarios': Permissao := 13; ... end;
  if Permissao <> 0 then
    if not UsuarioTemPerm(userName, Permissao) then raise 'Usuário não tem permissão.';

  // (2) LAYOUT — carrega o XML da tela e monta a árvore
  LeXml(filename, Xml);                                  // <-- do BANCO (xmltelas_cliente|xmltelas) ou arquivo
  processaIncluir(xml.DocumentElement, -1);              // <-- composição de <incluir> (estático)
  processaPermissoes(userName, xml.DocumentElement);     // <-- MASCARA por usuário/permissão (por-usuário!)
  jsonOut.add('tela').AssignAttributesAndChildren(Xml.DocumentElement);   // <-- LAYOUT -> jsonOut['tela']

  // (3) DADOS — percorre as funções 'ledados'/'processatela' e executa cada uma
  funcoes := jsonOut['tela']['funcoes'];
  for i := 0 to funcoes.count-1 do
    if (funcoes[i].NodeName = 'ledados') or (funcoes[i].NodeName = 'processatela') then begin
      unixmtd := funcoes[i].attributes['unixmtd'];       // ex.: "GetDadosContrato?CO_CONTRATO=..."
      Executa(unixmtd, jsonIn/JsonAux, jsonOut);          // <-- IN-PROCESS -> preenche jsonOut['dados']
    end;
  // (4) success := true
end;
```

Resposta resultante (confirmada em runtime):

```json
{
  "tela":  { "funcoes": [...], "frame": {...}, "dirOrigem": "xmltelas/incluirtaxascontrato" },
  "dados": { "CO_CONTRATO": "...", "NOME": "...", "CPF": "...", "VATAXA": "..." },
  "success": true
}
```

### Fonte do layout (`LeXml`, apilib.pas:102247)

Ordem de resolução da tela `nome`:
1. Banco `xmltelas_cliente` (`LeArqsXml`) — versão customizada do cliente **(precedência)**.
2. Banco `xmltelas` — versão padrão.
3. Arquivo `PegaDirArqs/xmltelas_cliente/nome`.
4. Arquivo `PegaDirArqs/xmltelas/nome`.

→ O layout é **conteúdo versionável do cliente** (raramente muda; muda quando o Configurador publica
uma tela nova).

### Classificação estático × dinâmico

| Parte | Origem | Varia por | Cacheável? |
|---|---|---|---|
| `LeXml` (XML cru) + `processaIncluir` | banco/arquivo `xmltelas*` | **tela + versão** | ✅ estático |
| `processaPermissoes` | permissões do usuário | **conjunto de permissões (≈ perfil)** | ⚠️ por-permissão |
| `leDados` → `dados` | queries (contrato/params) | **request** | ❌ dinâmico |

---

## 3. O NÓ do problema

Tudo isso — layout **e** dados — roda **num único spawn Pascal**. O `Executa(unixmtd, ...)` dos
`leDados` é **in-process** (chama outro método dentro do mesmo `w`), não um spawn novo.

Logo:
- Cachear **só o layout** não elimina o spawn (o `dados` ainda precisa dele) **nem** as queries dos
  `leDados` (o dominante).
- O ganho **expressivo** só aparece quando a resposta **inteira** pode sair do Redis — o que exige que
  a tela **não tenha `dados` dinâmico** (ou que ele seja tolerável a um TTL curto).

---

## 4. Estratégias concretas (com trade-offs honestos)

### Caso A — Telas SEM `dados` dinâmico → cachear a resposta inteira ✅ (ganho grande)

Telas cujo `funcoes` não tem `ledados` dinâmico (ou o `dados` é referência estática): config, listas
fixas, telas de parâmetro, muitos `frames` de layout puro.

```
chave = tela:<ambiente>:<nomeTela>:<versao>:<permHash>
hit  → devolve do Redis  (~2–5 ms; PULA o spawn inteiro)
miss → executa GetTela, grava a resposta, devolve
```
- `permHash` = hash do conjunto de permissões do usuário (por causa do `processaPermissoes`). Como
  permissões vêm do **perfil**, na prática são poucos valores distintos → hit rate alto.
- **Onde está o ganho:** 320 ms → ~3 ms. Multiplicado por (telas × usuários). **É aqui que vale.**
- **Passo 0 do estudo (FEITO — ver §8):** varredura de `/u/scci/xmltelas` → **103 de 1523 telas** são
  Caso A (~7%). Lista completa + análise da trilha "semi-A" (que é bem maior) na §8.

### Caso B — Telas COM `leDados` → opções (ganho parcial)

**B1 — cachear só o layout + modo "só dados" no Pascal.**
Adicionar um flag no `GetTela` que **pula** `add('tela')` + `processaPermissoes` e roda **apenas** o
loop de `leDados`. O reator monta `{ tela: <cache>, dados: <fresh> }`.
```
layout = redis.get("tela:<amb>:<nomeTela>:<versao>:<permHash>")
if layout == null:
    r = GetTela(...)                    // 1ª vez: layout + dados
    redis.set(chave, r.tela, TTL_longo)
    resp = r
else:
    d = GetTela(..., soDados=true)      // pula layout/permissões, roda só os leDados
    resp = { tela: layout, dados: d.dados, success: true }
```
- **Honesto:** o `soDados` **ainda spawna** o Pascal e **ainda** roda o `LeXml` (precisa do XML pra
  saber quais `leDados` chamar) + as queries. Economiza só `processaPermissoes` + a serialização do
  layout grande. Ganho **marginal** (dá pra estimar em ~50–120 ms dependendo do tamanho do layout).
- Vale se, na medição (§6), o custo de `processaPermissoes`+serialização do layout for gordo.

**B2 — cachear a resposta inteira com TTL curto (segundos), chave por params.**
```
chave = tela:<amb>:<nomeTela>:<CO_CONTRATO>:<hash-params>:<permHash>   TTL=5–15s
```
- Zero mudança no Pascal. Ganho **oportunista**: re-aberturas rápidas da mesma tela+contrato (usuário
  voltando; vários usuários no mesmo contrato). Hit rate geralmente baixo, mas de graça.

**C — (arquitetural) mover a montagem do layout pro reator.** *(maior esforço, maior ganho)*
O reator passa a: (a) cachear o **XML cru** da tela (do banco `xmltelas*`) em Redis; (b) aplicar
`processaIncluir` + `processaPermissoes` em Java; (c) chamar o Pascal **só** para os `unixmtd` de
`dados`. Assim o **layout inteiro** sai sem Pascal, e só o `dados` dinâmico spawna. É reimplementar
`LeXml`/`processaIncluir`/`processaPermissoes` em Java — mas ataca a metade estática de vez. **Boa
linha de estudo para a fase 2.**

---

## 5. Chave de cache, versão e invalidação

**Chave:** `tela:<ambiente>:<nomeTela>:<versao>:<permHash>`
- `ambiente`: multi-tenant (ex.: `abc`).
- `nomeTela`: o `jsonIn['tela']`.
- `versao`: **a verificar** — o `xmltelas*` é tabela no banco; ver se há coluna de versão/updated. Se
  não houver, usar **hash do conteúdo do XML** (o próprio `LeArqsXml` já lê o blob) como versão. Assim,
  publicar tela nova muda a chave sozinho (invalidação natural).
- `permHash`: hash do conjunto de permissões efetivas do usuário (ou do perfil).

**Invalidação:** o gancho já existe — `AdminAmbienteController.invalidar` (hoje usado pra invalidar o
cache do `LauncherEnvReader`, chamado pelo Configurador). Estender pro namespace `tela:` quando o
Configurador **publica/edita** uma tela. Se usar hash-de-conteúdo na chave, a invalidação é
automática e o gancho vira só um "flush" opcional.

---

## 6. Plano de medição (decidir A vs B com dado, não com achismo)

Instrumentar o `GetTela` (ou o `ProgramExecutor` do reator, que já tem timers `pascal.spawn` /
`pascal.roundtrip`) pra quebrar o tempo de uma tela em:

1. spawn + conexão (o "piso" ~115 ms — já medido, é fixo);
2. `LeXml` (ler + parsear o XML do banco);
3. `processaIncluir` + `processaPermissoes`;
4. loop `leDados` (as queries);
5. serialização da resposta.

Com esse breakdown decide-se:
- Se (3)+(5-layout) é gordo → **B1** compensa.
- Se (2) é gordo → **C** (cachear o XML cru) compensa.
- Telas onde (4) é ~0 → **Caso A** (cache total).

Sugestão: rodar em ~5 telas representativas (1 "pesada" de contrato, 1 de listagem, 1 frame de
config, 1 simulador, 1 cadastro).

---

## 7. Recomendação e próximos passos

**Ordem de retorno × esforço (para telas):**
1. **Caso A** — cachear a resposta inteira das telas **sem `dados` dinâmico**. Esforço baixo, ganho
   grande e garantido. *(Começar levantando quais telas se qualificam — Passo 0.)*
2. **B2** — TTL curto por params nas telas de contrato. Esforço ~zero, ganho oportunista.
3. **C** — montar layout no reator (cache do XML cru + permissões em Java). Esforço alto, ganho grande
   e amplo. Fase 2.
4. **B1** — só depois de medir; ganho marginal se o layout não for gordo.

**Pontos a verificar (para completar o estudo):**
- [ ] Levantar a lista de telas **Caso A** (sem `ledados` dinâmico) varrendo `xmltelas*`.
- [ ] O `xmltelas*` tem coluna de versão/updated? Senão, definir hash-de-conteúdo como `versao`.
- [ ] `processaPermissoes` remove nós ou só desabilita? (define se o `permHash` precisa ser fino ou
      basta o perfil.) — ver `originacaolib.pas:1237`.
- [ ] Breakdown de tempo (§6) em telas representativas.
- [ ] Definir política de TTL e o gancho de invalidação no Configurador (`AdminAmbienteController`).

**Nota (fora do escopo "telas", mas relacionada):** os `leDados` de uma tela frequentemente chamam
**domínios/combos** (`unixmtd` = MontaDominio...). Cachear os **domínios** (dado de referência, hit
rate altíssimo) acelera as telas **por dentro**, sem depender do cache de layout — é o item de maior
retorno geral e vale citar no estudo como trilha paralela.

**Nota de arquitetura:** o "piso" de ~115 ms é **spawn de processo**. Um **pool de workers Pascal
quentes** (processo `w` já vivo, conexão de banco aberta) cortaria isso de **toda** chamada —
ortogonal ao cache, e possivelmente o maior lever de todos. Vale mencionar como alternativa/complemento.

---

## 8. Levantamento nesta base (contagem + lista real)

Varredura de `/u/scci/xmltelas` (arquivos `.xml`), classificando cada tela por ter ou não
`<ledados>`/`<processatela>`:

| Classe | Qtd | % |
|---|---|---|
| **Caso A** — SEM dado dinâmico (candidata a cache total) | **103** | ~7% |
| **Caso B** — com `ledados`/`processatela` | **1420** | ~93% |
| **Total** | **1523** | |

> **Ressalva metodológica:** o `LeXml` lê primeiro do **banco** (`xmltelas_cliente` → `xmltelas`), com
> fallback em arquivo. Esta contagem é dos **arquivos** de `/u/scci/xmltelas`. No ambiente medido o
> `xmltelas_cliente` tinha só **1** tela customizada, então o proxy é fiel — mas em produção convém
> confirmar contra o banco (uma versão de cliente pode reclassificar poucas telas).

### As 103 telas Caso A (candidatas a cache total)

São, na esmagadora maioria, **layout puro**: diálogos/modais/popups, frames de ajuda, filtros/pesquisas,
seletores de campo, digitação e treeviews. Lista completa:

```
abahistoricos                     frameAjudaProducao                mostraMut
avisoEnvioDocumento               frameAjudaRelatorios              mostraNaoMut
cadastro_da_seguradora            frameAjudaSCCI                    paramDataExecOper
camposatendimento                 frameAjudaSisAt                   parametrosTela
camposDetPagamento                framecadctr                       paramFiltroEspelhoCadmut
camposevolucao                    framecadpretendente_prognum       paramFiltroLogEventos
confirmaDadosEnvioAcesso          frameCalcCorr                     paramFiltroRotinas
consultaEspelhoCadmut             frameCalcHabilit                  paramFiltroTipoEnquadramento
consultaprocessos                 frameCalcValIni                   pesquisaFonemaMunic
ConsultaProtocoloWeb              frameCancHab                      pesquisanaoMutuario
conta_enquadramento               frameCEP                          pesquisaPretNovoCtr
copiarRemessaGenerica             frameConsHab                      pesquisaTaxaNaoMutuario
copiarRetornoGenerico             frameDefinirBusca                 pesquisaTramitacao
dialogConfirmaPercentualSinistro  framedigitacaofuncpub             popUpBuscaUser
dialogoIniciarProposta            framedigitacaopretendente         PopUpConfirmacao
dialogoSelecionaQtde              framedigitacaoregfund             PopUpCtrHabil
dialogoTaxaJuros                  frameEditaStatusPendParcelada     PopUpIncluirUsuarios
dialogoTemLimiteCoberturaSeguro   frameEscolheEmpreen               PretendWeb
documentacaoNecessaria            frameEscolheEmpreendimento        processaEspelhoCadmut
dominioscontratoweb               frameGerarRemessa                 processosReceber
exportarRemessaGenerica           frameImportProd                   simulacao_originacao
exportarRetornoGenerico           frameimpressaoboletointerno       treeviewCessao
filtraEntidades                   frameIncluirCessaoLCI             treeviewdocumentos
filtraUsuarios                    frameIncluirCesta                 treeviewjuridico
frameAjudaDocumentos              framemostrapret                   treeviewprocessos
frameAjudaFCVS                    framePesqMutFcvs
frameAjudaImplantacaoRevisao      framePesqMutFcvsRcvRnv
frameAjudaManutencao              framePesqMutFin
frameAjudaOriginacao              framepretendentemobile
                                  framePropostasRenegociacao
                                  frameSelecionaSM
                                  frameUserComerc
                                  importaDadosComMascaramento
                                  importaDadosComMascaramentoOri
                                  importarRemessaGenerica
                                  importarRetornoGenerico
                                  impressaopretendenteweb
                                  imprimeRelCad
                                  incluiPretendente
                                  incluirAlterarContasDampMutuario
                                  loginPretendente
                                  matriz_campos
                                  mensagemIsentaDespesa
                                  menuAjuda
                                  mobileDadosOperacao
                                  mobileSimuladorPasso1
                                  mobileStatus
                                  modalSelecaoCtrExterno
                                  modalSelecionaImovelPretendente
```
> Muitas dessas são de **uso pontual** (diálogos, ajuda). Pra priorizar, cruzar com o **tráfego real**
> (log `w_dispatch` do gateway por `methodName=tela` + `tela=<nome>`) e cachear primeiro as mais abertas.

### O que as telas Caso B carregam (distribuição dos `ledados`)

Top métodos `unixmtd` chamados pelos `<ledados>` (base toda):

| unixmtd | nº de telas | natureza |
|---|---|---|
| **GetDadosEntrada** | **765** | ❓ coringa — investigar |
| GetDadosTabela | 326 | provável **referência** (cacheável) |
| GetDados | 316 | ❓ genérico |
| GetContrato | 98 | **dinâmico** (por contrato) |
| ProcessaTelaGrupoTipoOperacao | 58 | referência/config |
| GetPretendente | 54 | **dinâmico** (por pretendente) |
| GetContratoGen | 46 | **dinâmico** |
| MontaDominiosFrameSimulacao | 16 | **domínio** (cacheável) |

### O achado mais importante: a trilha "semi-A" é MUITO maior que 7%

O Caso A estrito são 7%. Mas o conjunto **cacheável de verdade** provavelmente é bem maior:
- `GetContrato` + `GetPretendente` + `GetContratoGen` (~**200 telas**) → dinâmico real, **não** cachear.
- `GetDadosTabela` (326), `MontaDominios*` → tendem a **referência** → telas cujo(s) `ledados` só chamam
  esses são **semi-A** (dado cacheável) e entram no cache.
- **`GetDadosEntrada` domina com 765 telas** — é o coringa que decide o tamanho do bolo. **Próximo passo
  de maior alavancagem:** abrir o `GetDadosEntrada` (procurar no `apilib.pas`) e ver se ele retorna
  **dado leve/genérico de abertura** (→ cacheável, e aí centenas de telas viram cache) ou **específico
  por operação** (→ dinâmico). Isso pode transformar "7%" em "maioria".

### Priorização com número
1. **103 Caso A** → cache total já (filtrando por tráfego). Ganho garantido, esforço baixo.
2. **Classificar `GetDadosEntrada` e `GetDadosTabela`** (referência × dinâmico) → potencial de expandir o
   cacheável de ~7% pra maioria das telas. **É aqui que o estudo tem que ir a fundo.**
3. Telas de `GetContrato`/`GetPretendente` (~200) → não cachear; atacar via **pool de workers** (§7).
