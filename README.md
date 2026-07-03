# SCCI Launcher

> Migração do launcher SCCI (daemon **Pascal**/oserver) para uma **plataforma Java hexagonal** —
> _Strangler Fig_, sem parar produção.

![Java](https://img.shields.io/badge/Java-21-e11f27)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.3.4-6db33f)
![Build](https://img.shields.io/badge/build-Maven-c71a36)
![Arquitetura](https://img.shields.io/badge/arquitetura-Hexagonal%20%2B%20DDD-0f7e8a)
![Migração](https://img.shields.io/badge/migra%C3%A7%C3%A3o-Strangler%20Fig-2c7a4b)

O launcher legado está sendo transformado numa plataforma modular: uma **borda fina** (edge) em Java
na frente, os **domínios em Java** num monólito modular, e o que **ainda é Pascal** isolado atrás de um
serviço próprio. Cada peça é trocável por **feature-flag**, com _fallback_ — dá para migrar um método
de cada vez sem interromper o serviço, preservando o contrato do front (`/aejs-l`) byte-a-byte.

---

## Arquitetura

```mermaid
flowchart LR
  Front["Front / SPA"] -->|W_COP| Kong
  Kong --> L["launcher :8083<br/>edge — Java puro"]
  L -->|"REST /interno"| C["scci-core :8090<br/>domínios Java (DDD)"]
  L -->|"REST /interno"| P["pascal-executor :8091<br/>ponte oserver/JNA"]
  C --> DB[("bancos por cliente<br/>PG · Oracle · Firebird · MSSQL")]
  P --> PAS[["programas Pascal<br/>wdoc · wtela · ..."]]
  L -. "Redis compartilhado" .-> R[("Redis<br/>sessão")]
  C -. Redis .-> R
```

O front fala **só** com o `launcher`. Ele não contém regra de negócio: transporta o protocolo **W_COP**,
decide por _feature-flag_ quem atende cada chamada e delega — para o `scci-core` (domínios já em Java)
ou para o `pascal-executor` (o que ainda é Pascal). Os dois backends são **internos** (não expostos ao
front). `launcher` e `scci-core` são _stateless_ (estado no Redis + bancos) → escalam em N réplicas.

---

## Módulos

```
scci-launcher/
├── common/            libs técnicas compartilhadas (in-process, usadas pelos apps)
│   ├── crypto             W_COP — AES no request, XOR na resposta
│   ├── environment        leitor do launcherenv.ini + JDBC multi-banco
│   └── contract           contratos compartilhados
│
├── launcher/          a BORDA (edge / gateway) — Java puro, sem código nativo
│   ├── domain             modelos + portas
│   ├── application        gate de sessão + roteadores Strangler
│   ├── adapters-in        controllers /w/*, /sccidoc
│   ├── adapters-out       clientes REST (scci-core, pascal-executor), Redis, SCCI_SESSION
│   └── bootstrap          Spring Boot main + wiring (:8083)
│
├── scci-core/         o MONÓLITO MODULAR (DDD) — domínios Java, escalável
│   ├── acesso             login (BANCO + família B), senha, recuperação, valida
│   ├── sessao             ciclo de vida da sessão (Redis + SCCI_SESSION)
│   ├── documentos         ver / baixar / enviar (FileSystem + BLOB)
│   ├── notificacao        e-mail / SMTP (reaproveitável)
│   ├── kernel             infra JDBC multi-banco + drivers
│   └── bootstrap          Spring Boot main + wiring (:8090)
│
└── pascal-executor/   a ÂNCORA LEGADA — ponte oserver/JNA (único módulo nativo)
                        socketpair + posix_spawn no fd 6 → spawna os "w" Pascal (:8091)
```

Cada contexto do `scci-core` tem sua **hexagonal interna** (`domain` / `application` / `adapters/in` /
`adapters/out`). No `launcher`, a hexagonal é **por módulo Maven** — a fronteira é imposta pelo build.
Regra DDD: um contexto só referencia a **porta** do outro, nunca a entidade.

---

## Stack

| Camada | Tecnologia |
| --- | --- |
| Linguagem | **Java 21** |
| Framework | **Spring Boot 3.3.4** (Web, Actuator, Data Redis, Mail) |
| Build | **Maven** (monorepo multi-módulo) |
| Arquitetura | **Hexagonal** (Ports & Adapters) · **DDD** · **Strangler Fig** |
| Persistência | JDBC **multi-banco** — Postgres, Oracle, Firebird, MSSQL (por `DRIVERNAME`) |
| Sessão / cache | **Redis** (compartilhado entre launcher e scci-core) |
| Cripto | **W_COP** — AES-128 no request, XOR/ISO-8859-1 na resposta; senha bcrypt + md5crypt |
| Relatórios | **JasperReports** (lib Java) · imagem→PDF (openpdf) |
| Legado | **Pascal** via oserver (JNA: `socketpair` + `posix_spawn`) |
| Observabilidade | logs **JSON estruturado** (logstash) · **OTLP** (métricas/traces) |

---

## Como rodar

Pré-requisitos: **JDK 21** e **Maven**.

```bash
# build de tudo (a partir da raiz)
mvn clean package

# subir cada serviço (portas padrão)
java -jar scci-core/bootstrap/target/scci-core.jar          # :8090  (interno)
java -jar pascal-executor/target/pascal-executor.jar        # :8091  (interno, co-localizado com o Pascal)
java -jar launcher/bootstrap/target/launcher.jar            # :8083  (edge)
```

Health de cada serviço em `http://localhost:<porta>/actuator/health`.
Os scripts de deploy (empacotamento com JDK embutido + envio por SSH) estão em [`deploy/`](deploy/).

### Portas

| Serviço | Porta | Exposto ao front |
| --- | --- | --- |
| `launcher` | **8083** | sim (atrás do Kong) |
| `scci-core` | **8090** | não (REST interno) |
| `pascal-executor` | **8091** | não (REST interno) |

---

## Feature flags (Strangler)

Cada canal do `launcher` é um **decorator** (roteador) que, por flag, escolhe o caminho **JAVA**
(`scci-core`) ou o **legado** (Pascal). Sem entrada = comportamento antigo; com o backend fora, cai no
_fallback_. As flags vivem no mapa `launcher.roteamento.flags` (chave com ponto usa notação de colchetes):

```yaml
launcher:
  roteamento:
    flags:
      "[documentos.GetDocumento]": { habilitado: true }   # download por ID -> scci-core
      "[acesso.Login]":            { habilitado: true }   # /w/login       -> scci-core
```

A flag carrega um campo `percentual`, então a evolução natural é **canary / rollout gradual**
(10% → 50% → 100%) ou decisão **por ambiente/cliente** — mudando só o roteador.

---

## Status da migração

| Já em Java (scci-core) | Ainda Pascal (via pascal-executor) |
| --- | --- |
| **documentos** — download (FileSystem + BLOB) e upload | demais métodos do wdoc/wtela/... |
| **acesso** — login BANCO + família B (7 clientes), senha, valida | relatórios e fluxos que ainda batem no oserver |
| **sessao** — Redis + SCCI_SESSION | |
| **notificacao** — e-mail/SMTP | |
| **execução** — externalizada; launcher virou **Java puro** | _ao fim: desligar o pascal-executor_ |

---

## Invariantes de segurança

- **Login = somente leitura** no banco do cliente (sem rehash md5crypt→bcrypt).
- **W_COP fica na borda**; a comunicação interna trafega texto na rede confiável.
- **Produção intocada** — toda a migração corre no trilho paralelo `/aejs-l`.
- **Redis: contrato idêntico** de chave/serialização entre launcher (gate) e scci-core (ciclo de vida).
- **Ir ao ar por cliente** exige o endpoint/credenciais **daquele** cliente; escrita só em ambiente nomeado.

---

<sub>Plataforma SCCI · `common` · `launcher` · `scci-core` · `pascal-executor` — arquitetura hexagonal, Strangler Fig.</sub>
