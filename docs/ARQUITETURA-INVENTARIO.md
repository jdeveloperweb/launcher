# Launcher SCCI em Java — Arquitetura & Inventário

Documento de referência do **reator hexagonal** (`launcher`): o que é, como está desacoplado,
qual peça cobre qual papel do launcher legado (Pascal), e o inventário **classe por classe**.

> Companheiro operacional: [`README.md`](../README.md) (build, deploy, cobertura). Regras de
> negócio detalhadas: [`docs/REGRAS-NEGOCIO-LAUNCHER-JAVA.md`](REGRAS-NEGOCIO-LAUNCHER-JAVA.md).

---

## 1. Visão geral e a **fronteira** (o que foi reescrito vs. o que é executado)

O SCCI roda um **launcher** (daemon Pascal) que faz a ponte entre o front web e os **programas "w"**
(binários `wtela`, `wmenu`, `wdoc`, …). O launcher **não é** a regra de negócio — ele **transporta**:
recebe a requisição HTTP, decifra, valida a sessão, monta o ambiente, **executa o programa real** e
fala o **protocolo de blocos do oserver** com ele.

O reator Java reproduz **exatamente esse papel de transporte/orquestração**, do jeito hexagonal, e
**não reimplementa a lógica dos programas**:

| Camada | Quem faz | No reator |
|---|---|---|
| **Transporte / orquestração** (o papel do *launcher*) | `launcher.pas`, `wcorp.pas`, `sccidoc.pas`, `oserver.pas` | **REESCRITO** em Java (este reator) |
| **Login / senha / sessão** (regra simples, mapeável) | `loginbd.pas` | **REESCRITO** em Java (nativo, contra a mesma base) |
| **Regra dos programas** (crédito, produção, documentos…) | `wtela`, `wmenu`, `wdoc` (via `apilib`/`apiscci`/`execlib`) | **NÃO reescrito** — o reator **EXECUTA o binário real** |

Ou seja: a fronteira é o **oserver**. Abaixo dela, os programas "w" continuam sendo os donos da
regra; o reator só monta o ambiente e conversa o protocolo. Isso mantém o risco baixo (zero
reimplementação de regra de programa) e o contrato byte-a-byte com o front.

---

## 2. Camadas hexagonais (Ports & Adapters) e a regra da dependência

```
                    ┌───────────────────── adapters-in (driving) ─────────────────────┐
   Front / Kong ───▶│  AutenticacaoController · DespachoController · SccidocController │
                    │  + filtros (RequestId, SlashNormalization)                       │
                    └───────────────┬──────────────────────────────────────────────────┘
                                    ▼ (ports IN)
                    ┌───────────── application (casos de uso, POJO) ──────────────┐
                    │  LoginService · SessaoService · TrocarSenhaService ·         │
                    │  RecuperarSenhaService · ValidacaoAcessoService ·            │
                    │  DespachoService · DocumentoService · EnvioDocumentoService  │
                    └───────────────┬──────────────────────────────────────────────┘
                                    ▼ (ports OUT)
                    ┌────────────────────── domain (puro) ────────────────────────┐
                    │  models (records) · ports in/out (interfaces) ·              │
                    │  WcopCrypto · PasswordPolicy                                 │
                    └───────────────▲──────────────────────────────────────────────┘
                                    │ (implementam os ports OUT)
                    ┌──────────── adapters-out (driven) ──────────────────────────┐
                    │  ProgramExecutor + NativeOserverBridge (oserver/JNA) ·       │
                    │  Scc* (JDBC) · Redis* · SmtpEnvioEmail ·                     │
                    │  LauncherEnvReader/JdbcConnectionFactory (launcherenv.ini)   │
                    └──────────────────────────────────────────────────────────────┘

   bootstrap (composition root): LauncherApplication + WiringConfig ligam tudo.
```

**Regra da dependência** — sempre aponta **para dentro**:
- `domain` não conhece ninguém (nem Spring). É o núcleo: modelos, ports (interfaces) e as duas peças
  puras de regra técnica (`WcopCrypto`, `PasswordPolicy`).
- `application` depende só de `domain` (recebe os ports OUT por construtor; expõe os ports IN). São
  **POJOs puros**, sem anotação Spring.
