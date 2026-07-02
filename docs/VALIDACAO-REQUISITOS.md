# Validação de Requisitos — Launcher Java

Cruzamento dos **requisitos** (Documento de Requisitos – Versão Revisada) com o que **já está
implementado e validado** no reator, com **evidência** (classe/endpoint + validação feita) e o que
**falta**. Fonte de verdade: o **código** e as validações executadas na migração (algumas partes do
[`REGRAS-NEGOCIO-LAUNCHER-JAVA.md`](REGRAS-NEGOCIO-LAUNCHER-JAVA.md) estão desatualizadas — ex.:
documentos aparece como *501*, mas está **concluído**).

**Legenda:** ✅ Feito e validado · 🟡 Parcial · ⛔ Falta · ➖ Fora do escopo (por decisão) /
responsabilidade do programa legado.

---

## Resumo executivo

| # | Requisito | Status |
|---|---|---|
| 2.1 | Login usuário/senha (direto no banco) | ✅ |
| 2.1 | Sem MFA/CAPTCHA na 1ª fase | ✅ (CAPTCHA é opcional/desligável; MFA não existe) |
| 2.2 | Sessões simultâneas permitidas | ✅ |
| 2.2 | Timeout configurável (30 min) | ✅ |
| 2.2 | Token/sessionKey | ✅ |
| 2.3 | Perfis/permissões consultados no legado | ✅ |
| 2.4 | Troca de senha | ✅ (feita, mesmo sendo "não prioritária") |
| 2.5 | Recuperação de senha | ✅ (feita, mesmo marcada "fora do escopo") |
| 2.6 | **Upload > 10 GB (chunking/resumível)** | ⛔ **principal débito** |
| 2.7 | Log/Auditoria (JSON, sem dado sensível) | ✅ |
| 2.8 | Licenças/sessões concorrentes sem limite | ✅ |
| 2.9 | **Documentos SCCIDOC/wcorp** (getDoc/putDoc/view) | ✅ (1 diferença menor em 2.9.5) |
| 3.x | Não-funcionais (segurança, observabilidade, arquitetura) | ✅ / 🟡 |
| 3.2/3.5 | Resiliência de deploy (auto-restart) | 🟡 (tirado do escopo) |
| 6 | OSERVER/InitFD | ✅ (resolvido via socketpair/JNA, sem alterar o oserver) |

**Já entregue além do que o documento pedia:** troca de senha (2.4), recuperação de senha (2.5),
**sessão distribuída em Redis**, e **observabilidade** (OpenTelemetry: métricas + traces).

---

## 2. Requisitos Funcionais

### 2.1 Autenticação de Usuário — ✅
- **Login usuário/senha direto no banco** — ✅ `LoginService` (application) → `SccCredenciaisRepository`
  (JDBC) → `VerificadorSenhaBcryptMd5` (md5crypt `$1$`); endpoint `POST /w/login` (`AutenticacaoController`),
  cripto W_COP (AES no request / XOR na resposta, `WcopCrypto`). Conexão por ambiente via `launcherenv.ini`
  (`LauncherEnvReader`/`JdbcConnectionFactory`, multi-banco PG/Firebird/Oracle/MSSQL).
  **Evidência:** login real validado contra o Postgres do ambiente (senha certa → `success`+`sessionKey`;
  errada → falha). Regras: [REGRAS §3](REGRAS-NEGOCIO-LAUNCHER-JAVA.md).
- **Sem MFA/CAPTCHA na 1ª fase** — ✅ **MFA não existe** (fora do escopo, ok). **CAPTCHA** é
  **opcional/parametrizável** (`launcher.auth.captcha-habilitado`, `max-erros-captcha`) — pode ficar
  desligado nesta fase; o login sinaliza o estado, não bloqueia por padrão.
- **Ajuste p/ fases futuras** — ✅ a arquitetura hexagonal permite plugar novos fatores atrás de ports
  sem tocar no núcleo.

### 2.2 Gestão de Sessões — ✅
- **Sessões simultâneas permitidas** — ✅ `launcher.auth.max-logins-simultaneos: 0` (ilimitado). Já existe
  `SessaoService.contarSessoesAtivas` (`SccSessionRepository.contarAtivas`) para o dia em que quiserem
  limitar (regra `QtMaxLogin`), sem mexer no código.
