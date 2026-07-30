# Configurador SCCI

Ferramenta **standalone** (Node puro, sem dependências) para operar os serviços SCCI em um ambiente:
observar **métricas ao vivo**, o **RTT por chamada** (a viagem da requisição pelos 3 trilhos),
**sessões**, **logs** em tempo real, **configuração** (editar+aplicar por serviço) e **energia +
roteamento** (ligar/desligar cada serviço e virar as feature-flags de trilho por operação).

Roda numa porta única (**:8095**) e é servido como **um arquivo** (bundle) — fácil de distribuir.

## Arquivos

| Arquivo | O que é |
|---|---|
| `server.js` | Backend (HTTP + SSE de logs + APIs `/api/*`). Serve os assets do disco (dev) ou embutidos (bundle). |
| `index.html` | Front (SPA — abas Métricas, RTT, Serviços, Logs, Sessões, Configuração, Auditoria). |
| `bundle.js` | Empacotador: `node bundle.js` gera `configurador.bundle.js` com `index.html` + `logo.png` embutidos. |
| `instalar-configurador.sh` | Instalador idempotente de 1 comando (copia o bundle, sobe em :8095, gera admin no 1º boot). |
| `logo.png` | **FALTA no repo** — está só no ambiente (`~/configurador/logo.png`). Necessário pro bundle. Ver abaixo. |

Estado em runtime (criado no 1º boot, **não versionar**): `users.json`, `secret.key`, `overrides.json`,
`audit.jsonl`, `routing.json`, `rotas.json`.

## Rodar em dev

```bash
node server.js            # http://localhost:8095  (lê index.html/logo.png do disco)
```

## Empacotar e distribuir

```bash
node bundle.js                                   # gera configurador.bundle.js (1 arquivo, autocontido)
scp configurador.bundle.js instalar-configurador.sh destino:~/
ssh destino 'PORT=8095 ./instalar-configurador.sh ~/configurador'
```

## Pendências

- **`logo.png`**: trazer do ambiente (`scp ...:~/configurador/logo.png ./`) e commitar, senão o
  bundle sai sem logo.
- **Feature Spring Boot (H2)**: hoje o store de auth é em arquivos; a versão Spring Boot com H2 é futura.

## Notas de operação (ambiente desenv)

- Subir os JVMs **sob `ulimit -u` alto** — o `buildLaunch` do `server.js` já faz (o `nproc` soft do
  usuário costuma ser 200 e trava com vários JVMs). Ver a memória de deploy do projeto.
- **Roteamento (Strangler, 3 trilhos)** por feature-flag no gateway
  (`gateway.execucao.rotas.<programa> = puro | hibrido | pascal`); a aba **Serviços → Roteamento por
  operação** edita essas flags e reinicia só o gateway.
