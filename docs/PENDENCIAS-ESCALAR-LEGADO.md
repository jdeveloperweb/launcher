# Pendências — escalar o legado (`pascal-executor`)

> O `pascal-executor` é **pinado** hoje. O que o prende é **estado mutável em disco local** (os
> documentos em FileSystem + os `ambiente/`) e os **binários Pascal**. Tirando isso do caminho +
> garantindo **idempotência**, ele vira N réplicas atrás de um LB — como o `launcher`/`scci-core`.

**Lembrete estratégico:** o `pascal-executor` é a âncora legada **em extinção** (Strangler). Escalar o
legado só compensa se ele for gargalo **agora** e a migração do domínio estiver longe. Muitas vezes o
ROI melhor é **migrar o programa quente pro `scci-core`** (que já escala nativo).

---

## A. Tirar o estado do disco local  ← o bloqueador principal
- [ ] **Documentos → storage compartilhado.** Migrar do FileSystem local para **S3** (o legado **já
      suporta**: `tp_gravacao = 2`, `LocalArmazenamentoS3 = 'aws://s3'`, `GravarArquivoNoS3` no
      `wsistarqlib`) **ou** um volume de rede (NFS/EFS) montado idêntico em todos os nós.
- [ ] **Migrar os arquivos existentes** (FileSystem → S3) por ambiente.
- [ ] **Config por ambiente** (`launcherenv.ini`, `ambiente/`) em mount compartilhado ou replicado.
- [ ] Apontar `scciconf.LocalArmazenaDocImgs` do ambiente para o storage compartilhado.

## B. Distribuir os binários
- [ ] **Assar os binários Pascal + oserver na imagem** (container) ou montar de um share read-only.
- [ ] Garantir **versão idêntica** dos binários em todos os nós.

## C. Rodar N instâncias + LB
- [ ] Subir N `pascal-executor` atrás de um **LB / serviço interno**.
- [ ] Apontar `launcher.pascal-executor.url` para o **LB** (não host fixo).
- [ ] Usar o `/actuator/health` (já existe) como readiness no LB.

## D. Idempotência / dedup — segurança sob retry + N réplicas
> Com fleet + retries, a mesma operação chega repetida. Para **escrita**, executar 2× é bug. O
> **gate do launcher** é o lugar ideal (é o funil e já fala com Redis).

- [ ] **Dedup no gate:** `SET idem:{sessao}:{key} <marker> NX PX <ttl>`.
      - `NX` **passa** (1ª cópia) → marca **in-flight**.
      - `NX` **falha** (duplicata) → se **concluída**, devolve a **resposta cacheada** (replay); se
        **em andamento**, devolve **409/425**.
- [ ] **Escopo:** só métodos **NÃO idempotentes** (upload/`PostDocumento`, provisão família B, troca de
      senha, …). GET/download **não** precisa (e é idempotente por natureza).
- [ ] **Chave de idempotência do cliente** (header/UUID por operação). Sem isso, derivar de
      `hash(usuário + ambiente + programa + método + corpo)` — **ressalva:** re-submit legítimo do mesmo
      conteúdo seria deduplicado.
- [ ] **TTL do lock ≥ tempo máx de execução** (ex.: `> executor.timeout` = 30s), para o lock **não
      expirar no meio** (senão a duplicata passa).
- [ ] **Sucesso:** guardar a **resposta** por ~24h → **replay** para retries. Cachear **só acks
      pequenos** (ex.: `{"success":true,"dados":{"ID_INSERIDO":293}}`); **nunca** binário grande.
- [ ] **Falha transitória:** **apagar** a chave (deixa o retry re-executar de verdade).
- [ ] Redis **compartilhado** entre as réplicas → o `SET NX` é atômico e vale para todo o fleet.

## E. Cuidados de legado (verificar antes)
- [ ] **Licença por host** do Pascal/oserver? (pode bloquear N nós)
- [ ] **Lock files / pipes nomeados / porta singleton**?
- [ ] **Temporários:** garantir temp **por-instância**, não um caminho fixo compartilhado.
- [ ] **Concorrência de escrita** no storage: S3 resolve; NFS precisa de locking. (o gerador de ID
      `sq_id_sistarq` é **atômico no banco** → sem colisão de ID entre nós.)

## F. Ganho barato (antes de tudo)
- [ ] **Vertical:** subir a caixa (CPU/RAM) + `executor.max-concorrentes`.
- [ ] **Levantar onde os documentos de cada cliente moram hoje** (FileSystem vs S3) — quem **já** usa S3
      está a um LB de distância.

## G. Estratégico
- [ ] Avaliar ROI **caso a caso**: migrar o programa quente pro `scci-core` × escalar o legado.

---

### Ordem sugerida
`F (vertical + levantamento)` → `D (idempotência — vale mesmo sem escalar, protege retries)` →
`A (storage compartilhado)` → `B (binários na imagem)` → `C (N + LB)` → validar → medir.

> **Nota:** o item **D (idempotência)** vale ligar **já**, mesmo com 1 réplica — protege contra
> double-submit/retry do front hoje, e é pré-requisito para qualquer escala horizontal com escrita.
