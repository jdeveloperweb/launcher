# Migração do `acesso` (login + sessão) para o `scci-core` — plano em fases

> Objetivo: mover o domínio de **autenticação** (hoje em Java, mas **dentro do launcher**) para o
> `scci-core` como os módulos **`acesso`** e **`sessao`**, deixando o launcher como **edge fino**
> (transporte W_COP + gate de sessão). Mesmo padrão Strangler já provado no `documentos`
> (mover para o scci-core → rotear por feature-flag → validar ao vivo → promover → remover o local).

## 0. Situação atual (o que existe hoje)

Todo o auth **já é Java hexagonal** (família B), porém acoplado ao launcher:

| Camada | Onde está hoje | O que é |
|---|---|---|
| **Domínio** | `launcher-domain/.../autenticacao/*` | models, ports (in/out), `PasswordPolicy`, `mapeado/*` |
| **Aplicação** | `launcher-application/.../autenticacao/*` | `LoginService`, `SessaoService`, `TrocarSenhaService`, `RecuperarSenhaService`, `ValidacaoAcessoService`, `AutenticadorBanco`, `mapeado/Provisao*` (Strategies por cliente) |
| **Saída (DB)** | `launcher-adapters-out/.../autenticacao/scc/*` | `SccCredenciaisRepository`, `SccSenhaRepository`, `SccSessionRepository`, `SccValidacaoAcessoRepository`, `SccRecuperacaoSenhaRepository`, `SccProvisionamentoRepository` |
| **Saída (Redis)** | `.../autenticacao/redis/*` | `RedisRepositorioSessao` (cache), `RedisContadorTentativas` |
| **Saída (cripto/e-mail/config)** | `.../autenticacao/{crypto,email,config}/*` | `VerificadorSenhaBcryptMd5`, `SmtpEnvioEmail`, `MetodoLoginPadrao` |
| **Entrada (edge)** | `launcher-adapters-in/.../autenticacao/rest/AutenticacaoController` | `/w/login`, `/w/password`, `/w/email-pwd`, `/w/valida-acesso`, `/w/logout` (W_COP) |
| **Gate de sessão** | `SessaoService.validar` usado por `SccidocController` e `DespachoController` | Redis primeiro; miss → revalida na `SCCI_SESSION` (DB) e reidrata |

**Sessão = 2 stores** (fiel ao VALIDA do `launcher.pas`): **Redis** (cache rápido, TTL 1800s) +
**`SCCI_SESSION`** (DB autoritativo). `registrar` grava nos dois; `validar` lê Redis (hit) ou DB (miss).

## Arquitetura-alvo (o corte)

```
front → Kong → launcher (EDGE)                         scci-core (interno, escalável)
                ├─ W_COP: decifra request / cifra resp   ┌─ acesso:  login/senha/email-pwd/valida-acesso
                ├─ ROTEADOR (flag acesso.<metodo>) ──REST─┤            + Strategies (BANCO, MAPEADO_*)
                │     fallback = Java local (transição)   │            + repos DB (SOMENTE LEITURA no login)
                └─ GATE de sessão → lê Redis direto       └─ sessao:  ciclo de vida (Redis + SCCI_SESSION)
                                          ▲                              registrar/consultar/contar/encerrar
                                          └──────── mesmo Redis ─────────┘
```

**Decisões (herdadas do desenho aprovado):**
- **Cripto continua no edge** (`comum/cripto`, in-process). O scci-core **nunca** vê o blob cifrado:
  o launcher decifra e manda **texto** pela rede **interna confiável** (igual ao `documentos`).
- **Gate de sessão fica no launcher lendo Redis direto** — sem hop REST por request autenticado
  (é o caminho quente). Só o **ciclo de vida** da sessão (criar/encerrar/contar) vai pro `scci-core`.
- **`acesso` é stateless** → escala horizontal atrás do NLB, estado compartilhado no Redis (igual `documentos`).

---

## Fases

### Fase 0 — Contrato + esqueleto (sem mudança de comportamento)
- Definir o **contrato REST interno** (`/interno/acesso/*`, `/interno/sessao/*`) e os DTOs.
- Ligar os módulos vazios `scci-core-acesso` e `scci-core-sessao` no `scci-core-bootstrap`
  (deps: `comum/ambiente` p/ JDBC, `scci-core-kernel`; **sem** `comum/cripto`).
- **Entregável:** ADR curto fixando o corte edge×core e o formato da chave/serialização da sessão no Redis
  (tem que ser **idêntico** entre launcher-gate e scci-core-sessao).
- **Risco:** zero (nada plugado ainda).