- `adapters-in` (REST) traduz HTTP → ports IN. `adapters-out` implementa os ports OUT (JDBC, Redis,
  oserver, SMTP). Ambos dependem de `application`+`domain`, nunca o contrário.
- `bootstrap` é o único que conhece todos: `@Bean`s dos casos de uso (POJO) + component-scan dos
  adapters (`@Component`).

Isso é o que torna o núcleo **testável e imutável a framework**: dá pra trocar JDBC↔Redis↔oserver
sem tocar na regra.

---

## 3. Mapa **legado → reator** (qual peça cobre qual papel)

### `launcher.pas` — o daemon (executor + ambiente + sessão)
| Papel no legado | Peça no reator |
|---|---|
| `fpfork`/`fpexecve` do programa "w" | `NativeOserverBridge` (socketpair + `posix_spawn` no fd 6, via JNA) |
| `SetAmbiente` (monta env do `launcherenv.ini [ENVIRONMENT]` + `USER`) | `LauncherEnvReader.ambienteEnv` |
| `DBINIT` (abre conexão do ambiente) | `JdbcConnectionFactory` + `SccDbConfig` |
| **VALIDA** (`VerificaSessionKeyExpirada`, `SCCI_SESSION`) | `SessaoService` + `SccSessionRepository` (+ cache `RedisRepositorioSessao`) |
| Limite de execuções concorrentes (`MAXCONN`) | semáforo no `ProgramExecutor` |

### `wcorp.pas` — a chamada remota (`DoRemoteCall`)
| Papel no legado | Peça no reator |
|---|---|
| Params como XML raiz `<PMEMORY>` (`Params.saveToStream`) | `ProgramExecutor.jsonParaPmemoryXml` |
| Prefixo de verbo (`Get`/`Post`/… só se `requestMethod` é verbo HTTP) | `ProgramExecutor.montaMetodo` |
| Relay do 1º bloco de resposta; wrap de exceção em JSON | `ProgramExecutor.parseBlocos` |
| `codifica` (XOR na resposta) | `WcopCrypto.cifraResposta` |

### `oserver.pas` — o protocolo de blocos
| Papel no legado | Peça no reator |
|---|---|
| Bloco = `magic(1) + len(4, big-endian) + dados` [zlib se `_Z`] | `ProgramExecutor.bloco`/`parseBlocos`/`inflar` |
| `InitFD` (um fd bidirecional = socketpair) | `NativeOserverBridge` |

### `sccidoc.pas` — o CGI de documentos
| Papel no legado | Peça no reator |
|---|---|
| `DoRawRemoteCall` (resposta `[len][XML metadados][binário]`, mime por extensão) | `DocumentoService` + `SccidocController` |
| `DoMultiPartRemoteCall` (upload: 1 chamada/arquivo, `[len][XML]+bytes`) | `EnvioDocumentoService` + `SccidocController` |
| `DecodeProgramNameAndMethod(Path_Info)` (programa/método no path, GET de navegador) | handler `@GetMapping("/sccidoc/{programa}/{metodo}")` |
| `RequestMethod := GetEnv('REQUEST_METHOD')` (default do verbo) | default `req.getMethod()` nos handlers |

### `loginbd.pas` — login / senha / recuperação / validações
| Papel no legado | Peça no reator |
|---|---|
| `TestaUsuario` (login, md5crypt, códigos T/C/E/M/B/F) | `LoginService` + `SccCredenciaisRepository` + `VerificadorSenhaBcryptMd5` |
| `PASSWD`/`ExecutaPasswdBD` (troca de senha, rodízio `NO_SENHA1..5`) | `TrocarSenhaService` + `SccSenhaRepository` + `PasswordPolicy` |
| `ExecutaEmailPwd` (esqueci a senha → e-mail) | `RecuperarSenhaService` + `SccRecuperacaoSenhaRepository` + `SmtpEnvioEmail` |
| `ValidaCpf`/`ValidaProtocolo` | `ValidacaoAcessoService` + `SccValidacaoAcessoRepository` |
| Cripto do request (AES-128-CBC) + `TrataSenhaEncriptografada` (`[..]`→`WebDeCrypt`) | `WcopCrypto` |

