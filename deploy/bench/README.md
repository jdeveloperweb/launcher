# Bench A/B de latência — legado `/aejs` × novo `/aejs-l`

Evidência da migração: a **mesma operação** medida nos dois caminhos, pela **borda**
(Apache/Kong), para responder *"a migração mudou a latência que o usuário sente?"*.

## Método (o que torna a evidência crível)

1. **A/B pela borda** — dispara a mesma requisição para `/aejs` (Pascal legado) e
   `/aejs-l` (Java novo). Mede ponta-a-ponta, incluindo TLS/proxy/rede.
2. **Intercalado** (A,B,A,B…) — cada iteração bate nos dois quase ao mesmo tempo, então
   ambos pegam as **mesmas condições** de DB/backend/rede. Cancela deriva ao longo do teste.
3. **Warmup** — descarta os primeiros `N_WARM` requests de cada lado. A JVM tem JIT + pools
   frios (a 1ª `tela` chega a ~3800ms; as seguintes caem pra dezenas de ms). Sem isso o
   número do novo sai injustamente pessimista.
4. **Percentis, não média** — reporta p50/p90/p95/p99. A média esconde a cauda, e é na
   cauda (p95/p99) que a arquitetura aparece.
5. **Segmentar por caminho** — o `/aejs-l` **não** faz tudo igual ao `/aejs`:

   | Operação | `/aejs` | `/aejs-l` | Delta esperado |
   |---|---|---|---|
   | **login** | Pascal in-process | **Java nativo** (scci-core), sem Pascal | empata ou melhora |
   | **dispatch** (wmenu/wtela) | Pascal in-process | launcher → **hop REST** → pascal-executor → Pascal | +1 hop (localhost, poucos ms) |
   | **download** (GetDocumento) | Pascal in-process | **Java nativo** (scci-core/documentos) | empata ou melhora |
   | **upload** | Pascal in-process | roteador (Pascal ou Java) | conforme a flag |

   Jogar tudo num número só engana: o hop do dispatch "contamina" os migrados. **Leia por
   operação.** A história honesta: *nos domínios migrados empatamos/ganhamos; nos ainda-Pascal
   pagamos ~X ms de hop, em troca de observabilidade e escala horizontal que o legado não tem.*

## Como rodar

```bash
AEJS_BASE=https://SEU_HOST/aejs \
AEJSL_BASE=https://SEU_HOST/aejs-l \
AMB=/u10/c6bank/suporte/scat112934 \
USER_SCCI=supervisor PASS_SCCI='Tempo+2024' \
N_WARM=30 N_SAMPLES=200 \
OPS="login dispatch download upload" \
./bench-ab.sh
```

- **login** e **dispatch** funcionam de imediato.
- **download**: informe um doc REAL do scat em `DL_EXTRA` (ex.: `DL_EXTRA='"NU_SISTARQ":"12345"'`)
  — senão mede o **caminho de erro** (doc não encontrado), que não é comparável ao de sucesso.
- **upload**: gera um arquivo de teste sozinho; para um upload *real* passe os campos em
  `UP_EXTRA` (ex.: `UP_EXTRA=(-F "NU_OPERACAO=000000105")`).

Saída: uma tabela de percentis por (op, stack) + um bloco **DELTA** (aejsl − aejs) e o
**CSV bruto** (`op,stack,http_code,total_s,ttfb_s,connect_s,tls_s`) para gráfico/planilha.

> Rode de um host estável e próximo da borda (o próprio servidor, batendo na URL da borda),
> para não medir ruído de VPN/WAN do cliente. Use um **scat de suporte**, nunca produção.

## Corroboração server-side (caixa-branca) — evidência que já existe

O número A/B diz *quanto*; a telemetria diz *por quê* e decompõe onde o tempo vai:

- **`duracaoMs`** no log `http_request` do launcher — latência por request, de graça.
- **Actuator** `/actuator/metrics/http.server.requests` — count/total/max por rota.
- **X-Ray** — decompõe o span: edge → scci-core → pascal-executor → DB. **O legado não tem isso**
  — é evidência da própria migração.
- **CloudWatch** (micrometer-otlp) — histograma/percentis ao longo do tempo.
- Legado `/aejs`: latência sai do **Apache access log** se o `LogFormat` tiver `%D` (µs).

## Throughput / concorrência (passo seguinte)

Este harness é **serial** (mede latência limpa). Para vazão sob carga (req/s, saturação),
rode `hey`/`wrk`/`k6` contra cada base com concorrência controlada — mesma allow-list de
operações, fora de horário de pico.