- **Timeout configurável (30 min)** — ✅ `launcher.sessao.ttl-segundos: 1800`; sessão em **Redis (TTL)**
  como cache + **`SCCI_SESSION`** persistente (autoritativa). `SessaoService` + `SccSessionRepository` +
  `RedisRepositorioSessao`. Renovação: **VALIDA** revalida a cada chamada.
- **Token/sessionKey** — ✅ token opaco emitido no login, guardado no cliente, validado em toda chamada
  (`/w` e `/sccidoc`). **Evidência:** VALIDA rejeita sessão inválida (E004) e aceita válida.

### 2.3 Perfis e Permissões — ✅
- **Consulta ao legado / sem lógica própria** — ✅ a autorização é **enforçada pelos programas** (Pascal),
  não pelo launcher. O reator injeta `USER=<usuário da sessão>` no ambiente do programa
  (`LauncherEnvReader.ambienteEnv`); o programa resolve `PegaUsuario = getenv('USER')` e aplica
  `UsuarioTemPerm`. **Evidência:** `GetSetaPermissoes` devolve `TEMPERM_* = true` para `supervisor` e
  `false` para usuário inexistente — prova que a permissão do **usuário certo** é consultada no legado.
  O `AutorizacaoPort` do domínio é um **hook opcional sem uso** (não duplicamos a regra). Ver
  [ARQUITETURA §5.6-equivalente](ARQUITETURA-INVENTARIO.md).

### 2.4 Troca de Senha — ✅ (adiantado)
- Marcada "não prioritária", mas **já implementada e validada**: `TrocarSenhaService` + `PasswordPolicy`
  (política de força) + `SccSenhaRepository` (rodízio `NO_SENHA1..5`, grava md5crypt); endpoint
  `POST /w/password`. Ordem dos gates: **verifica atual → política → rodízio → grava**. Loga só as
  **chaves** dos campos, nunca o valor da senha. Regras: [REGRAS §6](REGRAS-NEGOCIO-LAUNCHER-JAVA.md).

### 2.5 Recuperação de Senha — ✅ (adiantado, além do escopo)
- Marcada "fora do escopo inicial", mas **já implementada**: `RecuperarSenhaService` +
  `SccRecuperacaoSenhaRepository` (lê e-mail/SMTP da entidade, grava senha temporária forçando troca) +
  `SmtpEnvioEmail` (SMTP da **entidade**, nada estático); endpoint `POST /w/email-pwd`. Porte do
  `ExecutaEmailPwd` do `loginbd`. **O débito técnico do documento já está pago** — pode ficar desativado
  na borda (Kong) se quiserem manter fora da 1ª fase.

### 2.6 Upload de Arquivos Grandes (> 10 GB) — ⛔ **PRINCIPAL DÉBITO**
- **Hoje:** upload **multipart/form-data** (`EnvioDocumentoService` + `SccidocController`), fiel ao
  `DoMultiPartRemoteCall` do `sccidoc.pas` — funciona e foi validado (ver 2.9). **Limite atual ~30 MB**
  (o Apache barra em `LimitRequestBody 30 MB`; o reator aceita até `spring.servlet.multipart.max-file-size`,
  hoje 50 MB — parametrizável). O limite de **negócio** é do `wdoc` (lê do `launcherenv.ini`).
- **O que FALTA para o requisito de > 10 GB:**
  - ⛔ **Chunking / upload resumível** (envio em blocos) — hoje é upload único em memória/stream.
  - ⛔ **Armazenamento temporário seguro** dos blocos + reassembly.
  - ⛔ **Monitoramento de progresso** e **tolerância a falhas** (retomar de onde parou).
  - ⛔ **Limpeza/gestão** dos temporários de chunk em caso de falha/parada.
  - 🟡 **Parametrização do tamanho máximo** — existe para o multipart simples, falta para o fluxo de 10 GB.
  > Este é um **novo fluxo** (protocolo de upload resumível: iniciar → enviar blocos → concluir/abortar),
  > não coberto pelo `sccidoc` atual. Requer design próprio (endpoints de chunk, storage temporário,
  > checksum por bloco, TTL de sessão de upload).

### 2.7 Log / Auditoria — ✅
- **Ações críticas registradas** — ✅ logs **JSON estruturados** (`logstash-logback-encoder`,
  `StructuredArguments.kv`): `web_login`, `program_exec`/`program_exec_erro`, `sccidoc`/`sccidoc_upload`/
  `sccidoc_view`, `w_password`, com `requestId` correlacionado ao `X-Request-Id`/`kong_request_id`.