### **NÃO reescrito** (executado como binário real)
`wtela`, `wmenu`, `wdoc` e toda a regra em `apilib`/`apiscci`/`execlib`/`scciio`. O reator os
**executa** via `ProgramExecutor`/`NativeOserverBridge` — inclusive a **autorização por operação**
(`UsuarioTemPerm`/`getenv('USER')`), que o programa enforça sozinho com o `USER` que o reator injeta.

---

## 4. Inventário classe por classe

Legenda de módulo: **D**=domain · **A**=application · **In**=adapters-in · **Out**=adapters-out · **B**=bootstrap.

### 4.1 `domain` — modelos, ports e regra técnica pura (40 classes)

**autenticacao.model** (records)
| Classe | Papel | Legado |
|---|---|---|
| `CredenciaisUsuario` | Dados do usuário p/ login: hash, validade, datas de troca, min/max dias, flag de troca obrigatória | `loginbd.pas` (TestaUsuario) |
| `DadosRecuperacao` | Usuário + SMTP da entidade p/ recuperação (CPF, e-mail, credenciais SMTP) | `loginbd.pas` (ExecutaEmailPwd) |
| `HistoricoSenhas` | Senha atual + 5 anteriores em md5crypt (`NO_SENHA1..5`) | `loginbd.pas` (PASSWD) |
| `ResultadoLogin` | Resultado do login: código T/C/E/M/B/F/K/X, sessionKey, mensagem, dias restantes | `loginbd.pas` |
| `ResultadoTroca` | Resultado da troca de senha (sucesso + mensagem) | `loginbd.pas` |
| `Sessao` | Sessão isolada emitida no login: usuário + ambiente operacional | — |

**autenticacao.policy**
| Classe | Papel | Legado |
|---|---|---|
| `PasswordPolicy` (class pura) | Política de complexidade: mín. caracteres, composição, repetições e sequências | `loginbd.pas` (ValidaSenha) |

**autenticacao.port.in** (interfaces — casos de uso)
| Port | Papel | Legado |
|---|---|---|
| `LoginUseCase` | Login nativo W_COP com estados T/C/E/M/B/F/K/X | `loginbd.pas` |
| `TrocarSenhaUseCase` | Troca de senha (PASSWD) | `loginbd.pas` |
| `RecuperarSenhaUseCase` | "Esqueci a senha": senha temporária + e-mail | `loginbd.pas` (ExecutaEmailPwd) |
| `SessaoUseCase` | Gestão de sessão: registrar/consultar/validar/encerrar/contar (Redis+SCCI_SESSION) | `launcher.pas`, SCCI_SESSION, VALIDA |
| `ValidarAcessoUseCase` | Validações isoladas por CPF/protocolo | `loginbd.pas` |

**autenticacao.port.out** (interfaces — dependências)
| Port | Papel | Legado |
|---|---|---|
| `CredenciaisRepository` | Consulta credenciais na base do ambiente (`[USERS]`), só leitura | `loginbd.pas` |
| `SenhaRepository` | Lê/grava senha p/ troca, rotacionando `NO_SENHA1..5` | `loginbd.pas` (PASSWD) |
| `SessaoPersistente` | Sessão autoritativa na `SCCI_SESSION`; implementa VALIDA | `launcher.pas`, SCCI_SESSION |
| `RepositorioSessao` | Armazenamento de sessões (cache) `sessionKey → Sessao` | — |
| `RecuperacaoSenhaRepository` | Lê dados+SMTP da entidade e grava senha temporária | `loginbd.pas` (ExecutaEmailPwd) |
| `ValidacaoAcessoRepository` | Validações CPF/protocolo (crédito + existência de protocolo) | `loginbd.pas` |
| `VerificadorSenha` | Verifica/gera hash (bcrypt/md5crypt) | `loginbd.pas` |
| `ContadorTentativas` | Contador de tentativas erradas (bloqueio/captcha) | — |
| `EnvioEmail` | Envio de e-mail atrás de interface (SMTP hoje) | — |
| `AutorizacaoPort` | Hook opcional de autorização por operação — **sem uso** (enforce fica no programa via `getenv('USER')`) | `apiscci`/`apilib` (UsuarioTemPerm) |

