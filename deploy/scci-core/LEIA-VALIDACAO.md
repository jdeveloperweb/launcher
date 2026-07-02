# Deploy + validação ao vivo do `scci-core` (documentos em Java)

Objetivo: **provar o download de documento rodando em Java ponta a ponta** num ambiente de teste,
convertendo o "verde em teste" em "funciona". Depois disso a gente promove os 🟡→✅ com evidência.

O `scci-core` é **interno** (porta 8090); o **launcher** o chama por REST quando a flag do módulo aponta
JAVA. Ele NÃO passa pelo Kong/Apache e NÃO é exposto ao front.

---

## ⚠️ Risco #1 — a base dos documentos (VERIFICAR ANTES)

Os documentos vivem na base **de ATIVIDADE/SCIS** (`SCCIDIRATV` — tabelas `SISTARQ`, `CONTROLEVERSAO`).
O adapter atual (`RepositorioDocumentoJdbc`) conecta via `LauncherEnvReader.ler(ambiente)`, que lê a seção
`[USERS]` do `launcherenv.ini` — que normalmente é a base de **login** (tabela `USUARIO`).

**Se a base de login e a de documentos forem a MESMA** (mesmo `DB` no launcherenv), tudo funciona direto.
**Se forem SEPARADAS**, as queries de `SISTARQ` falham e o download volta pro Pascal (fallback). Nesse caso
o ajuste é de **1 ponto**: fazer o adapter resolver a conexão de `SCCIDIRATV` (do `[ENVIRONMENT]` do
launcherenv) em vez de `[USERS]`. Me avise o resultado do teste do passo 1 que eu ajusto se preciso.

### Passo 0 — teste de schema (read-only, 2 min) — recomendado antes do deploy
No servidor, contra a base do ambiente de teste, rode um SELECT de leitura pra confirmar o schema:
```sql
SELECT c.nome, s.nome, versao, compactado, tp_gravacao
FROM controleversao c, sistarq s
WHERE s.id = <ID_DE_UM_DOC_REAL> AND c.id = s.id
ORDER BY versao DESC;
```
- Se retornar a linha do documento → schema OK, base correta. Pode seguir.
- Se der "tabela não existe" → a base do `[USERS]` **não** é a de documentos → ver Risco #1 acima.

---

## 1. Configure o alvo
Edite `deploy.conf` (HOST/USUARIO/DESTINO/SSHKEY já vêm do padrão do launcher). `DESTINO=~/scci-core`.

## 2. Build + envio (do seu Windows)
```
deploy\scci-core\enviar-pacote.bat
```
Faz: `mvn package` → `scci-core.tar.gz` (jar + JDK 21 embutido + run.sh) → `scp` → `instalar.sh` → sobe na 8090.

## 3. Confirme o scci-core no ar
```
ssh ... "curl -s http://localhost:8090/actuator/health"        # -> {"status":"UP"}
```

## 4. Aponte o launcher pro scci-core + ligue a flag
No `application.yml` do **launcher** (ou por ENV), no deploy do launcher:
```yaml
launcher:
  scci-core:
    url: http://localhost:8090          # ou SCCI_CORE_URL=http://localhost:8090
  roteamento:
    documentos.GetDocumento: { habilitado: true }   # só este método -> Java (o resto segue Pascal)
```
Reinicie o launcher. (Comece por UM método — `GetDocumento` — pra isolar.)

## 5. Valide o download em Java (a prova)
Baixe um documento **real** pelo caminho normal do front/`/sccidoc` (o mesmo `GetDocumento` por `ID`).
Evidência de que veio do Java (não do Pascal):
```
ssh ... "tail -n 30 ~/scci-core/app/app.log"     # deve logar a chamada e a query no SISTARQ
```
- Documento abre igual ao Pascal → ✅ **provado ponta a ponta.**
- Erro/volta pro Pascal → veja o `app.log` do scci-core (schema/conexão) — provável Risco #1.

## 6. Rollback (instantâneo, sem deploy)
Tire a flag (ou `habilitado: false`) e reinicie o launcher → volta 100% pro `wdoc` Pascal. Nada muda no
banco (o download é só leitura).

---

## Depois que o download passar
- Promover `GetDocumento`/`Versao`/`Operacao`/`Sisat`/`ContratoAssinatura` (ligar `documentos: {habilitado:true}`).
- Testar **upload** (`documentos.PostDocumento` — grava versão; comece num doc de teste).
- **Relatórios Jasper**: colocar os `.jrxml` (+ subreports `.jasper` + imagens) em `SCCI_DOCUMENTOS_JASPER_DIR`
  e testar `POST /interno/relatorios/{nome}/pdf`.
- Voltar pro "restante" (fetch de relatório, merge RTF/HTML, `GetEstruturaAtualizada`) — units já localizadas
  no `headGIT`.

## Notas de infra
- **Mesmo host do launcher**: os paths de `launcherenv.ini` (por ambiente) precisam ser os mesmos → rode o
  scci-core no MESMO servidor (ou monte os mesmos diretórios). Sem isso ele não acha o ambiente.
- **Banco alcançável**: o scci-core abre conexão JDBC direto (multi-banco pelo `DRIVERNAME`).
- **Sem Redis** por enquanto (o contexto `documentos` é só banco; `acesso`/`sessao` viriam depois).
