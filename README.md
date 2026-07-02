# Launcher SCCI — Reator Hexagonal em Java

Migração do **launcher** do SCCI (daemon Pascal/W_COP) para **Java**, com **arquitetura hexagonal
(Ports & Adapters) organizada por domínio**, **Kong** na borda e **Redis** para sessão. Preserva o
contrato do front (`/aejs-l`) **byte-a-byte** e **executa os programas legados reais** (`wmenu`,
`wtela`, …) via ponte nativa **JNA** — sem reescrevê-los.

O reator é composto por 5 módulos Maven: `launcher-domain`, `launcher-application`,
`launcher-adapters-in`, `launcher-adapters-out`, `launcher-bootstrap`. O artefato executável é
`launcher.jar`.

> 📐 **Arquitetura & inventário completo (classe por classe + mapa legado→reator):**
> [`docs/ARQUITETURA-INVENTARIO.md`](docs/ARQUITETURA-INVENTARIO.md).

> **O legado é o daemon Pascal** (`launcher.pas`, `wcorp.pas`, `sccidoc.pas`, `loginbd.pas`,
> `oserver.pas`) — é o que está sendo migrado. **Este projeto — o reator hexagonal — é a versão
> final.** (Material histórico fica arquivado em [`legacy/`](legacy/).)

---

## 1. Índice

