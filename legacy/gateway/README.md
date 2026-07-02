# launcher-gateway (Fase 1 — MVP)

Gateway Java do projeto de migração do launcher (Pascal/W_COP) descrito em `../regras.md`.
Implementa o padrão **Strangler** com roteamento **A/B/C** por feature flags.

- **(A) Java nativo** — funcionalidade já migrada (ainda não implementado).
- **(B) ProcessBuilder** — executa `.exe` Pascal por CLI/stdin (TLV), sem handoff de socket (ainda não implementado).
- **(C) Proxy Legacy** — proxy TCP para o W_COP/launcher Pascal (fallback; ainda não implementado).

## Etapa 1 (este commit)
Esqueleto que **sobe e responde**: endpoint `POST /v1/launcher/execute`, roteador A/B/C,
feature flags em memória (stub) e healthcheck.

## Como rodar
```bash
cd gateway
mvn spring-boot:run
# health:
curl http://localhost:8082/actuator/health
# execute (Fase 1: cai na Rota C por padrão e responde "não implementada"):
curl -X POST http://localhost:8082/v1/launcher/execute \
  -H "Content-Type: application/json" \
  -d '{"programa":"wcorp","metodo":"Login","wTela":"login","ambiente":"larcky","usuario":"joao","params":{}}'
```

## Coordenadas (ajustáveis)
Maven · Java 21 · Spring Boot 3.3.x · pacote base `com.prognum.launcher`.

## Etapas 2–3 (simulação) — funcionando
- **Rota C** (default): proxy **HTTP** para o W_COP. Hoje aponta para o **simulador embutido**
  (`/__wcop-sim/{programa}/{metodo}`). O fluxo HTTP é real — só o destino é simulado.
- **Rota B**: executor via ProcessBuilder em **modo simulado** (`launcher.executor.simulate=true`).
- `request-id` propagado (header `X-Request-Id`; gerado se ausente).

### Como alternar a rota (para testar)
- `--launcher.routing.global-legacy-fallback=true`  → **Rota C** (default).
- `--launcher.routing.global-legacy-fallback=false` → **Rota B** (enquanto A/registry não decidem).

### Como trocar pelo W_COP / .exe REAIS (sem mexer no código)
```yaml
launcher:
  legacy:
    wcop:
      base-url: http://HOST-DO-WCOP:PORTA/CONTEXTO   # URL real do W_COP (HTTP)
      simulator:
        enabled: false                                # desliga o simulador embutido
  executor:
    simulate: false                                   # passa a rodar o .exe Pascal de verdade
```

## Etapa 4 — Login BD (Rota A, simulado) — funcionando
Endpoints: `POST /v1/login`, `POST /v1/logout`, `GET /v1/session/validate`.
Catálogo de estados (`LoginOutcome`): OK, SENHA_VAI_EXPIRAR, SENHA_INCORRETA, USUARIO_INATIVO,
SENHA_EXPIRADA, TROCA_OBRIGATORIA, BLOQUEADO, CAPTCHA_OBRIGATORIO, LIMITE_ACESSOS.

Regras implementadas: verificação **bcrypt**; estados (inativo/expirada/troca/aviso);
**bloqueio progressivo** (captcha → bloqueio); **atraso + mensagem indistinguível** (anti-enumeração);
**sessão** com token separado da senha (1 ativa por usuário, logout automático ao novo login).

### Usuários de teste (in-memory) — senha `Senha@123`
| usuário | desfecho |
|---|---|
| joao | OK |
| maria | TROCA_OBRIGATORIA |
| carlos | SENHA_EXPIRADA |
| ana | USUARIO_INATIVO |
| bia | SENHA_VAI_EXPIRAR (2 dias) |

```bash
curl -X POST http://localhost:8082/v1/login -H "Content-Type: application/json" \
  -d '{"usuario":"joao","senha":"Senha@123","ambiente":"larcky"}'
```

### Config (application.yml → `launcher.auth.*`)
`login-err-delay-ms`, `max-erros`, `max-erros-captcha`, `captcha-habilitado`,
`dias-aviso-expiracao`, `session.ttl-segundos`, `session.max-por-usuario`.

### Trocar pelo banco real
Implementar um `UserRepository` lendo o **Firebird** (`usuario.gdb`) — só essa classe muda
(portas: `UserRepository`, `SessionStore`, `LoginAttemptStore`). md5crypt legado entra no
`PasswordVerifier` (verificar e re-hashear para bcrypt no login — Q8).

