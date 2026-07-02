# Análise do Legado — Hooks/Side-effects & Matriz de Encoding

Complementa a migração: mapeia os **efeitos colaterais** que o `loginbd.pas` executa (para o login
nativo do reator não perder nada) e a **matriz de codificação** por fluxo/programa.

---

## 1. Hooks / side-effects do login/troca/logoff (fonte: `legacy/loginbd.pas`)

| Fluxo | Side-effect no legado | No reator | Situação |
|---|---|---|---|
| **Login** (`ExecutaLoginBD`) | **read-only** (só verifica senha + estados); a sessão é gravada pelo caller via `GravaSection` (SCCI_SESSION) | `SccSessionRepository.registrar` (SCCI_SESSION) + `RedisRepositorioSessao` | ✅ replicado |
| **Login** — limite de sessões | `ValidaQtdLogin(QTDMAXLOGIN, usuario)` | `SessaoService.contarSessoesAtivas` + config `max-logins-simultaneos` | ✅ replicado (parametrizável) |
| **Troca de senha** (`ExecutaPasswdBD`) | `UPDATE usuario` — rotaciona `NO_SENHA1..5`, `IN_TROCA_SENHA_PROXIMO_LOGIN`, `DT_ULTIMA_TROCA_SENHA` | `SccSenhaRepository.gravar` | ✅ replicado |
| **Troca de senha (variante SCAT-Internet)** (`ExecutaPasswdScatInternet`) | ALÉM do `usuario`, faz `UPDATE USUARIO_SCAT_INTERNET SET ...` | — | 🟡 **GAP** — o reator não atualiza `USUARIO_SCAT_INTERNET`. Relevante **só** para clientes que usam o SCAT-Internet |
| **Recuperação de senha** (`ExecutaEmailPwd`) | `GeraLogEmailPwd` (grava na **tabela de log do SCCI** via `GeraLog`) + `EnviaEmail` (SMTP) + `UPDATE usuario` | `RecuperarSenhaService`: e-mail (SMTP) + update; log via **JSON (slf4j)** | 🟡 **diferença** — auditoria vai p/ log estruturado, **não** p/ a tabela de log do SCCI (`GeraLog`). Avaliar se precisa gravar lá |
| **Recuperação (variante SCAT-Internet)** (`ExecutaEmailPwdScatInternet`) | idem, tocando `USUARIO_SCAT_INTERNET` | — | 🟡 mesmo GAP do SCAT-Internet |
| **Logoff** | encerra a sessão (SCCI_SESSION) | `SessaoService.encerrar` (`/w/logout`) | ✅ replicado |
| **Login por CPF** (`ExecutaLoginWebReact`) | fluxo alternativo (CPF/protocolo) | building block `/w/valida-acesso` (validações portadas) | 🟡 modo completo pendente |

**Conclusão:** o login/senha/logoff nativo cobre os side-effects principais (sessão, rodízio,
limite, e-mail). **Pendências a decidir:** (a) atualizar `USUARIO_SCAT_INTERNET` na troca/recuperação
para clientes SCAT-Internet; (b) se a auditoria precisa ir para a **tabela de log do SCCI** (`GeraLog`)
além do log JSON. Ambas são **fáceis** (mais um UPDATE / mais um INSERT no adapter) quando confirmadas.

> Nota: para os **programas "w"** (documentos, produção, etc.) **não há perda de hook** — o reator
> executa o binário real, então qualquer efeito colateral interno continua acontecendo.

---

## 2. Matriz de codificação (encoding) por fluxo

O I/O com os programas Pascal (Linux) é **ISO-8859-1 (Latin-1)** de ponta a ponta. Ponto crítico: a
**resposta ao front tem que sair em ISO-8859-1** (não UTF-8), senão o front mostra `Ã§` no lugar de `ç`.

| Fluxo | Codificação | Peça no reator |
|---|---|---|
| Request cifrado (front → reator) | AES-128-CBC → claro **UTF-8** | `WcopCrypto.decifraRequest` |
| Resposta cifrada (reator → front) | XOR posicional + **ISO-8859-1** | `WcopCrypto.cifraResposta` |
| Params ao programa (`<PMEMORY>`) | **ISO-8859-1** | `ProgramExecutor` (getBytes ISO-8859-1) |
| Resposta do programa (blocos oserver) | **ISO-8859-1** | `ProgramExecutor.parseBlocos` (new String ISO-8859-1) |
| Documento binário (get/putDoc) | **bytes crus** (sem conversão) | `DocumentoService` / `SccidocController` |
| Metadados do documento (`[len][xml]`) | **ISO-8859-1** (`len` LE 4 bytes) | `DocumentoService.le32` + `tag` |
| `launcherenv.ini` | **ISO-8859-1** | `LauncherEnvReader` |
| Logs (JSON) | **UTF-8** | `logback` |