**compartilhado.crypto**
| Classe | Papel | Legado |
|---|---|---|
| `WcopCrypto` (class pura) | Cripto W_COP: AES-128-CBC no request + XOR na resposta; `WebDeCrypt` de senhas `[..]` do ini | `wcorp.pas`, `loginbd.pas`, `pcrypt.pas` |

**execucao** (model + ports)
| Classe | Tipo | Papel | Legado |
|---|---|---|---|
| `ComandoExecucao` | record | Comando p/ executar programa "w": rawJson, ambiente, programa/método; flags de stream (TStream/TPXML) + upload binário | `sccidoc`, `apilib`, DoMultiPartRemoteCall |
| `ResultadoExecucao` | record | Resultado: flag de erro (bloco EXCEPT) + corpo cru | — |
| `DespachoUseCase` | port in | Despacho `/w`: valida sessão e orquestra a execução | — |
| `ExecutorPrograma` | port out | Executa o binário "w" via protocolo de blocos do oserver | `oserver`, `wmenu`, `wtela` |

**documentos** (model + ports)
| Classe | Tipo | Papel | Legado |
|---|---|---|---|
| `RespostaDocumento` | record | Envelope da resposta `/sccidoc`: metadados + binário OU texto/JSON, flags erro/arquivo | `sccidoc` |
| `Documento` | record | Placeholder do BC (id, tipo, descrição) — sem regra ainda | — |
| `BaixarDocumentoUseCase` | port in | Download: despacha ao programa e devolve binário+metadados/texto | `wdoc`, `sccidoc` |
| `EnviarDocumentoUseCase` | port in | Upload multipart (putDoc): 1 chamada/arquivo com XML PMEMORY+bytes | `sccidoc`, DoMultiPartRemoteCall |
| `ConsultarDocumentosUseCase` | port in | Scaffold p/ listar documentos (sem regra) | — |
| `RepositorioDocumentos` | port out | Scaffold: abstrai fonte p/ listar documentos | — |

**identidade / licencas / roteamento** (scaffolds / não-produtivos)
| Classe | Tipo | Papel | Legado |
|---|---|---|---|
| `AmbienteOperacional` | record | Visão de domínio do ambiente (path, driver, host, database) | — |
| `Usuario` | record | Identidade mínima (login + ambiente) — scaffold | — |
| `MapeamentoAmbiente` | port out | Carrega mapeamento do ambiente (`[USERS]`) | `launcherenv.ini` |
| `Licenca` | record | Placeholder do BC LICENCAS — sem regra | — |
| `ConsultarLicencasUseCase` | port in | Scaffold p/ listar licenças (REST responde 501) | — |
| `RepositorioLicencas` | port out | Scaffold: abstrai fonte p/ licenças | — |
| `FeatureFlag` | record | Feature flag **não-produtivo** do roteador Strangler A/B/C | — |
| `FeatureRegistry` | port out | Port **não-produtivo** do registro de feature flags | — |

### 4.2 `application` — casos de uso (POJO puro, 8 classes)

| Classe | Papel | Legado |
|---|---|---|
| `LoginService` | Autentica usuário nativo (W_COP): bloqueio, captcha, expiração de senha | `loginbd.pas` (TestaUsuario, ExecutaLoginBD) |
| `TrocarSenhaService` | Troca de senha: política de força, histórico e rodízio | `loginbd.pas` (PASSWD, ExecutaPasswdBD) |
| `RecuperarSenhaService` | "Esqueci a senha": valida CPF, gera senha temporária, envia SMTP | `loginbd.pas` (ExecutaEmailPwd) |
| `SessaoService` | Sessão = cache Redis + `SCCI_SESSION` persistente; valida/renova/conta | `launcher.pas` (VALIDA), SCCI_SESSION |
| `ValidacaoAcessoService` | Valida acesso por CPF ou protocolo contra operações do ambiente | `loginbd.pas` (ValidaCpf/ValidaProtocolo) |
| `DespachoService` | Executa o programa "w" do `/w` após validar sessão | `launcher.pas` |
| `DocumentoService` | Download `/sccidoc`: interpreta `[len][XML metadados][binário]` | `sccidoc.pas` (DoRawRemoteCall) |
| `EnvioDocumentoService` | Upload (putDoc): itera arquivos, coleta respostas JSON | `sccidoc.pas` (DoMultiPartRemoteCall) |

