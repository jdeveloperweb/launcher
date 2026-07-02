# Evidências de Testes — Launcher Java

Suíte de testes **automatizados** que serve de **evidência** do que está implementado. Cobre a
**lógica pura e de negócio** (crypto, políticas, casos de uso, protocolo de transporte). Os
**adapters de infra** (JDBC, Redis, oserver nativo, HTTP cifrado) são validados **ao vivo** no
servidor de desenvolvimento (ver [VALIDACAO-REQUISITOS](VALIDACAO-REQUISITOS.md)).

## Resumo

```
mvn test   →   BUILD SUCCESS
Tests run: 116, Failures: 0, Errors: 0, Skipped: 0
```

| Módulo | Testes | Foco |
|---|---:|---|
| `launcher-domain` | 23 | cripto W_COP, política de senha, enum de código, parser do payload multi-cliente |
| `launcher-application` | 69 | casos de uso (login, sessão, senha, validação, documentos) + provisionamento multi-cliente |
| `launcher-adapters-out` | 20 | transporte (método, XML PMEMORY, blocos oserver, `[LE32]`), feature flags, URL multi-banco |
| `launcher-adapters-in` | 3 | helpers do canal `/sccidoc` (strip `[LE32]`, mime) |
| `launcher-bootstrap` | 1 | `contextLoads` — sobe o wiring hexagonal inteiro (inclui os 8 autenticadores) |
| **Total** | **116** | |

## Detalhe por classe (o que cada uma prova)

| Classe de teste | Nº | Prova | Requisito / regra |
|---|---:|---|---|
| `WcopCryptoTest` | 6 | decifra um **request AES real** do login; XOR round-trip + prefixo `.*(@`; acentos ISO-8859-1; `WebDeCrypt` (round-trip); modo dev | 2.1, 2.9.3, 3.4 |
| `PasswordPolicyTest` | 7 | complexidade: mín. caracteres, composição, repetição, sequência | 2.4 |
| `LoginServiceTest` | 6 | coordenador: estados **T/F/E/M**, bloqueio/captcha, delega à Strategy, preserva token da Strategy | 2.1 |
| `AutenticadorBancoTest` | 6 | Strategy BANCO (loginbd): md5crypt + estados T/F/E/M/C, sem sessão | 2.1 |
| `CodigoLoginTest` | 4 | enum `CodigoLogin` T/C/E/M/B/F/K/X (código/sucesso/descrição/de(char)) | 2.1 |
| `TrocarSenhaServiceTest` | 5 | gates: senha atual → política → rodízio `NO_SENHA1..5` → grava | 2.4 |
| `SessaoServiceTest` | 8 | **VALIDA**: registrar nos dois stores; cache hit; miss→SCCI_SESSION→reidrata; inválida→vazio; encerrar; contar | 2.2 |
| `ValidacaoAcessoServiceTest` | 4 | CPF/protocolo (vazio=válido; delega ao repositório) | 2.1 (building block) |
| `RecuperarSenhaServiceTest` | 7 | bloqueio supervisor/CPF 111; CPF confere; exige e-mail/SMTP; gera+grava+envia; falha de envio | 2.5 |
| `DespachoServiceTest` | 1 | `/w` delega ao executor do programa real | 2.3 |
| `DocumentoServiceTest` | 4 | download: parse `[LE32][XML metadados][binário]` → arquivo; erro→JSON; JSON de passagem | 2.9.2, 2.9.4 |
| `EnvioDocumentoServiceTest` | 2 | upload: 1 execução por arquivo, coleta as respostas | 2.9.2 |
| `ProgramExecutorTest` | 13 | **`montaMetodo`** (verbo só se HTTP — os bugs corrigidos), **XML PMEMORY** (inclui `dados:{}`→`<dados></dados>`), **`parseBlocos`** (DATA vence EXCEPT), **`[LE32]`** | 5 (execução), 2.9 |
| `SccidocControllerTest` | 3 | strip do `[LE32]` na resposta de upload (o fix do "tela não atualiza"); mime por extensão | 2.9.4, 2.9.5 |
| `PayloadMapeadoTest` | 6 | parser do payload multi-cliente: XML (perfil/ip/expiresIn/token, trunca IP 30) + CommaText (`!#___`, aspas) | 2.1 (família B) |
| `ProvisaoMapeadoTest` | 26 | as 7 estratégias payload-mapeado (itau/c6/brb/cashmeweb/direto/unicred/ailos): provisiona/valida como cada `.pas`; `AutenticadorMapeado` T/F | 2.1 (família B) |
| `ConfigFeatureRegistryTest` | 2 | registro de feature flags por config (Strangler) | 3.7 |
| `JdbcConnectionFactoryTest` | 5 | URL JDBC por `DRIVERNAME` (Postgres/Oracle/MSSQL/Firebird remoto+embedded) | multi-banco |
| `LauncherApplicationTest` | 1 | `contextLoads` — todo o wiring domain-first sobe (controllers, casos de uso, adapters) | 3.8 |

## O que os testes automatizados cobrem × o que é validado ao vivo

| Camada | Cobertura automatizada | Validação ao vivo (dev) |
|---|---|---|
| Domínio (crypto, política) | ✅ unit (round-trip, vetor real) | — |
| Aplicação (casos de uso) | ✅ unit com mocks dos ports | — |
| Transporte (método, PMEMORY, blocos, LE32) | ✅ unit (bytes) | ✅ execução real de `wtela`/`wdoc` |
| Adapters JDBC (`Scc*`) | (thin; lógica testada na aplicação) | ✅ **login real** contra Postgres do ambiente |
| Adapters Redis (`Redis*`) | — | ✅ sessão/tentativas no `redis` |
| oserver nativo (`NativeOserverBridge`) | — | ✅ menu/PDF reais via socketpair |
| HTTP cifrado (controllers) | ✅ helpers puros | ✅ `/w/login`, `/w`, `/sccidoc` via Kong (200) |

> Os adapters de infra são **finos** (traduzem para os ports); a regra vive na aplicação/domínio, que
> tem cobertura unitária. A ponta a ponta (banco/Redis/oserver/HTTP) foi exercida **de verdade** no
> `/aejs-l` (evidências no VALIDACAO-REQUISITOS): login real, PDF baixado, upload `PostDocumentoOperacao`,
> `GetSetaPermissoes` refletindo o usuário, cadeia Kong→reator 200.

## Como reproduzir

```bash
# na raiz do projeto:
mvn test                       # roda os 66 testes (todos os módulos)
mvn test -pl launcher-domain   # só um módulo
```
Relatórios detalhados: `*/target/surefire-reports/`.

## Nota de testabilidade
Alguns helpers de transporte/borda (`ProgramExecutor.montaMetodo/jsonParaPmemoryXml/parseBlocos/`
`comTamanhoLE/bloco`, `SccidocController.desembrulhaTamanho/mime`) foram tornados **package-private**
(antes `private`) para o teste no mesmo pacote verificá-los — sem mudança de comportamento.
