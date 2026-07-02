# Decisões de Arquitetura (ADRs) — Launcher Java

Registro curto das decisões-chave (formato ADR: contexto → decisão → consequência). Ordem cronológica.

---

## ADR-001 · Arquitetura hexagonal (Ports & Adapters)
**Contexto:** migrar o launcher Pascal para Java sem acoplar regra a framework/IO.
**Decisão:** organizar em `domain` (puro) · `application` (casos de uso POJO) · `adapters-in`/`adapters-out` · `bootstrap`; dependência sempre para dentro.
**Consequência:** núcleo testável sem Spring (48 das 73 classes); dá pra trocar JDBC↔Redis↔oserver sem tocar na regra. Custo: mais módulos/indireção.

## ADR-002 · A fronteira é o oserver — reescrever transporte, EXECUTAR os programas
**Contexto:** a regra de negócio mora dentro dos binários "w" (milhares de regras).
**Decisão:** reescrever só o **transporte/orquestração** (launcher.pas/wcorp.pas/sccidoc.pas/oserver.pas) e **executar os binários Pascal reais** (wtela/wmenu/wdoc).
**Consequência:** risco baixíssimo (zero reimplementação de regra de programa), contrato byte-a-byte. Custo: dependência dos binários legados continua.

## ADR-003 · Ponte nativa JNA (socketpair) em vez de alterar o oserver
**Contexto:** o `InitFD` do oserver usa **um fd bidirecional** (socketpair); a JVM não cria socketpair.
**Decisão:** `NativeOserverBridge` via **JNA** (`socketpair` + `posix_spawn` no fd 6), sem tocar no oserver nem recompilar binários.
**Consequência:** falamos o protocolo real sem alterar o legado. Alternativa descartada: mudar o `InitFD` p/ 2 fds (obrigaria recompilar tudo).

## ADR-004 · Login/senha nativos (reescrever `loginbd`) vs. executar
**Contexto:** login/senha são regra **simples e mapeável** (md5crypt + estados).
**Decisão:** reescrever em Java (`LoginService`/`AutenticadorBanco`/`TrocarSenhaService`) contra a mesma base; **somente leitura no login**.
**Consequência:** ganhamos multi-banco + hardening (bloqueio/captcha/atraso) sem tocar no binário. Atenção: hooks laterais do legado precisam ser mapeados (ver ANALISE-LEGADO).

## ADR-005 · Preservar o contrato W_COP byte-a-byte (adiar REST moderno)
**Contexto:** o front existente fala W_COP (AES no request, XOR/ISO-8859-1 na resposta).
**Decisão:** manter o contrato **idêntico**; NÃO introduzir problem+json/Swagger/versionamento/JWT próprio agora.
**Consequência:** zero breaking change no front. API REST moderna fica para quando o front evoluir.

## ADR-006 · Sessão distribuída (Redis) + autoritativa (SCCI_SESSION)
**Contexto:** o VALIDA do launcher revalida o token; múltiplas instâncias precisam compartilhar estado.
**Decisão:** cache rápido no **Redis** + store autoritativo na **SCCI_SESSION** (`SessaoService`).
**Consequência:** escala horizontal e sobrevive a restart. Contador de tentativas idem (Redis).

## ADR-007 · Login multi-cliente via Strategy (config por cliente)
**Contexto:** o legado tem 17 `loginXXX.pas` (BANCO/OAuth-pré-autenticado/API-externa/LDAP).
**Decisão:** um port `Autenticador` com uma **Strategy por mecanismo**, escolhida pela **config do cliente** (`MetodoLoginResolver`); o coordenador (`LoginService`) concentra o comum.
**Consequência:** portar um cliente novo do mesmo tipo = configuração. Ligar cada cliente ao ar precisa endpoint/credenciais deles.

## ADR-008 · Autorização por operação é dos PROGRAMAS (não do launcher)
**Contexto:** `UsuarioTemPerm` é chamado dentro dos programas (apiscci/apilib), que resolvem `PegaUsuario = getenv('USER')`.
**Decisão:** o reator injeta `USER=<usuário da sessão>`; o programa enforça. O launcher **não** duplica o gate.
**Consequência:** fiel ao legado, sem risco de dupla checagem. `AutorizacaoPort` = hook opcional sem uso.

## ADR-009 · Kong na borda (DB-less) · TLS no Apache
**Contexto:** roteamento por domínio + rate-limit + correlação, sem tocar no Apache.
**Decisão:** **Kong DB-less** na 8082 (o Apache proxya), roteando por domínio; plugins correlation-id + opentelemetry + **rate-limiting**; TLS fica no Apache.
**Consequência:** borda desacoplada. GOTCHA: mudança no `kong.yml` declarativo exige **restart do container** (o `kong reload` nem sempre aplica).

## ADR-010 · Nome do artefato = `launcher` (sem "gateway"/"hex")
**Contexto:** vestígios do protótipo ("gateway") e do qualificador "hex" poluíam o nome.
**Decisão:** artefato/serviço = **`launcher`**; "hexagonal" fica só na descrição da arquitetura.
**Consequência:** nomes consistentes (parent/jar/main-class/service/dir/containers).