### 4.3 `adapters-in` — driving (REST + filtros, 7 classes)

| Classe | Papel | Legado |
|---|---|---|
| `AutenticacaoController` | `/w/login`, `/w/password`, `/w/email-pwd`, `/w/valida-acesso`, `/w/logout` (contrato W_COP: AES req / XOR resp) | `loginbd.pas`, `wcorp.pas`, `launcher.pas` |
| `DespachoController` | `/w`: valida sessão **antes** de executar `wmenu`/`wtela`; cifra a resposta | `launcher.pas`, VALIDA |
| `SccidocController` | Canal `/sccidoc`: download (POST body), upload (multipart), view/download (GET path-based) | `sccidoc.pas`, DoRemoteCall, DoMultiPartRemoteCall |
| `DocumentosController` | Scaffold do BC — 501 | — |
| `LicencasController` | Scaffold do BC — 501 | — |
| `RequestIdFilter` | Garante `X-Request-Id` (MDC + resposta), loga acesso (status+duração) | — |
| `SlashNormalizationFilter` | Normaliza `//` no path (atrás do proxy Apache) | — |

### 4.4 `adapters-out` — driven (16 classes)

**oserver / execução**
| Classe | Papel | Legado |
|---|---|---|
| `ProgramExecutor` | Executa `wmenu`/`wtela`/`wdoc` via bridge; monta env, traduz JSON→XML PMEMORY, blocos, retry | `launcher.pas`, `wcorp.pas`, `sccidoc.pas` |
| `NativeOserverBridge` | Ponte JNA: socketpair + `posix_spawn` no fd 6 (protocolo do oserver) | `launcher.pas` (fpfork/fpexecve), `oserver.pas`, InitFD |

**autenticacao (crypto / email / redis / scc)**
| Classe | Papel | Legado |
|---|---|---|
| `VerificadorSenhaBcryptMd5` | Verifica/gera bcrypt (`$2`) e md5crypt (`$1$` legado) | `loginbd.pas` |
| `SmtpEnvioEmail` | Envia e-mail via SMTP (JavaMail) com credenciais da entidade | `loginbd.pas` (ExecutaEmailPwd) |
| `RedisContadorTentativas` | Conta tentativas falhas no Redis com TTL (bloqueio distribuído) | — |
| `RedisRepositorioSessao` | Cache de sessão no Redis (JSON + TTL); SCCI_SESSION é a autoritativa | `launcher.pas`, SCCI_SESSION |
| `SccCredenciaisRepository` | Busca hash/validade/limites na base do ambiente | `loginbd.pas` (TestaUsuario) |
| `SccSenhaRepository` | Lê/grava senha rotacionando `NO_SENHA1..5` | `loginbd.pas` (PASSWD) |
| `SccSessionRepository` | Autoritativo da `SCCI_SESSION`: registra/valida/encerra/conta | `launcher.pas` (VALIDA) |
| `SccRecuperacaoSenhaRepository` | Lê e-mail/SMTP da entidade e grava senha temporária | `loginbd.pas` (ExecutaEmailPwd) |
| `SccValidacaoAcessoRepository` | Valida CPF (operação/crédito) e existência de protocolo (SISAT) | `loginbd.pas` (ValidaCpf/ValidaProtocolo) |

**compartilhado.db / identidade / roteamento**
| Classe | Papel | Legado |
|---|---|---|
| `LauncherEnvReader` | Lê `launcherenv.ini` (`[USERS]`/`[ENVIRONMENT]`), expande `$VAR`, devolve `SccDbConfig`+env | `launcher.pas`, `launcherenv.ini` |
| `JdbcConnectionFactory` | Abre conexão JDBC pelo driver do ini (Firebird/Postgres/Oracle/MSSQL) | `launcher.pas` (DBINIT) |
| `SccDbConfig` (record) | Config JDBC + mapeamento de 13 colunas do usuário | `launcher.pas` |
| `MapeamentoAmbienteScc` | Carrega `AmbienteOperacional` do `launcherenv.ini [USERS]` | `launcherenv.ini` |
| `InMemoryFeatureRegistry` | Registro **não-produtivo** de feature flags (Strangler) | — |