- **Privacidade** — ✅ **não registra dado sensível**: a senha é logada só como **nomes de campo**
  (`w_password` loga `campos`, nunca o valor); documentos logam **metadados** (programa, método, nº de
  arquivos, usuário), **nunca o conteúdo**.
- **JSON para sistema centralizado** — ✅ `logback-spring.xml` (ELK-ready) + OTLP p/ o Collector.

### 2.8 Licenças / Sessões Concorrentes — ✅
- **Sem limitação neste release** — ✅ sessões simultâneas ilimitadas (2.2). Domínio `licencas` é
  **scaffold** (`ConsultarLicencasUseCase` + controller **501**) — sem regra ativa, aderente ao "sem
  limitação". Implementar só quando houver regra de negócio (§9.4 do REGRAS).

### 2.9 Integração e Tratamento de Documentos (SCCIDOC / wcorp) — ✅ (com 1 diferença em 2.9.5)

Toda esta seção foi **implementada e validada** na migração.

- **2.9.1 Conexão sccidoc + wcorp** — ✅ canal `/sccidoc` (`SccidocController`), equivalente ao CGI
  `sccidoc.pas`; execução via `ProgramExecutor` (papel do `wcorp.DoRemoteCall`: params XML `<PMEMORY>`,
  blocos oserver).
- **2.9.2 Fluxo de operação**
  - **Leitura (getDoc/download)** — ✅ `DocumentoService.baixar` interpreta a resposta
    `[len(4,LE)][XML metadados: Nome/Tipo/DOW][binário]`. **Evidência:** `GetRotinaLogs` devolveu um
    **PDF real** (`MODULO_PRODUCAO_ARQUIVO_DE_LOG.pdf`, ~7 KB, `application/pdf`) ponta a ponta.
  - **Upload (putDoc/multipart)** — ✅ `EnvioDocumentoService`: 1 chamada por arquivo,
    `[len][XML PMEMORY + FileName] + bytes`, preservando **nome/usuário/ambiente**. **Evidência:** upload
    real montou `PostDocumentoOperacao` no `wdoc` e executou; a tela atualiza após o envio.
- **2.9.3 Segurança e validação**
  - **Sessão + sessionKey + ambiente** — ✅ VALIDA (`sessoes.validar`) no `SccidocController` antes de
    executar; ambiente validado.
  - **W_COP (AES + headers)** — ✅ `WcopCrypto` (decifra request, cifra resposta); params do upload vêm no
    header cifrado `application-data` (equivalente ao `HTTP_APPLICATION_DATA`).
  - **Autorização = igual ao resto** — ✅ mesma VALIDA + enforce pelo programa (USER); rejeita ambiente
    incorreto/sessão inválida (E004).
  - **Modo dev sem cripto** — ✅ requisição não cifrada é aceita (`estaCifrado` false → processa em texto).
- **2.9.4 Content-Type / Content-Disposition** — ✅ `SccidocController.respostaDocumento` +
  `mime()`: **inline** para visualização (GET de navegador via `AbrirUrl`) e **attachment** quando `DOW`,
  com **nome preservado**; mapeia PDF, ZIP, XLSX, CSV, DOCX, imagens (PNG/JPG/GIF/TIFF/BMP), etc.
- **2.9.5 Resposta e erros**
  - **Download: streaming do binário + headers** — ✅.
  - **Upload: sucesso JSON / falha `success:false` com meta** — ✅ (o bloco EXCEPT do programa vira
    `{"success":false,"message":...}`; o prefixo `[len]` da resposta é removido para o front decodificar).
  - 🟡 **"Falha ao gerar documento → resposta HTML simples"** — **diferença**: o reator hoje responde
    **JSON** de erro (não HTML) também no download. Funciona (o front trata), mas o `sccidoc.pas` devolvia
    **HTML** nesse caso específico. **Ajuste pequeno** se quiserem paridade exata (devolver HTML no erro de
    geração no fluxo GET de navegador).
- **2.9.6 Logs/auditoria de documentos** — ✅ `sccidoc`/`sccidoc_upload`/`sccidoc_view` registram
  **metadados** (programa, método, nº de arquivos, usuário, sessão válida), **nunca o conteúdo**.