### Fase 1 — Mover o domínio `acesso` (começando por LOGIN)
- Mover para `scci-core-acesso`: `domain/autenticacao/*` (models/ports/policy/mapeado),
  `application/*` (`LoginService`, `AutenticadorBanco`, `mapeado/Provisao*`, `ValidacaoAcessoService`,
  `TrocarSenhaService`, `RecuperarSenhaService`) e `adapters-out/{scc,crypto,config,email}`.
- Criar `AcessoInternoController`: `POST /interno/acesso/login` (depois `/senha`, `/email-pwd`, `/valida-acesso`).
  Entrada = texto (usuario/senha/ambiente/ip); saída = `ResultadoLogin` JSON. **Sem W_COP** (é interno).
- **Manter o login Java local do launcher intacto** (não apagar) — é o fallback.
- **Entregável:** `scci-core` faz login por REST, testado com mock/unit.
- **Risco:** baixo (código movido, mesmos POJOs; login é **leitura** no DB).

### Fase 2 — Mover `sessao`
- Mover para `scci-core-sessao`: `SessaoService`, `RedisRepositorioSessao`, `SccSessionRepository`,
  `RedisContadorTentativas`.
- `scci-core` passa a **criar** a sessão no login (Redis + `SCCI_SESSION`) e a **encerrar** no logout.
- No **launcher**, deixar um validador de sessão **slim, read-only** sobre o **mesmo Redis**
  (`GateSessaoRedis`) — mesma chave/serialização da Fase 0. É o gate por-request (sem hop).
- **Decisão a bater:** no **miss** de Redis (sessão expirada/evccionada), o gate (a) **rejeita** →
  re-login (simples, recomendado; TTL 1800s cobre o caso comum) ou (b) faz **1 REST**
  `/interno/sessao/validar` p/ o fallback `SCCI_SESSION`. Recomendo **(a)** com **(b)** atrás de flag.
- **Risco:** médio — a consistência Redis entre 2 processos é o ponto sensível (Fase 0 mitiga).

### Fase 3 — Launcher vira EDGE (cliente REST + flag)
- `AutenticacaoController`: decifra W_COP → `ClienteScciCoreAcesso` (REST) → cifra. Igual ao
  `ClienteScciCoreDocumentos`.
- Roteador `RoteadorLogin` (decorator do `LoginUseCase`) com flag `acesso.Login` →
  scci-core (JAVA) ou launcher-local (JAVA) — **fallback** se o scci-core cair (resiliência).
  Idem `/w/password`, `/w/email-pwd`, `/w/valida-acesso`, `/w/logout`.
- Gate continua Redis-local.
- **Entregável:** com a flag ligada, `/w/login` roda no scci-core ponta a ponta.
- **Risco:** baixo (flag + fallback; rollback = desliga a flag).

### Fase 4 — Validar ao vivo → promover → remover o auth local
- Validar login/gate ponta a ponta num ambiente de teste **nomeado por você** (login = **SOMENTE
  LEITURA**; sem rehash md5→bcrypt; `MAPEADO_*` que **provisiona** usuário é **escrita** → cautela extra).
- Promover as flags (`acesso.*`).
- **Só então** remover o domínio/app/adapters de auth do launcher, deixando no edge apenas:
  `AutenticacaoController` (W_COP) + `ClienteScciCoreAcesso` + `GateSessaoRedis`.

---

## Pontos sensíveis / invariantes (não violar)

1. **Login = SOMENTE LEITURA** no banco do cliente. Nada de `UPDATE`, nada de rehash md5crypt→bcrypt.
2. **`SCCI_SESSION` e o contador de tentativas** são escrita — só no fluxo normal (login/logout), nunca em teste manual sem seu OK.
3. **`MAPEADO_*` (Itau/C6/BRB/Cashme/Unicred/Ailos/Direto)** provisiona usuário (INSERT) → é escrita; validar por último e num ambiente que você nomear.
4. **Serialização/chave da sessão no Redis** tem que ser **idêntica** entre launcher-gate e scci-core (Fase 0 congela isso).
5. **W_COP fica no edge**: a chave AES/contexto é config do launcher; o scci-core recebe texto pela rede interna (confiável). Se precisar, mTLS interno.
6. **Ir ao ar por cliente** exige endpoint/credenciais **daquele** cliente (não extrapolar de um ambiente para outro).
7. **Produção `/aejs` (launcher Pascal) intocada** — tudo no trilho paralelo `/aejs-l` (8083) + scci-core (8090).

## Ordem sugerida de execução
`Fase 0 → 1 (login) → validar login isolado → 2 (sessão) → validar gate → 3 (edge/flag) → 4 (promover+limpar)`.
Depois: `/w/password`, `/w/email-pwd`, `/w/valida-acesso` (mesma mecânica, um de cada vez).