### 4.5 `bootstrap` — composition root (2 classes)

| Classe | Papel |
|---|---|
| `LauncherApplication` | Spring Boot main; porta 8083 (atrás do Kong); component-scan de `com.prognum.launcher` |
| `WiringConfig` | `@Bean` dos casos de uso POJO, injetando os adapters `@Component` e as classes puras (`WcopCrypto`, `PasswordPolicy`) |

**Contagem:** domain 40 · application 8 · adapters-in 7 · adapters-out 16 · bootstrap 2 — **total 73**.

---

## 5. Fluxos ponta a ponta

### 5.1 Login (`POST /w/login`)
`AutenticacaoController` decifra o blob AES (`WcopCrypto`) → `LoginService.login` → `SccCredenciaisRepository`
lê a base do ambiente (`LauncherEnvReader`+`JdbcConnectionFactory`) → `VerificadorSenhaBcryptMd5`
compara md5crypt → em sucesso, `SessaoService.registrar` grava na `SCCI_SESSION` (`SccSessionRepository`)
+ cache (`RedisRepositorioSessao`) → resposta `{success, sessionKey, contexto}` cifrada em XOR.

### 5.2 Despacho `/w` (executar um programa)
`DespachoController` decifra → **VALIDA** a sessão (`SessaoService.validar` → `SccSessionRepository`)
→ `DespachoService` → `ProgramExecutor`: monta env (`LauncherEnvReader`, com `USER=<usuário>`),
resolve o binário, converte params JSON→`<PMEMORY>`, monta os blocos METD/DATA e executa via
`NativeOserverBridge` (socketpair) → lê o 1º bloco de resposta → resposta cifrada. A **autorização
por operação** acontece **dentro do programa** (`UsuarioTemPerm(getenv('USER'))`).

### 5.3 Documentos `/sccidoc`
- **Ler/baixar** (`RDoc`/`RProc`, POST body): `SccidocController` → `DocumentoService.baixar` →
  `ProgramExecutor` (params size-prefixed `[LE32]`) → resposta `[len][XML metadados][binário]` →
  arquivo (mime por extensão) ou JSON.
- **Ver no navegador** (`AbrirUrl`, GET path-based): `GET /sccidoc/{programa}/{metodo}?query` →
  programa/método do path, params da query, auth por cookie → arquivo inline.
- **Enviar** (`Importar`, multipart): `EnvioDocumentoService` → 1 chamada/arquivo, `[LE32][XML+FileName]+bytes`
  → `PostX` → respostas JSON juntadas (com o prefixo `[LE32]` removido, como o `ReadAnsiString` faz).

---

## 6. Infraestrutura e deploy

| Peça | Papel |
|---|---|
| **Apache** | Borda; `ProxyPass /aejs-l/rest → :8082` (remove o prefixo); `LimitRequestBody` 30 MB |
| **Kong** (`kong`, DB-less, 8082) | API gateway: roteia por domínio (`/w/login`, `/w`, `/sccidoc`, …) para o reator (8083); plugins correlation-id + opentelemetry |
| **Reator** (`launcher.jar`, 8083) | Este projeto |
| **Redis** (`redis`) | Cache de sessão (`sess:*`) e contador de tentativas (`att:*`) |
| **OTel Collector** (`otel`) | Métricas + traces (OTLP); pronto p/ AWS (EMF/X-Ray comentados) |
| **Banco (multi-banco)** (por ambiente) | Base real por ambiente via `launcherenv.ini`: **PostgreSQL · Firebird · Oracle · SQL Server** (driver por `DRIVERNAME`). Queries ANSI-padrão/parametrizadas (sem `NOW()`/`SYSDATE`/`TOP`/`LIMIT`/`::`) — portáveis. Só Postgres validado ao vivo; os demais driver+query prontos |

Build: `mvn -q clean package` → `launcher-bootstrap/target/launcher.jar`. Deploy: `deploy/`
(envia o jar + `kong.yml`, sobe via `run.sh 8083`, JDK 21 embutido, sem cron).