- **2.9.7 Limpeza de temporários** — ➖ **responsabilidade do programa** (`wdoc` gera/converte/limpa seus
  temporários — ex.: PDF temporário do `GetErroExec`). O reator **não cria arquivos temporários** de
  documento (faz streaming) — não há resíduo do lado do launcher. (Para o fluxo de **10 GB/chunk** — 2.6 —
  a limpeza de blocos temporários **passará a ser do launcher** e está no débito.)

---

## 3. Requisitos Não Funcionais (resumo)

| Req | Status | Evidência / observação |
|---|---|---|
| 3.1 Performance/Escalabilidade | 🟡 | semáforo de concorrência no `ProgramExecutor`; **retry idempotente (GET)**; escala horizontal viável (sessão/tentativas em **Redis**). Falta teste de carga formal. |
| 3.2 Timeouts/Resiliência | 🟡 | timeout de execução (30 s) + retry GET. **Falta auto-restart/watchdog** (tirado do escopo por decisão). |
| 3.4 Segurança | ✅ | W_COP (AES/XOR), VALIDA, logs sem dado sensível, sem UPDATE indevido no banco. |
| 3.5 Disponibilidade | 🟡 | reator + Kong + Redis + OTel no ar; **sem** auto-restart hoje. |
| 3.6 Monitoramento/Logging | ✅ | **OpenTelemetry** (métricas + traces) → Collector; logs JSON; Kong `correlation-id`. |
| 3.8 Arquitetura/Integração | ✅ | **hexagonal** (Ports & Adapters), Kong na borda, integração SCCIDOC/oserver. |

## 6. OSERVER / InitFD — ✅ (sem alterar o legado)
O documento sugere alterar o oserver (múltiplos FDs/parametrização). **Não foi necessário:** o
`InitFD` usa **um fd bidirecional** (socketpair) e a ponte **`NativeOserverBridge` (JNA)** cria
`socketpair + posix_spawn` no fd 6 **sem tocar no `oserver`** nem nos binários. A sugestão vira
**opcional** (não é bloqueante).

## 7. Organização por Domínio — ✅
`identidade` (usa o legado por ora), `licencas` (scaffold, sem limite), **`documentos`** (integração
SCCIDOC/wcorp **completa**), `execucao`/`autenticacao` (maduros), `launcher` orquestra. Ver
[ARQUITETURA-INVENTARIO](ARQUITETURA-INVENTARIO.md).

## 9. Regras SCCIDOC/wcorp (checklist do documento) — ✅ (menos 1)
| Regra | Status |
|---|---|
| Passar pelo SCCIDOC | ✅ |
| Validar sessão/ambiente por header, parâmetro **ou cookie** | ✅ (cookie usado no GET de navegador) |
| Criptografar/decifrar W_COP | ✅ |
| Upload → multipart → `putDoc` | ✅ |
| Download → `getDoc`, repassando tipo/metadados fielmente | ✅ |
| Content-Type/Disposition conforme o programa | ✅ |
| Erros: **JSON** p/ falha lógica / **HTML** p/ falha de arquivo | 🟡 (JSON ok; **HTML falta**) |
| Limpar temporários após o ciclo | ➖ (do programa; do launcher só no fluxo 10 GB futuro) |
| Logs de acesso documental sem conteúdo | ✅ |

---

## O que FALTA (consolidado)

| Prioridade | Item | Requisito | Nota |
|---|---|---|---|
| **Alta** | **Upload resumível > 10 GB** (chunking, storage temp, progresso, tolerância a falha, cleanup, parametrização) | 2.6 | Novo fluxo/protocolo — não coberto pelo sccidoc atual |
| Baixa | Resposta **HTML** na falha de geração de documento (paridade com sccidoc.pas) | 2.9.5 / 9 | Hoje devolvemos JSON (funciona) |
| Média | **Resiliência de deploy** (auto-restart/watchdog) | 3.2 / 3.5 | Tirado do escopo por decisão |
| Baixa | **CAPTCHA real** (hoje só sinaliza o estado) | 2.1 | Opcional; fora da 1ª fase |
| Baixa | **Login por CPF** (modo `ExecutaLoginWebReact`) | 2.1 | Building block pronto (`/w/valida-acesso`); modo completo aguarda o fonte do `loginbd` |
| — | Teste de carga formal (3.1) e testes automatizados dos fluxos documentais | 4 | Recomendação do próprio documento |