## Etapa 5 — Troca de senha (`POST /v1/passwd`) — funcionando
Valida a senha atual → aplica a **política de complexidade** (RN-010..012) → checa **rodízio/histórico**
(RN-013) → grava o novo hash (**bcrypt**) e zera `mustChange`.
Estados: `OK`, `SENHA_INCORRETA`, `SENHA_FRACA` (mensagem detalhando o que falta), `SENHA_JA_USADA`.

```bash
curl -X POST http://localhost:8082/v1/passwd -H "Content-Type: application/json" \
  -d '{"usuario":"maria","senhaAtual":"Senha@123","novaSenha":"NovaSenha@9"}'
```
Config em `launcher.auth.policy.*` (min-caracteres, composição, max-repetidos, max-sequenciais, histórico).

> Nota: a política vale **na troca** — senhas legadas existentes não precisam atender (ex.: a semente
> `Senha@123` tem a sequência `123` e seria barrada numa troca, mas funciona no login).

## Etapa 6 — Feature Registry (roteamento real) — funcionando
O roteador A/B/C agora consulta o **Feature Registry** (RF11): regras por `wTela`/usuário/ambiente,
**rollout percentual** sticky (canary) e **kill-switch global** (rollback instantâneo).
Precedência: kill-switch (C) → legado por escopo (C) → nativo (A) → ProcessBuilder (B).

Admin (proteger via Kong/Spring Security em produção):
```bash
# rollback global (tudo -> C) / liberar
curl -X POST "http://localhost:8082/v1/admin/kill-switch?on=true"
curl -X POST "http://localhost:8082/v1/admin/kill-switch?on=false"

# migrar uma tela para Java nativo (A), 100%:
curl -X POST http://localhost:8082/v1/admin/features -H "Content-Type: application/json" \
  -d '{"wTela":"login","rota":"NATIVE_JAVA","rolloutPercent":100,"prioridade":10}'

# canary 20% para uma tela:
curl -X POST http://localhost:8082/v1/admin/features -H "Content-Type: application/json" \
  -d '{"wTela":"consulta","rota":"NATIVE_JAVA","rolloutPercent":20,"prioridade":10}'

# fixar uma tela no legado (rollback por escopo):
curl -X POST http://localhost:8082/v1/admin/features -H "Content-Type: application/json" \
  -d '{"wTela":"consulta","rota":"LEGACY_PROXY","prioridade":5}'

curl http://localhost:8082/v1/admin/features                 # listar
curl -X DELETE http://localhost:8082/v1/admin/features/<id>   # remover
```
`launcher.routing.global-legacy-fallback` (yml) define o **valor inicial** do kill-switch.
Depois: trocar `InMemoryFeatureRegistry` por adapter **DB + Redis** (mesma interface `FeatureRegistry`).

## Etapa 7 — Observabilidade (request-id + logs JSON) — funcionando
- **`request-id`** ponta-a-ponta: filtro lê/gera o header `X-Request-Id`, coloca no **MDC** (vai em todo log)
  e devolve no header da resposta.
- **Logs estruturados JSON** (logback + logstash-encoder, ELK-ready) com eventos:
  - `http_request` — método, path, status, `duracaoMs`
  - `execute` — `rota` (A/B/C), usuário, wTela, sucesso, `duracaoMs`
  - `login` / `passwd` — usuário, `outcome`, sucesso
- Pronto para Prometheus/Grafana e dashboards "Java vs Pascal" (rota nos eventos).

## Etapa 8 — Compatibilidade com o loginbd (md5crypt) — funcionando
`PasswordVerifier` agora valida **bcrypt ($2)** e **md5crypt ($1$)** (o hash legado do `loginbd.pas`/`usuario.gdb`).
No **primeiro login** bem-sucedido de um hash legado, a senha é **re-hasheada para bcrypt** (migração Q8) — evento `rehash` no log.
Usuário de teste `legado` (senha `Senha@123`) demonstra o fluxo.

> Próximas etapas: adapter **Firebird** (lê `usuario.gdb` — o `PasswordVerifier` já aceita os hashes) + sessão **Redis**
> → **EMAILPWD** (reset por e-mail) e **VALIDA** (revalidação de sessão) do `loginbd` → Rotas B/C reais (W_COP HTTP / `.exe`).