- [2. Visão de arquitetura](#2-visão-de-arquitetura)
- [3. Domínios (bounded contexts) e organização dos arquivos](#3-domínios-bounded-contexts-e-organização-dos-arquivos)
- [4. Cobertura das regras de negócio (aplicado × falta)](#4-cobertura-das-regras-de-negócio-do-launcher)
- [5. Decisões de arquitetura (o porquê)](#5-decisões-de-arquitetura-o-porquê)
  - [5.1 JNA — por que e como](#51-jna--por-que-e-como)
  - [5.2 VALIDA + Redis](#52-valida--redis)
  - [5.3 Kong](#53-kong)
- [6. Padrões de projeto utilizados (e por que estes)](#6-padrões-de-projeto-utilizados-e-por-que-estes)
- [7. Como instalar e testar](#7-como-instalar-e-testar)
- [8. Benefícios da nova arquitetura](#8-benefícios-da-nova-arquitetura)
- [9. Strangler Fig — estou pronto?](#9-strangler-fig--estou-pronto)
- [10. Dependências](#10-dependências)
- [11. Raio-X do projeto](#11-raio-x-do-projeto)

---

## 2. Visão de arquitetura

Fluxo de uma requisição (produção-teste, com o reator + Kong):

```
Browser (SPA ExtJS /aejs-l)
   │  POST /aejs-l/rest/w/login | /w/password | /w   (corpo AES do W_COP)
   ▼
Apache httpd (TLS + vhost + SPA estático)   ── ProxyPass /aejs-l/rest → :8082 ──┐
                                                                                 ▼
                                                            Kong (:8082, DB-less, Docker)
                                                              ├─ /w/login, /w/password, /w/logout,
                                                              │  /w/email-pwd, /w/valida-acesso → "autenticacao"
                                                              └─ /w                             → "execucao"
                                                                                 │
                                                                                 ▼
                                                            Reator hexagonal (:8083, JVM no host)
                                                              ├─ decifra AES (W_COP) / cifra XOR ISO-8859-1
                                                              ├─ autenticacao: login/senha (loginbd) → Postgres do ambiente
                                                              ├─ sessão: Redis (cache) + SCCI_SESSION (VALIDA)
                                                              └─ execucao: socketpair + posix_spawn (JNA) → binário "w" real
                                                                                 │
                                                          ┌──────────────────────┼───────────────────────┐
                                                          ▼                      ▼                       ▼
                                                   Postgres/Firebird       redis (Docker)     /u/scci/binfpc/wmenu…
                                                   (launcherenv.ini)       sessão + tentativas     (protocolo oserver)
```

**Camadas (Ports & Adapters / Hexagonal):**

| Módulo Maven | Papel | Depende de | Spring? |
|---|---|---|---|
| `launcher-domain` | modelos, **ports** (in/out), políticas, `WcopCrypto` (kernel técnico puro) | — | **Não** (Java puro) |
| `launcher-application` | **casos de uso** (POJOs) — orquestram os ports | domain | Não |
| `launcher-adapters-in` | **driving**: controllers REST, filtros | application + domain | Sim (web) |
| `launcher-adapters-out` | **driven**: JDBC, JNA/oserver, Redis, crypto edge | application + domain | Sim |
| `launcher-bootstrap` | **composition root**: `main`, wiring (`@Bean`), `application.yml` | adapters-in + out | Sim |

A **regra de dependência aponta para dentro**: nada em `domain` conhece framework; `application`
só depende de **ports** do domain; os adapters implementam os ports; o `bootstrap` injeta as
implementações. Isso é imposto pelo `<dependencies>` de cada `pom.xml` (evidência verificável).

---

## 3. Domínios (bounded contexts) e organização dos arquivos

O **domínio é o 1º segmento de pacote** dentro de cada módulo: `com.prognum.launcher.<domínio>.<hexagonal>`.

```
com.prognum.launcher
├── autenticacao        Login, troca/recuperação de senha, sessão, logout, política, VALIDA, validação de acesso
│   ├── model           CredenciaisUsuario, ResultadoLogin, ResultadoTroca, HistoricoSenhas, Sessao, DadosRecuperacao
│   ├── policy          PasswordPolicy (regras de complexidade — Java puro)
│   ├── port/in         LoginUseCase, TrocarSenhaUseCase, RecuperarSenhaUseCase, SessaoUseCase, ValidarAcessoUseCase
│   └── port/out        CredenciaisRepository, SenhaRepository, RecuperacaoSenhaRepository, VerificadorSenha,
│                       ContadorTentativas, RepositorioSessao, SessaoPersistente, ValidacaoAcessoRepository,
│                       EnvioEmail, AutorizacaoPort
├── execucao            Papel "launcher": executa binários "w" (oserver) e despacho /w
│   ├── model           ComandoExecucao, ResultadoExecucao
│   ├── port/in         DespachoUseCase
│   └── port/out        ExecutorPrograma
├── identidade          Usuário/ambiente operacional, mapeamento launcherenv [USERS] (multi-banco)
├── licencas            (NOVO — scaffold) modelo + ports + controller 501
├── documentos          Canal de arquivos `sccidoc` (download/raw migrado; upload multipart pendente)
│   ├── model           RespostaDocumento (arquivo: tipo/nome/download/bytes | texto/erro)
│   ├── port/in         BaixarDocumentoUseCase
│   └── (application)   DocumentoService · (adapters-in) SccidocController (/sccidoc)
├── roteamento          (NÃO-PRODUTIVO) feature flags do roteador A/B/C (Strangler)
└── compartilhado       Infra transversal: WcopCrypto (domain), LauncherEnvReader,
                        JdbcConnectionFactory, SccDbConfig, filtros web (request-id, slash)
```

**Onde cada classe vive (evidência da separação por camada):**

| Classe | Módulo | Pacote | Papel |
|---|---|---|---|
| `LoginService`, `TrocarSenhaService`, `SessaoService` | application | `autenticacao` | casos de uso (POJO) |
| `AutenticacaoController` (`/w/login`, `/w/password`) | adapters-in | `autenticacao.rest` | driving adapter |
| `DespachoController` (`/w`) | adapters-in | `execucao.rest` | driving adapter |
| `SccidocController` (`/sccidoc`) | adapters-in | `documentos.rest` | driving adapter (arquivos) |
| `DocumentoService` | application | `documentos` | caso de uso (POJO) — reusa `ExecutorPrograma` |
| `SccCredenciaisRepository`, `SccSenhaRepository`, `SccSessionRepository` | adapters-out | `autenticacao.scc` | driven (JDBC) |
| `RedisRepositorioSessao`, `RedisContadorTentativas` | adapters-out | `autenticacao.redis` | driven (Redis) |
| `VerificadorSenhaBcryptMd5` | adapters-out | `autenticacao.crypto` | driven (hash) |
| `ProgramExecutor`, `NativeOserverBridge` | adapters-out | `execucao.oserver` | driven (JNA) |
| `WcopCrypto` | **domain** | `compartilhado.crypto` | kernel técnico puro (injetado nos dois lados) |

> Por que `WcopCrypto` está no `domain` e não num adapter? Porque é **Java puro** (só JDK) e precisa
> ser visto pelos **dois** adapters (in cifra/decifra; out trata `DB_PASS`). Como adapters-in e
> adapters-out **não podem depender um do outro**, ele desce ao domain (kernel compartilhado) e o
> bootstrap o expõe como `@Bean`.

---

## 4. Cobertura das regras de negócio do launcher

Legenda: ✅ aplicado (fiel ao Pascal) · 🟡 parcial/scaffold · ⛔ ainda não.

| Regra de negócio (origem Pascal) | Status | Onde / observação |
|---|---|---|
| **Login** md5crypt + estados `T/C/E/M/B/F` (`loginbd.pas` TestaUsuario) | ✅ | `LoginService` |
| **Hardening** bloqueio/captcha/atraso (`K/X`, contador) | ✅ | `LoginService` + `RedisContadorTentativas` |
| **Troca de senha**: verifica atual → política → rodízio `NO_SENHA1..5` → grava md5crypt | ✅ | `TrocarSenhaService` + `SccSenhaRepository` |
| **Política de senha** (`ValidaSenha`, CARACESP) | ✅ | `PasswordPolicy` |
| **Cripto W_COP** AES-128-CBC (request) + XOR ISO-8859-1 (resposta) | ✅ | `WcopCrypto` |
| **Multi-banco** por ambiente (`launcherenv.ini [USERS]`: PG/Firebird/Oracle/MSSQL) | ✅ | `LauncherEnvReader` + `JdbcConnectionFactory` |
| **`DB_PASS`** `TrataSenhaEncriptografada` (`[..]`→WebDeCrypt) | ✅ | `WcopCrypto` |
| **Executar programas "w"** via protocolo oserver (blocos, zlib) | ✅ | `ProgramExecutor` |
| **fd bidirecional do `InitFD`** (socketpair) | ✅ | `NativeOserverBridge` (JNA) |
| **Despacho `/w`** (verbo+método → `GetMenu`) | ✅ | `DespachoController` |
| **Params como XML `<PMEMORY>`** (o launcher serializa os params em XML, não JSON — `wcorp.DoRemoteCall`) | ✅ | `ProgramExecutor.jsonParaPmemoryXml` — ver §5.4 |
| **Relay do 1º bloco de resposta** (`oserver_recebe` lê um bloco; DATA vence EXCEPT pós-resposta) | ✅ | `ProgramExecutor.parseBlocos` — ver §5.4 |
| **Embrulho da exceção do programa em JSON** (`{"success":false,"message":...}`, não texto cru) | ✅ | `ProgramExecutor.parseBlocos` (bloco EXCEPT) — ver §5.4 |
| **VALIDA** — revalidar token antes de executar (`VerificaSessionKeyExpirada`/`SCCI_SESSION`) | ✅ | `SessaoService` + `SccSessionRepository` |
| **Sessão persistente/distribuída** (`SCCI_SESSION` + cache) | ✅ | `SccSessionRepository` + Redis |
| **Contrato de resposta** (`success` boolean na falha + `message` + `codigo` E003/E004) | ✅ | controllers |
| **Logout** — encerrar sessão (`/w/logout`) | ✅ | `SessaoService.encerrar` (SCCI_SESSION + Redis) |
| **Máx. logins simultâneos** (`QtMaxLogin`) | ✅ | `AutenticacaoController` + `SccSessionRepository.contarAtivas` (config `max-logins-simultaneos`) |
| **Esqueci a senha** (`ExecutaEmailPwd`): valida CPF → senha temporária → e-mail | ✅ | `RecuperarSenhaService` + `SccRecuperacaoSenhaRepository` + `EnvioEmail` (`/w/email-pwd`) |
| **Validação de acesso** CPF/protocolo (`ValidaCpf`/`ValidaProtocolo`) | 🟡 | `ValidacaoAcessoService` (`/w/valida-acesso`) — **building block portado e validado** (`{"success":"true","valido":true}`): `cpfComOperacao` (OPERACAO_CREDITO+PESSOA_PRETENDENTE), `protocoloExiste` (OCORRENCIA_SISAT). O **modo login-por-CPF completo** (`ExecutaLoginWebReact` do `loginbd`) fica pendente — o fonte não está neste servidor de desenv; wiring aguarda o fonte/fluxo real |
| **Autorização por operação** (`UsuarioTemPerm`/`TemPermissao`) | ✅ | Enforçada pelos **programas** (fiel: o launcher legado tb não faz gate). `PegaUsuario=getenv('USER')` e o reator injeta `USER=<usuário da sessão>` (`LauncherEnvReader`). **Validado**: `GetSetaPermissoes` → `TEMPERM_*` true p/ supervisor, false p/ usuário inexistente. `AutorizacaoPort` = hook opcional sem uso — ver §5.6 |
| **Cache de usuários/permissões do daemon** (`LoadDBUsers`/`FSectionList`) | ✅ | Não é papel do launcher: a permissão vive no banco e o programa a lê por request (via `USER`); sessão via VALIDA/Redis |
| **Roteador A/B/C + feature flags** (Strangler) | 🟡 | `roteamento` scaffold **não-produtivo** |
| **`licencas`** | ⛔ | scaffold (501) — **regra de negócio a definir** |
| **`documentos` — canal `sccidoc`** (view/download + upload; métodos `TStream`; mime por extensão + Content-Disposition; **prefixo `[LE32 tamanho]` no request**) | ✅ | `SccidocController` + `DocumentoService`/`EnvioDocumentoService`. **3 fluxos**: view/download `AbrirUrl` (GET path-based `/sccidoc/{prog}/{metodo}?query`, auth por cookie), upload `Importar` (multipart POST → `PostX`), leituras `RDoc`/`RProc` (POST body → `GetX`). Validado ponta a ponta (PDF real; upload `PostDocumentoOperacao`; view GET via Kong 200) |
| **Login externo / OAuth / outros bancos** (`loginoauth`, `loginc6`, …) | ⛔ | não portados (só `loginbd`) |

Detalhamento e definições de negócio em aberto: ver
[`docs/REGRAS-NEGOCIO-LAUNCHER-JAVA.md`](docs/REGRAS-NEGOCIO-LAUNCHER-JAVA.md) (seção 9, mapa de lacunas).

---

## 5. Decisões de arquitetura (o porquê)

### 5.1 JNA — por que e como

**Problema.** Os programas "w" do SCCI usam o `InitFD` do **oserver**, que lê e escreve **um único
descritor bidirecional** (um `socketpair`). A JVM **não cria `socketpair`**: o `ProcessBuilder` só
entrega pipes **separados** (stdin de leitura + stdout de escrita), o que não atende o `InitFD`.

**Alternativa descartada.** Alterar o `oserver` para o `InitFD` aceitar dois fds → obrigaria a
**recompilar as libs e todos os binários** de todos os clientes em produção (risco alto, acopla a
migração ao núcleo do runtime). Rejeitada.

**Decisão.** **JNA (Java Native Access)** — o Java chama a libc diretamente e monta o **mesmo fd
bidirecional (fd 6)** que o `InitFD` espera, **sem tocar no oserver** e sem escrever C/JNI:

1. `socketpair(AF_UNIX, SOCK_STREAM)` → par de fds conectados;
2. **`posix_spawn`** do programa com o fd do filho `dup2` para o **fd 6** (não `fork` — a JVM é
   multithread e `fork`+chamadas não async-signal-safe travaria; `posix_spawn` é o primitivo seguro);
3. o programa é chamado como `programa 6 6 <ip>` (igual ao daemon);
4. o pai escreve o request, `shutdown(WR)` e lê a resposta (blocos do oserver).

Detalhe do ambiente: o glibc do servidor é **2.28** (sem `posix_spawn_file_actions_addchdir_np`, que
só existe em 2.29+), então o diretório de trabalho é ajustado com um `chdir` **serializado** na
janela do spawn e restaurado logo após. Código: `NativeOserverBridge` + `ProgramExecutor`.

**Impacto/benefício:** zero alteração no oserver, uma dependência (`net.java.dev.jna`), e ainda
**mais leve** que a alternativa anterior (uma ponte Python) — some um processo interpretador da
cadeia (JVM → posix_spawn → programa).

### 5.2 VALIDA + Redis

**VALIDA** (regra do `launcher.pas`): o token de sessão é **persistido na `SCCI_SESSION`** e
**revalidado antes de executar** cada programa (`VerificaSessionKeyExpirada`). Sem isso, o contexto
de sessão fica inconsistente sob concorrência (pendência histórica). Aplicado:

- **Login** grava a sessão na `SCCI_SESSION` (autoritativo) **e** no **Redis** (cache, TTL);
- **Despacho `/w`** faz **VALIDA**: Redis primeiro; no *miss*, revalida na `SCCI_SESSION`; sessão
  inválida → **rejeita** (`{"success":false,"message":"Sessao expirada..."}`) e **não executa**.

**Redis** (por que): a sessão e o contador de tentativas eram `ConcurrentHashMap` em memória (não
sobreviviam a restart nem escalavam entre instâncias). Movidos para o Redis **atrás dos ports**
(`RepositorioSessao`, `ContadorTentativas`) — troca sem tocar nos casos de uso. É também onde o
contexto do VALIDA (o "`FSectionList`" do daemon) passa a viver de forma compartilhada.

### 5.3 Kong

**API Gateway na borda** (depois do Apache, antes do reator): roteia por **domínio** (um
service/route por bounded context), injeta `correlation-id` (casa com o `requestId` do reator) e
habilita rate-limit/auth/observabilidade **sem tocar no código**. Roda **DB-less** (declarativo,
`kong.yml`) em Docker, escutando na **8082** (a porta que o Apache já proxya) → reator 8083, então
**o Apache não muda**. É também o ponto natural para ligar o **Strangler** (rota A/B/C) no futuro.

### 5.4 Serialização dos params: XML `<PMEMORY>` (o `HUBToken`) e relay de 1 bloco

**Regra descoberta e aplicada (validada).** O launcher **não** passa os params do front para o
programa "w" como JSON — ele passa como **XML** com raiz `<PMEMORY>`. Isso está no `wcorp.pas`
(`DoRemoteCall`):

```pascal
Params.DocumentElement.NodeName := 'PMEMORY';
if wini.HUBToken > '' then Params.saveJsonToStream(Buf)   // JSON — só com HUBToken (integração HUB)
else                        Params.saveToStream(Buf);      // XML nativo <PMEMORY> — modo PADRÃO
pCCPClient.exec(Programa+'.'+Metodo, Buf);
```

- **Por quê importa:** vários programas (ex.: `wtela.ExecutaOper`) tratam o campo `dados` como
  **XML**. Em XML, `"dados":{}` (vazio) vira `<dados></dados>` — nó válido na árvore, o programa
  **não re-parseia** e executa. Em JSON, `"dados":{}` obriga o programa a converter → XML vazio →
  exceção `EXMLParser` (*"só se admite 1 elemento de nível superior"*). Era **o bug da tela que não
  atualizava/executava**: nós mandávamos JSON.
- **`HUBToken`:** só quando o `w.ini` tem `HUBToken` (integração via HUB) o launcher manda **JSON**;
  o `w.ini` do `aejs` **não tem** → modo **XML** (confirmado no servidor). Por isso a POC agora
  serializa os params como `<PMEMORY>` por padrão (`ProgramExecutor.jsonParaPmemoryXml`), ignorando
  a chave-lixo `""` que o front envia e escapando `& < >`.
- **Relay de 1 bloco (bug irmão, também corrigido):** o `oserver_recebe` do launcher lê **um** bloco
  e repassa. Se o programa escreve o `DATA` (resposta) e **depois** estoura uma exceção (bloco
  `EXCEPT` pós-resposta), o launcher relaya **só o `DATA`**. A POC concatenava `DATA`+`EXCEPT` →
  JSON inválido no front. Corrigido em `parseBlocos` (devolve o 1º bloco de resposta: `DATA` vence;
  `EXCEPT` só quando vem sem `DATA` antes).
- **Embrulho da exceção em JSON (bug do "modal não abre", corrigido):** quando o programa devolve
  uma mensagem/erro de negócio (ex.: *"Não há registros para esses parametros."*) num bloco
  `EXCEPT`, o launcher **não** manda o texto cru — o `wcorp.pas` (`on E:Exception`) embrulha em
  `{"success":false,"message":"..."}`. A POC devolvia o texto cru → o `Ext.decode` do front
  quebrava → o modal não abria. Corrigido: `parseBlocos` embrulha o `EXCEPT` em
  `{"success":false,"message":"<msg escapada>"}` (fiel ao `wcorp`).

### 5.5 Canal de documentos `sccidoc` (arquivos)

**Descoberta e aplicada (validada).** Além do `/w` (JSON), o SCCI tem um canal **separado** para
**arquivos**: o CGI `sccidoc` (fonte `sccidoc.pas`), que faz a ponte HTTP↔CCP **especificamente
para ler/gravar documentos** via `wdoc.getDoc`/`putDoc`. Por isso o front chama
`/aejs-l/rest/sccidoc` — e sem a rota isso dava **404** (o front nem abria o modal de documentos).

O `sccidoc` difere do `/w` na **resposta**: o programa devolve **metadados** (`Tipo`=extensão,
`Nome`, `DOW`=baixar?) **+ o binário** do arquivo; o CGI escolhe o **Content-Type pela extensão**
(PDF/XLSX/PNG/DOCX/ZIP…), define **Content-Disposition** (`attachment` p/ baixar, senão inline) e
faz **streaming do binário** (não JSON). Também aceita **upload** (`multipart` → `putDoc`).

Porte (domínio `documentos`, do jeito Java): `SccidocController` (`/sccidoc`) decifra, faz VALIDA e
chama `DocumentoService`, que executa o programa pelo **mesmo oserver** e separa
`[AnsiString(len+XML metadados)] + [bytes do arquivo]` — se tem `<Nome>`, responde **arquivo**
(mime + disposition, streaming via Spring); senão, texto/JSON; erro do programa vira
`{"success":false,"message":...}`. O **upload multipart (`putDoc`)** fica como próximo passo.

**Regra do prefixo de tamanho no REQUEST (descoberta e aplicada — validada).** Os métodos de
arquivo do `apilib` (`GetErroExec`, `GetRelGerados`, `GetRotinaLogs`, `PostEnviaEmailLotes`) têm
assinatura **`TStream`** (não `TPXML`) e leem os parâmetros com **`LoadFromStreamWithSize`** — ou
seja, esperam o bloco `DATA` como **`[tamanho(4, little-endian)] + [XML PMEMORY]`**. Os métodos
`/w` comuns são `TPXML` e leem com `LoadFromStream` (**sem** prefixo). Enviar o XML cru para um
método `TStream` faz o programa ler os 4 primeiros bytes do XML como "tamanho" (lixo gigante) e
tentar ler bytes demais → exceção **`Stream read error`** (era o "Visualizar Arquivos Gerados"
falhando com *"sempre dá que não"*). **Correção:** `ComandoExecucao.streamComTamanho` — o
`SccidocController` marca `true` e o `ProgramExecutor` prefixa o `DATA` com o `[LE32 tamanho]`
(mesmo `SaveToStreamWithSize` que a **resposta** já usava para `[len][xml][binário]`). Validado
com `GetRotinaLogs` retornando um **PDF real** (`MODULO_PRODUCAO_ARQUIVO_DE_LOG.pdf`, 7 KB,
`application/pdf`) e `GetErroExec` passando a devolver a regra de negócio correta
(`"Fase não foi cancelada"`) em vez de `Stream read error`. **Download/raw migrado e validado**
(deixou de dar 404 e de estourar `Stream read error`).

**Upload (`putDoc` / multipart) — migrado.** Porte do `DoMultiPartRemoteCall`: `SccidocController`
aceita `multipart/form-data`, faz VALIDA e, **para cada arquivo**, monta um `ComandoExecucao` com
`corpoBinario` = bytes do arquivo. O `ProgramExecutor` monta o `DATA` como
**`[LE32 tamanho][XML PMEMORY + FileName] + [bytes do arquivo]`** (fiel ao
`writeAnsiString(Params.Code)+writeBuffer(binário)`), executa **uma vez por arquivo** e as respostas
JSON são juntadas (`success` último vence, `message` 1ª não-vazia, `dados` concatenados). Params vêm
do header cifrado `application-data` (como o `HTTP_APPLICATION_DATA`) com fallback para form
fields/query/headers. Validado: upload real monta `PostDocumentoOperacao` no `wdoc` e executa.

**View/download (`AbrirUrl`) — path-based GET.** O SCCI abre documentos por
`AbrirUrl:rest/sccidoc/wdoc/documentoOperacao?NU_DOCUMENTO=…` — um **GET de navegador** com
**programa/método no PATH** (o `DecodeProgramNameAndMethod(Path_Info)` do `sccidoc.pas`), params na
**query string** e auth por **cookie** (`userName`/`sessionKey`/`ambienteOperacional`). Handler
`@GetMapping("/sccidoc/{programa}/{metodo}[/**]")`: extrai prog/método do path, params da query,
sessão dos cookies (fallback query), `requestMethod=GET` → `Get<método>`, e devolve o arquivo
**inline** (ou `attachment` se `DOW`). Rota Kong `r-sccidoc` passou a aceitar **GET** além de POST.
Validado: GET via Kong → 200, `GetDocumentoOperacao` no `wdoc`.

**Nome do método — fiel ao `sccidoc.pas` (descoberto em teste).** O método é montado como no CGI:
capitaliza só a 1ª letra do `methodName` e **prefixa o verbo (Get/Post/…) apenas se `requestMethod`
for um verbo HTTP**; `requestMethod` tem default = **método HTTP** (`GetEnv('REQUEST_METHOD')`, POST
no multipart), sobrescrito por `requestMethod` no corpo/params. Isso corrigiu dois bugs achados em
teste: `GETDocumentoOperacao`/`DocumentoOperacao` (casing/sem-verbo) → agora `GetDocumentoOperacao`
(leitura) e `PostDocumentoOperacao` (upload), ambos existentes no `wdoc`.

### 5.6 Autorização por operação — enforçada pelos programas (fiel)

**Descoberta e validada.** No SCCI a permissão por operação **não é** papel do launcher: o launcher
legado **não** faz gate próprio antes de despachar. Quem enforça são os **programas** —
`UsuarioTemPerm(PegaUsuario, NumPerm)` / `TemPermissao` são chamados **dentro** das rotinas
(`apiscci`/`apilib`), levantando *"Usuário não tem permissão."*. E `PegaUsuario` resolve o usuário
por **`getenv('USER')`** (`scciio.pas`).

O reator já injeta **`USER=<usuário da sessão VALIDA'da>`** no ambiente do programa
([`LauncherEnvReader.ambienteEnv`](launcher-adapters-out/src/main/java/com/prognum/launcher/compartilhado/db/LauncherEnvReader.java)),
então o programa enforça a permissão do **usuário correto** — sem o launcher duplicar a lógica.
**Validado**: `GetSetaPermissoes` devolve `TEMPERM_2881/2/3 = true` para `supervisor` e `false` para
usuário inexistente. O front esconde botões por `permissao="NNNN"` usando essa mesma lista (método
despachado no `/w`). Por isso o `AutorizacaoPort` fica como **hook opcional sem uso** (defense-in-depth
futuro na borda) — implementar um gate no launcher seria **não-fiel** e arriscado (dupla checagem).

---

## 6. Padrões de projeto utilizados (e por que estes)

| Padrão | Onde | Por que este (e não outro) |
|---|---|---|
| **Hexagonal / Ports & Adapters** | todo o reator | isola regra de negócio de framework/IO; permite trocar JDBC↔Redis↔oserver sem tocar no núcleo. Escolhido sobre "camadas MVC" porque a dependência aponta **para dentro** (testável, o domínio não conhece Spring). |
| **Strangler Fig** | coexistência legado↔reator, `roteamento`, Kong | migração incremental sem big-bang: o launcher legado segue vivo e o novo cresce em volta, cortando fatia por fatia. |
| **Adapter** | `Scc*Repository`, `Redis*`, `NativeOserverBridge` | traduz o mundo externo (SQL, RESP, syscalls) para os ports do domínio. |
| **Repository** | `CredenciaisRepository`, `SenhaRepository`, `SessaoPersistente` | abstrai a persistência por trás de uma interface de domínio (o caso de uso não sabe que é Postgres). |
| **Strategy** | `VerificadorSenha` (bcrypt `$2` vs md5crypt `$1$`), `JdbcConnectionFactory` (driver por ambiente) | seleciona algoritmo/driver em runtime sem `if` espalhado. |
| **Facade** | `WcopCrypto` | esconde AES/XOR/mod1/WebDeCrypt atrás de `decifraRequest`/`cifraResposta`. |
| **Cache-Aside** | `SessaoService` (Redis → SCCI_SESSION no miss) | leitura rápida com fonte autoritativa; padrão certo para sessão/VALIDA. |
| **Bridge** | `NativeOserverBridge` | separa "o que o executor quer" (enviar request/ler resposta) de "como o SO faz" (socketpair/posix_spawn). |
| **Composition Root** | `WiringConfig` (bootstrap) | todo o `new`/wiring num único lugar; o resto do código não faz lookup de dependência. |
| **Dependency Injection** | Spring nos adapters/bootstrap; construtor nos POJOs | inversão de controle; POJOs testáveis sem container. |
| **Filter/Interceptor** | `RequestIdFilter`, `SlashNormalizationFilter` | cross-cutting (correlação, normalização de path) fora dos controllers. |

---

## 7. Como instalar e testar

### Pré-requisitos
- **JDK 21**, **Maven 3.9+** (o pacote de deploy **embute** um JRE 21, então o servidor não precisa de Java).
- Servidor Linux x86_64 (glibc 2.28+), Docker (para Kong e Redis), acesso aos binários `w` e ao banco do ambiente.

### Build e testes (local)
```bash
# na raiz do projeto:
mvn test          # 66 testes (domain/application/adapters/bootstrap) — BUILD SUCCESS
```
Suíte cobre cripto W_COP, política/troca/recuperação de senha, login (T/F/E/M), sessão/VALIDA,
validação CPF/protocolo, canal de documentos (download/upload) e o transporte (método/PMEMORY/blocos/
`[LE32]`) + `contextLoads`. Detalhes e rastreabilidade em
[`docs/EVIDENCIAS-TESTES.md`](docs/EVIDENCIAS-TESTES.md).

### Rodar o reator localmente
```bash
java -jar launcher-bootstrap/target/launcher.jar --server.port=8083
# health:
curl http://localhost:8083/actuator/health
```

### Deploy (servidor) — pipeline próprio do reator
```bash
# reator (porta 8083) — empacota o bootstrap + JRE 21 + kong.yml -> tar.gz -> SSH -> instala
deploy/enviar-pacote.bat        # usa deploy/deploy.conf (host, porta 8083)

# infra em Docker (uma vez):
docker run -d --name redis --network host --restart unless-stopped redis:7-alpine \
  redis-server --port 6379 --save ''
docker run -d --name kong  --network host \
  -e KONG_DATABASE=off -e KONG_DECLARATIVE_CONFIG=/kong/kong.yml \
  -e KONG_PROXY_LISTEN=0.0.0.0:8082 -e KONG_ADMIN_LISTEN=127.0.0.1:8001 \
  -v ~/launcher/app/kong/kong.yml:/kong/kong.yml:ro  kong:3.7
```

### Smoke-test (contrato W_COP; JSON puro é aceito em dev)
```bash
bash ~/launcher/app/smoke-test.sh 8083
# ou via Kong:  curl -s -XPOST http://127.0.0.1:8082/w/login -d '{...}'
```

### Ver tráfego no Kong
```bash
ssh -p 23 -L 8001:127.0.0.1:8001 <user>@<host>    # túnel p/ a Admin API
docker logs -f kong                            # access log ao vivo (kong_request_id)
```

### Rollback
O reator vive **isolado no `/aejs-l`**; o **`/aejs` real (daemon Pascal) nunca é tocado** e continua
como fallback. Para desligar só o `/aejs-l`, pare o reator (`fuser -k 8083/tcp`) e o Kong
(`docker stop kong`) — o `/aejs` segue no ar.

---

## 8. Benefícios da nova arquitetura

- **Testabilidade**: o núcleo (domínio/casos de uso) é POJO puro — testes sem Spring, rápidos.
- **Troca de infra sem tocar na regra**: sessão in-memory → **Redis**; JDBC ↔ outro driver;
  Python → **JNA** — tudo atrás de ports.
- **Organização por domínio**: cada bounded context num pacote; onboarding e ownership claros.
- **Observabilidade**: logs JSON + `requestId` correlacionado com o `kong_request_id`.
- **Escala/resiliência**: sessão e contador **distribuídos** (Redis) sobrevivem a restart e a
  múltiplas instâncias; VALIDA persistente na `SCCI_SESSION`.
- **Borda desacoplada** (Kong): rate-limit/auth/roteamento por domínio sem mexer no app.
- **Migração segura**: isolada no `/aejs-l` com o daemon Pascal (`/aejs`) intacto como referência e
  fallback; contrato byte-a-byte idêntico.

### 8.1 Observabilidade (OpenTelemetry / Collector / Kong)

Telemetria ponta a ponta via **OpenTelemetry**, sem acoplar backend no app:

```
Reator (Micrometer OTLP: métricas + traces) ─┐
                                             ├─→ OTel Collector (contrib) ─→ Prometheus (:9464)
Kong (plugin opentelemetry: traces de borda) ┘         │  processor transform/OTTL (DSL runtime)
                                                        └⇢ awsemf → CloudWatch  /  awsxray → X-Ray  (prontos, comentados)
```

- **Métricas** (`micrometer-registry-otlp`) e **traces** (`micrometer-tracing-bridge-otel` + `opentelemetry-exporter-otlp`) saem do reator via OTLP para o Collector; o **Kong** manda os spans da borda pelo plugin `opentelemetry`. O `X-Request-Id`/`correlation-id` casa com o `requestId` dos logs JSON → correlação Apache→Kong→reator.
- **OTTL** (processor `transform` do Collector) é a **DSL de métricas em runtime**: dá pra derivar/renomear/rotular métricas editando o `deploy/observability/otel-collector-config.yaml` e recarregando o Collector — **sem redeploy do reator** (ex.: já deriva `camada=reator` e `dominio=autenticacao|execucao`).
- **AWS (CloudWatch + X-Ray)**: os exporters `awsemf`/`awsxray` estão **prontos e comentados** no config. Habilitar = descomentar + `-e AWS_REGION/AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY` no container `otel` + egress 443. Aí vêm dashboards, **Service Map** e alarmes (SNS). IAM mínimo: `logs:Put*` (CloudWatch EMF) + `xray:PutTraceSegments/PutTelemetryRecords`.
- **Nota de distro:** o **ADOT** curado não traz o processor `transform`(OTTL); o **contrib** traz OTTL **e** os exporters AWS — por isso um único Collector faz tudo.

Ver tráfego: `docker logs -f kong` (access log + `kong_request_id`) e `curl http://127.0.0.1:9464/metrics` (Prometheus do Collector).

---

## 9. Strangler Fig — estou pronto?

**Parcialmente — as fundações estão prontas; falta ligar o roteamento.**

Já existe:
- ✅ **Mesmo contrato do front** já servido pelo reator (byte-a-byte); o daemon Pascal é a referência a ser estrangulada.
- ✅ **Kong na borda** por onde o roteamento A/B/C será decidido (uma rota já pode ir pro novo,
  outra pro legado).
- ✅ **Ports de roteamento** (`FeatureRegistry`/`FeatureFlag`) — scaffold pronto para popular.

Falta para operar o Strangler de verdade:
- ⛔ **Ativar o roteador**: hoje o `roteamento` é **não-produtivo**. É preciso um adapter de
  feature flags (Redis/arquivo/painel) e a decisão por rota/porcentagem no Kong ou no reator.
- ⛔ **Rota "legado" no Kong**: um service apontando para o **daemon Pascal** (o launcher real em
  produção), para cortar fatia por fatia (ex.: `/w/login` no reator, `/w` de certos programas ainda no Pascal).
- ⛔ **Autorização por operação** (`AutorizacaoPort`) e o cache de permissões — necessários antes de
  mover os programas "w" com contexto de sessão completo.
- 🟡 **Métricas por rota** (Prometheus no Kong) para decidir a promoção de cada fatia com dados.

**Sequência recomendada:** (1) autorização + contexto de sessão completo (VALIDA já é a base) →
(2) rota legado no Kong + feature flags → (3) promover programa por programa medindo no Kong.

---

## 10. Dependências

**Runtime (reator):**
- `spring-boot-starter-web`, `-actuator`, `-data-redis`, `-mail` (3.3.4)
- `net.java.dev.jna:jna:5.14.0` — ponte nativa oserver (socketpair/posix_spawn)
- `spring-security-crypto` (bcrypt) + `commons-codec` (md5crypt `$1$`)
- `net.logstash.logback:logstash-logback-encoder:8.0` — logs JSON
- **Observabilidade:** `micrometer-registry-otlp` (métricas) + `micrometer-tracing-bridge-otel` + `opentelemetry-exporter-otlp` (traces)
- Drivers JDBC (por ambiente): `postgresql`, `jaybird` (Firebird), `ojdbc11` (Oracle), `mssql-jdbc`

**Infra:**
- **Redis 7** (`redis`, Docker) — sessão + contador
- **Kong 3.7** (`kong`, Docker, DB-less) — API gateway de borda (+ plugins correlation-id, opentelemetry)
- **OTel Collector** (`otel`, Docker contrib) — OTLP → Prometheus + (pronto) CloudWatch/X-Ray
- **Apache httpd** — TLS/vhost/SPA (inalterado)
- SMTP: usa o servidor da **entidade** (colunas da tabela `entidades`) — nada estático no reator

**Build/test:** JDK 21, Maven, JUnit 5 + Mockito (`spring-boot-starter-test`).

**Servidor:** Linux x86_64, glibc ≥ 2.28, `/tmp` executável (JNA extrai o `libjnidispatch.so`).

---

## 11. Raio-X do projeto

```
launcher/                        ⭐ ESTE É O PROJETO (reator hexagonal)
├── launcher-domain/             Java puro: modelos, ports, políticas, WcopCrypto
├── launcher-application/        casos de uso (POJOs): Login/TrocarSenha/Sessao/Despacho
├── launcher-adapters-in/        REST: AutenticacaoController (/w/login,/w/password), DespachoController (/w)
├── launcher-adapters-out/       JDBC (Scc*), Redis (Redis*), JNA (oserver), crypto
├── launcher-bootstrap/          Spring Boot main + WiringConfig + application.yml (:8083)
├── pom.xml                      reator pai (5 módulos) — impõe a regra de dependência hexagonal
│
├── deploy/                  pipeline de deploy do reator (bootstrap + JRE + Kong)
│   ├── gerar-pacote.bat / enviar-pacote.bat / instalar.sh / deploy.conf
│   ├── payload/                 run.sh, manter.sh, smoke-test.sh
│   └── kong/                    kong.yml (DB-less, por domínio) + docker-compose.yml
│
├── README.md                    este arquivo (operacional + alto nível)
├── docs/                        ARQUITETURA-INVENTARIO.md (arquitetura + inventário classe-a-classe),
│                                REGRAS-NEGOCIO-LAUNCHER-JAVA.md (regras + mapa de lacunas)
└── legacy/                      🗄️  REFERÊNCIA histórica (não faz parte do projeto ativo):
    └── launcher.pas, wcorp.pas, sccidoc.pas, loginbd.pas, oserver.pas…  ← LEGADO Pascal (o que é migrado)
```

**Portas/serviços no servidor:**

| Serviço | Porta | Como roda |
|---|---|---|
| Apache httpd | 443 | vhost `/aejs-l` → ProxyPass `:8082` |
| Kong (borda) | 8082 | Docker `kong` (DB-less) → reator |
| Reator hexagonal | 8083 | JVM no host (`~/launcher/app`, JRE embutido) |
| Kong Admin | 8001 (localhost) | túnel SSH para acessar |
| Redis | 6379 | Docker `redis` (host network) |
| OTel Collector | 4318 | Docker `otel` (métricas + traces) |

**Estado atual (evidências):** `mvn clean verify` verde (5 módulos); login/senha/menu validados
contra o backend real; **VALIDA** rejeita sessão inválida e aceita sessão válida (SCCI_SESSION);
**Redis** guarda sessão + tentativas; **Kong** roteia por domínio (Apache → Kong → reator).