**Por programa:** como todos os "w" são compilados para Linux (FPC/Latin-1), o encoding é **uniforme
(ISO-8859-1)** — não há programa que fuja disso hoje. Se algum programa específico passar a emitir
UTF-8, o ponto de ajuste é único: o `new String(..., charset)` no `ProgramExecutor.parseBlocos`.

---

## 3. Login "payload-mapeado" (família B) — provisionamento JIT

Sete clientes cujo IdP externo (OpenID/JWT) **já autenticou** o usuário e manda os atributos cifrados
no campo "senha" (WebCrypt). O login não verifica senha — **provisiona** o USUARIO conforme os atributos
e emite a sessão. Portados como Strategy (`AutenticadorMapeado` + `ProvisaoXXX`), fiéis a cada `.pas`,
com o acesso a banco isolado no port `ProvisionamentoUsuario` (adapter `SccProvisionamentoRepository`,
multi-banco). Testes: `PayloadMapeadoTest` (parser) + `ProvisaoMapeadoTest` (26 casos, fake do port).

| Cliente | Formato do payload | Provisionamento (fiel ao `.pas`) | Situação |
|---|---|---|---|
| **direto** | XML | usuário (e-mail) tem que existir; devolve grafia real | ✅ portado + testado |
| **brb** | XML | usuário existe; valida perfil por nome; UPDATE PERF_PRIMARIO se mudou | ✅ portado + testado |
| **cashmeweb** | XML (e-mail) / — (CPF) | e-mail: como brb; CPF: exige contrato em CADMUT → entra `usuarioweb:` | ✅ portado + testado |
| **c6** | XML | valida perfil; **INSERT** se novo (entidade default + setor); atualiza perfil/e-mail AD | ✅ portado + testado |
| **itau** | `!#___`+perfil | valida perfil (exato); INSERT ou UPDATE (entidade default do env) | ✅ portado + testado |
| **ailos** | CommaText | deriva cooperativa/PA → ENTIDADE_SCCI; valida entidades/perfil; INSERT se novo | ✅ portado + testado |
| **unicred** | CommaText (JWT) | extrai usuário/entidade do `jwt_id_identifier`; subordinação; exige existir | 🟡 portado (ver GAP) |

**Side-effects replicados:** INSERT/UPDATE USUARIO (perfil, entidade, setor, e-mail AD), correção de
grafia (login case-insensitive: a sessão e o USER usam a grafia real, e o front recebe o `userName`
corrigido de volta — antes o wcorp fazia isso via `'T'+token+':'+usuario`).

**GAPs / diferenças a validar antes do go-live de cada cliente:**
- 🟡 **unicred — subordinação transitiva.** `UsuarioSubordinadoAEntidade` do legado usa a hierarquia
  recursiva de ENTIDADES (`EntidadeSubordinadaAEntidade`, do `sccilib`). O port cobre o **caso-base**
  (entidade informada == entidade primária/secundária do usuário); a subordinação por **ancestralidade**
  ainda não foi portada (loga `unicred_subordinacao_transitiva_nao_portada`). Portar quando for ligar o unicred.
- 🟡 **Log de auditoria (GeraLog).** brb/c6 gravam na tabela de log do SCCI (`uloglib.GeraLog`) na
  atualização de perfil/e-mail AD. O reator loga em **JSON (slf4j)** — mesma diferença do
  `RecuperarSenhaService` (ver §1). Avaliar se precisa gravar na tabela de log.
- 🟡 **Generator do UIDUSUARIO.** É o único ponto dependente de driver no INSERT — tratado por
  DRIVERNAME (`GEN_ID`/`nextval`/`.NEXTVAL`/`NEXT VALUE FOR`); fallback portável `MAX(UIDUSUARIO)+1`
  (não concorrente) para driver não previsto, com log. Validar o generator no banco de cada ambiente.

> **Famílias C/D pendentes** (precisam do sistema/credenciais do cliente, não portáveis sozinhas):
> banese/sicredi/sisbr (SOAP/JWT/OAuth externos), loginad (LDAP), poupex/integracao (stubs).
