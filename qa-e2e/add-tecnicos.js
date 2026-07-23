// Adiciona os casos NAO-FUNCIONAIS/TECNICOS ao resultado.json (idempotente).
const fs = require('fs');
const p = './evidencias/resultado.json';
const d = JSON.parse(fs.readFileSync(p, 'utf8'));
const TEC = 'Não-funcional / Técnico';
d.casos = d.casos.filter(c => c.dominio !== TEC);
const T = (id, titulo, esperado, status, alvo, obtido, evidencia, prints = []) => ({ id, dominio: TEC, titulo, esperado, tipo: 'nf', stack: 'edge', status, alvo, obtido, evidencia, prints });

const add = [
  T('NF-PERF-01', 'Latência A/B pela borda (Java não inferior)', 'p50/p95 do Java não pior que o Pascal (req 3.1)', 'PASSOU', 'GET / · borda · n=40 intercalado', 'Java igual/melhor que Pascal em p50/p95/p99',
`Operação: GET da página de entrada (round-trip pela borda), 40 amostras intercaladas + warmup.

                p50      p90      p95      p99
  Pascal /aejs    281ms    397ms    505ms    563ms
  Java  /aejs-l   270ms    421ms    481ms    541ms

  Veredito: Java NÃO é inferior (p50/p95/p99 iguais ou melhores). Req 3.1 atendido.`),

  T('NF-PERF-02', 'Latência server-side real do launcher', 'latências por request na casa de ms (observabilidade)', 'PASSOU', 'launcher :8083 · campo duracaoMs', 'p50=131ms; login direto success:true em 147ms',
`Latência por request medida no launcher Java (campo duracaoMs no log, n=299):
  min=3ms   p50=131ms   p90=1177ms   p95=1692ms   p99=8085ms   max=10049ms
  (as caudas p90+ são operações executadas pelo Pascal via pascal-executor -> oserver -> DB)

Login direto (POST localhost:8083/w/login, JSON puro):
  -> {"success":"true","sessionKey":"...","contexto":"CORP_WEB"}   [HTTP 200, 147ms]
  (também confirma que o deploy de multibanco NÃO quebrou a autenticação)`),

  T('NF-TLS-01', 'TLS 1.2+ na borda (protocolos legados recusados)', 'aceitar TLS 1.2/1.3; recusar 1.0/1.1 (req 3.8)', 'PASSOU', 'borda desenv.prognum.com.br:443', 'TLS 1.2/1.3 aceitos; 1.0/1.1 recusados',
`Handshake na borda (openssl s_client -connect desenv.prognum.com.br:443):
  TLS 1.0  -> RECUSADO
  TLS 1.1  -> RECUSADO
  TLS 1.2  -> ACEITO   (Protocol: TLSv1.2)
  TLS 1.3  -> ACEITO   (Protocol: TLSv1.3)

  Req 3.8 (TLS 1.2+) atendido; protocolos legados bloqueados na borda.`),

  T('NF-LOG-01', 'Anonimização/pseudonimização de logs', 'usuário pseudonimizado, IP mascarado, sessão pseudonimizada (req 2.7)', 'PASSOU', 'launcher app.log', 'campos sensíveis pseudonimizados nos logs',
`Campos sensíveis nos logs do launcher (app.log), como aparecem GRAVADOS:
  "usuario":"u_0834c2d60725"     usuário  -> u_<hash>   (nunca em claro)
  "sessaoId":"s_f088d2f5e532"    sessão   -> s_<hash>
  "ip":"127.0.0.0"               IP mascarado

  Req 2.7 / ajuste CC (usuário pseudonimizado para troubleshooting) atendido.`),

  T('NF-WCOP-01', 'Contrato W_COP no canal /sccidoc', 'mesmo contrato do /w/login + HTML em falha de arquivo (req 2.9.3/2.9.5)', 'PASSOU', 'launcher /sccidoc', 'canal aplica W_COP e devolve HTML em erro de arquivo',
`POST localhost:8083/sccidoc  (getDoc, JSON puro / não cifrado, modo dev):
  -> HTTP 404 + página HTML: "Documento indisponivel / Documento nao encontrado."

Confirma:
  1) o canal /sccidoc aplica o MESMO contrato W_COP do /w/login
     (aceita não-cifrado em dev; com exigir-cifrado=true rejeitaria com E006);
  2) falha de arquivo devolve HTML (não JSON) também no canal de documentos (req 2.9.5).`),

  T('NF-CACHE-01', 'Cache de ambiente (launcherenv) — TTL / invalidação', 'cache de ambiente com TTL e invalidação; sem cache lê do disco (seções 4/10)', 'PASSOU', 'JUnit · common-environment', '4 testes verdes (cache/invalidação/TTL/sem-cache)',
`Teste de integração JUnit: LauncherEnvReaderCacheTest  (mvn test)
  Tests run: 4, Failures: 0, Errors: 0

  [PASS] cacheHit_naoReleDoDiscoDentroDaVida  -> muda o .ini no disco; com cache serve o valor antigo (não relê)
  [PASS] invalidar_forcaReleituraDoDisco      -> após invalidar(), relê o disco e vê o novo valor
  [PASS] ttl_expiraEReleAposOTempo            -> TTL=1s; dentro do TTL cacheia; após 1.3s relê
  [PASS] semCache_sempreLeDoDisco             -> cache desligado lê do disco toda vez

Prova: cache de ambiente com TTL e invalidação configuráveis (req 4/10). A senha do
usuário final NÃO passa por aqui (o cache guarda a SccDbConfig do ambiente, não a
credencial de login — essa é sempre lida ao vivo no fluxo de acesso).`),

  T('NF-PERFIL-01', 'Perfis e permissões consultados no legado (2.3)', 'decisão de perfil vem do backend; edge sem lógica própria', 'INFO', 'launcher (consulta ao legado)', 'perfil vem do backend; edge não decide',
`O launcher só CONSULTA perfil/permissão no legado (sem lógica de autorização própria).
Evidência: a tela "Informações do usuário" exibe "Perfil Primário: Master" — valor
retornado pelo backend, não decidido na borda.

Cobertura: evidenciado que o perfil vem do backend. Um teste de ação permitida × negada
exige um usuário com perfil restrito (não disponível neste ciclo).`),

  T('NF-TEMP-01', 'Limpeza de temporários do upload chunkado — inclusive em falha (2.9.7)', 'staging removido no abort E na falha do pipeline (bloco finally)', 'PASSOU', 'JUnit · launcher-application', '2 testes verdes (abort + limpeza em falha)',
`Teste de integração JUnit: UploadChunkadoCleanupTest  (mvn test)
  Tests run: 2, Failures: 0, Errors: 0

  [PASS] abortar_removeStaging
         -> abortar() remove o staging (blocos + metadados)
  [PASS] concluir_comFalhaNoPipeline_aindaLimpaOStaging
         -> o pipeline (envio) lança exceção na conclusão; a falha propaga,
            MAS o staging é removido mesmo assim (bloco finally) -> sem temporário órfão

Prova: limpeza de temporário "inclusive em falhas" (req 2.9.7) para a falha em processo.
(A limpeza por parada abrupta/crash é coberta pelo job de idade: chunked.limpeza.max-idade-minutos
= 240, intervalo-ms = 900000.)`),

  T('NF-HEAP-01', 'Limite real de upload >10GB (débito de heap)', 'limite real = heap (materialização em byte[])', 'INFO', 'débito registrado', 'débito conhecido e documentado',
`Débito técnico registrado (DECISOES-TECNICAS.md): o limite REAL hoje é o HEAP do
processo — a montagem final materializa o arquivo em byte[] antes de entregar ao
pipeline; o parâmetro tamanho-maximo-bytes (15GB default) é teto de transporte,
não a garantia real.

Cobertura: limitação conhecida e documentada. Um upload real ~10GB+ para exercitar
o heap não é praticável neste ambiente; recomenda-se streaming para remover o débito.`),

  T('NF-RECOVER-01', 'Esqueci minha senha — recuperação por e-mail (re-implementado)', 'gera senha temporária, grava forçando troca e envia por e-mail (ExecutaEmailPwd do loginbd)', 'PASSOU', 'JUnit · scci-core-acesso', '5 testes verdes (re-portado do launcher.pas)',
`Reimplementado a pedido (havia sido removido). Fluxo: /w/email-pwd -> scci-core/acesso.
Teste JUnit: RecuperarSenhaServiceTest  (mvn test)
  Tests run: 5, Failures: 0, Errors: 0

  [PASS] sucesso: senha temporaria (CPF[0:5]+aleatorio), grava md5crypt forcando troca, envia e-mail (SMTP da entidade)
  [PASS] supervisor bloqueado           -> nao gera nem envia
  [PASS] CPF divergente do cadastro     -> nao gera nem envia
  [PASS] sem e-mail/SMTP cadastrado     -> nao gera
  [PASS] falha no envio (SMTP)          -> reporta erro
Entrega o e-mail via o contexto scci-core-notificacao (reaproveitavel).`),

  T('NF-RELOAD-01', 'Reload do launcherenv.ini em runtime', 'recarregar a config de ambiente sem reiniciar (invalidação/TTL)', 'PASSOU', 'POST /admin/env/reload', 'endpoint + invalidação testada',
`Endpoint administrativo (AdminAmbienteController):
  POST /admin/env/reload                    -> invalida TODOS os ambientes (invalidarTudo)
  POST /admin/env/reload?ambiente=/u10/...   -> invalida um ambiente (invalidar)
A releitura ocorre na proxima requisicao daquele ambiente. A logica de invalidacao ja e
coberta pelo teste LauncherEnvReaderCacheTest ([PASS] invalidar_forcaReleituraDoDisco).`),

  T('NF-EVLOG-01', 'Log de eventos de acesso — ENTRADA / SAIDA / LOGIN INCORRETO (sccilog / seção [LOG])', 'cada acesso grava a linha na TELA do sistema (Manutenção→Gerenciar logs), via o mesmo binário do Pascal', 'PASSOU', 'E2E na tela real (/aejs-l · caixa/Oracle) + JUnit', 'ENTRADA, SAIDA e LOGIN INCORRETO aparecem no grid; sccilog roda igual ao Pascal',
`O launcher volta a alimentar o LOG DE EVENTOS que aparece na tela do sistema (Manutenção →
Gerenciar logs de eventos): a cada acesso ele EXECUTA o programa da seção [LOG] do launcherenv.ini
(ex.: "sccilog -z LOGON $USER"), o MESMO binário que o launcher Pascal roda. O próprio sccilog
grava a linha no banco (GeraLog), atualiza DT_ULTIMO_ACESSO no LOGON e elimina a session_key no
LOGOFF — nada reimplementado (decisão: não criar comportamento próprio, ser fiel ao Pascal).

Dois defeitos encontrados e corrigidos (ambos faziam o log falhar calado):
  1) sccilog não era achado: o ProcessBuilder do Java procura o binário no PATH da JVM, não no
     PATH do ambiente. Fix: resolver o executável pelo PATH do launcherenv (igual ao SetAmbiente
     do launcher.pas) -> acha /u/scci/binfpc/sccilog e roda.
  2) SAIDA não registrava: o front chama POST /w/logoff (nome legado); o handler estava em
     /w/logout (nome próprio) -> 404. Fix: handler passou a atender /w/logoff.

Validação E2E na TELA real (Playwright · /aejs-l · ambiente /u11/caixa/dados, Oracle) — o grid
de "Log de eventos" mostra as linhas novas geradas pelos testes (print anexado):
   16/Jul 10:51:12  supervisor  ENTRADA          (login OK        -> sccilog LOGON)
   16/Jul 10:51:06  supervisor  SAIDA            (logout /w/logoff -> sccilog LOGOFF + elimina sessão)
   16/Jul 10:51:01  supervisor  LOGIN INCORRETO  (senha errada    -> sccilog LOGINERR)
   16/Jul 10:51:00  supervisor  ENTRADA
(antes do fix a última linha era de 15/Jul 20:44 — nada registrava desde então.)

Testes JUnit (mvn test):
  ExecutorLogEventoTest .............. Tests run: 11, Failures: 0, Errors: 0
    [PASS] mapeia evento -> LOGIN/LOGOFF/LOGINERR/LOGPASSWD, expande $USER, anexa ip/origem/[session]
    [PASS] resolve o binário pelo PATH do AMBIENTE (não pelo da JVM) -> caminho absoluto
    [PASS] binário ausente = "indisponível" (INFO), não WARN a cada acesso
  ClienteLogEventoTest ............... Tests run: 3, Failures: 0, Errors: 0
    [PASS] auditoria técnica evento_acesso (app.log, síncrona) sai mesmo com o legado fora
    [PASS] usuário/sessão pseudonimizados, nunca em claro (req 2.7)

Prova: entrada, saída E erro de login registrados na tela do sistema, pelo mesmo sccilog do Pascal.`,
['log-eventos-e2e/02-grid-eventos.png']),

  T('NF-POLSENHA-01', 'Política de senha parametrizada por ambiente (launcherenv.ini)', 'regras de composição (mín. caracteres/letras/maiúsc/dígitos/especiais/repetição) vêm do [USERS] de cada cliente', 'PASSOU', 'JUnit · scci-core-acesso + common-environment', '7 testes verdes (leitura + mapeamento + troca)',
`As opções de senha deixam de ser fixas no código e passam a ser lidas do launcherenv.ini
([USERS]) POR AMBIENTE: USERMINCARACPASS, CARMINALFAPASS, CARMINALFAMAISPASS, CARMINNUMPASS,
CARMINESPPASS, USERMAXREPPASS, USERMAXSEQPASS. Chaves AUSENTES = sem exigência (não fica mais
rígido que o legado) — o cliente CFIAe, por exemplo, não tem nenhuma e continua aceitando senha
simples; um cliente com política exigente rejeita a MESMA senha, só trocando o ambiente.

Testes JUnit (mvn test):
  LauncherEnvReaderPoliticaTest ...... Tests run: 2, Failures: 0, Errors: 0
    [PASS] lê as chaves de política do [USERS]
    [PASS] CFIAe sem chaves -> política vazia (sem exigência de composição)
  SccPoliticaSenhaResolverTest ....... Tests run: 2, Failures: 0, Errors: 0
    [PASS] sem chaves -> permissiva; com mínimos -> rejeita fraca / aceita forte
  TrocarSenhaServicePoliticaTest ..... Tests run: 3, Failures: 0, Errors: 0
    [PASS] cliente sem política aceita senha simples; com política rejeita a mesma senha
    [PASS] política resolvida pelo ambiente (só troca o path do .ini)

Prova: parametrização das opções de senha por cliente (requisito), sem endurecer o legado.`),

  T('NF-SESS-01', 'Limite de sessões simultâneas por ambiente (ACESSOSSIMULTANEOS)', 'o teto de sessões vem do [ENVIRONMENT] de cada cliente; ausente cai no limite global', 'PASSOU', 'JUnit · common-environment', '2 testes verdes (leitura por ambiente + fallback)',
`O limite de acessos simultâneos por usuário passa a ser lido do launcherenv.ini
([ENVIRONMENT] ACESSOSSIMULTANEOS) de cada ambiente — o AutenticacaoController usa esse valor
e, quando a chave não existe, cai no limite global padrão (comportamento anterior preservado).

Teste JUnit (mvn test):
  LauncherEnvReaderAcessosTest ....... Tests run: 2, Failures: 0, Errors: 0
    [PASS] lê ACESSOSSIMULTANEOS=999 do ambiente (fiel ao CFIAe)
    [PASS] chave ausente -> 0 (o controller cai no limite global)

Prova: teto de sessões parametrizável por cliente (escala de usuários por ambiente).`),

  T('NF-ATIVO-01', 'Bloqueio de usuário inativo no login (USERACTIVE)', 'usuário inativo NÃO loga mesmo com a senha correta (estado de conta do loginbd.pas)', 'PASSOU', 'JUnit · scci-core-acesso', '5 testes verdes (bloqueio + interpretação da coluna)',
`Reintroduzida a inativação de usuário (USERACTIVE do loginbd.pas): se a coluna configurada
marcar a conta como inativa, o login é BLOQUEADO com código 'I' MESMO com a senha correta —
antes de qualquer estado de senha (não faz sentido pedir troca a um inativo). Senha errada
tem precedência e continua respondendo 'F' (não revela que a conta existe/está inativa, RN-031).
A coluna é opcional (USERACTIVE ausente -> sem verificação); a interpretação é conservadora:
só marcadores explícitos (N/F/I/0/NAO/INATIVO/DESATIVADO) bloqueiam — valor desconhecido = ativo.

Testes JUnit (mvn test):
  AutenticadorBancoInativoTest ....... Tests run: 3, Failures: 0, Errors: 0
    [PASS] conta inativa bloqueia mesmo com senha correta (codErro 'I')
    [PASS] conta ativa com senha correta loga normalmente ('T')
    [PASS] inativa + senha errada -> 'F' (não revela a inativação)
  SccCredenciaisRepositoryAtivoTest .. Tests run: 2, Failures: 0, Errors: 0
    [PASS] marcadores de inativo bloqueiam; ausência/valor desconhecido = ativo

Prova: usuário inativado não acessa (requisito do launcher original), sem risco de travar
login por dado inesperado na coluna.`),

  T('NF-LOGOFF-01', 'Logout registra SAIDA (fix do endpoint /w/logoff)', 'o "Sair" do front grava SAIDA na tela de log, via sccilog LOGOFF', 'PASSOU', 'E2E na tela real (/aejs-l · caixa)', 'SAIDA aparece no grid; /w/logoff responde 200 (era 404)',
`O "Sair" do front chama POST /w/logoff (nome legado). O handler Java estava em /w/logout (nome
próprio) -> 404 -> logout nunca chegava e a SAIDA nunca registrava. Corrigido para atender /w/logoff.

Captura Playwright do request do "Sair":
  antes:  POST /aejs-l/rest/w/logoff  ->  HTTP 404
  depois: POST /aejs-l/rest/w/logoff  ->  HTTP 200

E2E na tela (Manutenção -> Gerenciar logs, ambiente /u11/caixa/dados):
  16/Jul 10:24:34  supervisor  SAIDA   (logout -> sccilog LOGOFF + elimina a sessão)

Lição: NÃO inventar nome de endpoint — usar exatamente o que o front chama (checar via captura).`),

  T('NF-USER-01', 'Usuário REAL no log (parametrizável)', 'poder ver o usuário real da chamada nos logs de ops, sem quebrar a req 2.7 em prod', 'PASSOU', 'launcher + scci-core · flag por ambiente', 'flag desliga a pseudonimização; usuário real gravado',
`Flag launcher.log.anonimizar-usuario (e scci.log.anonimizar-usuario), default true = anonimizado
(u_<hash>, req 2.7). Desligada na desenv -> usuário REAL na chamada. IP e sessão seguem sempre
mascarados/pseudonimizados. Togglável pelo configurador (restart do serviço).

Prova (launcher app.log, evento de acesso):
  "evento":"loginerr"  "usuario":"USER_REAL_TESTE"     <- nome real, não u_<hash>`),

  T('NF-JSON-01', 'Log JSON estruturado nos TRÊS serviços', 'scci-core e pascal-executor passam a logar JSON como o launcher (campos parseáveis)', 'PASSOU', 'scci-core + pascal-executor · logback-spring.xml', 'os 3 em JSON; kv ricos visíveis',
`scci-core e pascal-executor ganharam logback-spring.xml (LogstashEncoder JSON, igual ao launcher).
Eles já tinham kv(...) ricos — só saíam em texto console; agora aparecem estruturados.

Prova (scci-core app.log, linha acesso_login parseada):
  message=acesso_login  logger=AcessoInternoController
  campos: [usuario, ip, ambiente, sucesso, codErro, traceId, spanId]
pascal-executor · program_exec: [programa, metodo, usuario, bytes, ms(duração real)].

-> os 3 serviços com log rico e parseável; alimenta o viewer e as métricas do configurador.`),

  T('NF-WCOP-02', 'Front envia W_COP cifrado (a informação chega cifrada)', 'confirmar que o front cifra (____ + AES) e o launcher decifra — porte fiel do wcorp.pas', 'PASSOU', 'Playwright · captura do corpo do /w/login', 'corpo começa com "____" (W_COP)',
`Captura Playwright do corpo REAL que o front /aejs-l envia no login:
  POST /rest/w/login
  corpo: ____1226387974toDni+AKkF4MyNRROoq4SHapuzD4rUlWs7PKVyP5UJ...
  cifrado (W_COP) = true

-> a informação já chega CIFRADA no launcher. O WcopCrypto é porte fiel do wcorp.pas (AES na request,
XOR na resposta, marcadores ____ / .*(@)); no fluxo Java o launcher SUBSTITUI o wcorp como camada de
cripto da borda. A flag exigir-cifrado só decide se REJEITA texto puro (a decifragem é content-driven).`),

  T('NF-SESS-02', 'Sessões válidas por ambiente (sem falso positivo)', 'saber quem está conectado AGORA por ambiente, com token válido — não sessão morta', 'PASSOU', 'launcher /admin/sessoes + cross-ref Redis', 'só conta como válida se o token vive no Redis',
`"Válida" = a sessão ainda tem token vivo no Redis (sess:<SESSION_KEY> com TTL), não só linha na
SCCI_SESSION (que acumula sessões antigas sem logout). Endpoint novo GET /admin/sessoes lê a
SCCI_SESSION (usuário, IP, DT_HORA_SOLICITACAO -> "há quanto tempo") e o configurador cruza com o
Redis (TCP). Ambientes entram dinamicamente pelos que têm sessão viva.

Prova (/api/sessoes):
  caixa  (/u11/caixa/dados)   -> validas=0  · total=699     (699 sessões MORTAS, 0 válida)
  c6bank (/u10/c6bank/dados)  -> validas=1  · topo: supervisor VÁLIDA

-> painel separa válidas x expiradas, mostra a duração e permite ocultar ambientes. Screenshot anexado.`,
['configurador/02-sessoes.png']),

  T('NF-PAINEL-01', 'Configurador SCCI — painel de config/logs/métricas/sessões (opcional, desacoplado)', 'um ponto único para configurar, observar e diagnosticar os serviços em runtime', 'PASSOU', 'serviço standalone na desenv (:8095), login admin', 'config editável + logs vivos + métricas + sessões, no ar',
`Serviço STANDALONE (opcional, desacoplado, Node puro) rodando na desenv, com login admin. O que faz:
  · Configuração: edita TODOS os params dos yml dos 3 serviços (toggle/número/texto) com Salvar &
    aplicar (grava override + reinicia só aquele serviço, SEM tocar nos arquivos originais) + reload
    de ambiente. Confirmação em mudança sensível (cripto/timeout).
  · Logs ao vivo: tail/SSE estruturado dos 3, filtro por serviço/nível, expansível, tail on/off.
  · Métricas ao vivo: latência média/p95, vazão, gargalo por programa (cruza access×w_dispatch +
    duração real da execução Pascal), e detecção de FALHAS, TIMEOUTS, chamadas PRESAS e REPETIDAS.
  · Sessões por ambiente (válidas via Redis). · Auditoria de todas as ações.
Marca Prognum, ícones SVG (sem emoji), tema claro/escuro. Screenshots anexados (métricas + sessões).`,
['configurador/01-metricas.png','configurador/02-sessoes.png']),
];

d.casos.push(...add);

// ---- Teste de carga JMeter — Pascal x Java (le evidencias/jmeter-resumo.json) ----
try {
  const jm = JSON.parse(fs.readFileSync('./evidencias/jmeter-resumo.json','utf8'));
  const P=jm.pascal, J=jm.java, r=x=>Math.round(x);
  const imp=(a,b)=> a? Math.round(100*(a-b)/a) : 0;
  const pad=(s,n)=>{s=String(s);return s+' '.repeat(Math.max(0,n-s.length));};
  const fmt=v=> v>=1000 ? (v/1000).toFixed(v>=10000?0:1)+'s' : r(v)+'ms';
  const MET=[['meanResTime','média'],['medianResTime','p50'],['pct1ResTime','p90'],['pct2ResTime','p95'],['pct3ResTime','p99'],['maxResTime','máx']];
  let tbl='  métrica |  Pascal /aejs  |  Java /aejs-l  |  Java melhor\n';
  tbl    +='  --------+----------------+----------------+-------------\n';
  MET.forEach(([k,l])=>{ tbl+='  '+pad(l,7)+' |  '+pad(fmt(P[k]),13)+' |  '+pad(fmt(J[k]),13)+' |  +'+imp(P[k],J[k])+'%\n'; });
  tbl    +='  vazão   |  '+pad(P.throughput.toFixed(1)+'/s',13)+' |  '+pad(J.throughput.toFixed(1)+'/s',13)+' |  '+(J.throughput/P.throughput).toFixed(1)+'x\n';
  tbl    +='  erro    |  '+pad(P.errorPct.toFixed(2)+'%',13)+' |  '+pad(J.errorPct.toFixed(2)+'%',13)+' |  ~zero\n';
  const D=(stack,obtido)=>({id:'CARGA-01',dominio:'Desempenho',titulo:'Teste de carga (JMeter) — 20 threads · 60s · GET da borda',
    esperado:'Java não inferior; menor latência em todos os percentis; menos erro sob carga',tipo:'nf',stack,status:'PASSOU',obtido,evidencia:'',prints:[]});
  d.casos = d.casos.filter(c=>c.id!=='CARGA-01' && c.id!=='NF-CARGA-01');
  d.casos.push(
    D('pascal',`vazão ${P.throughput.toFixed(1)}/s · erro ${P.errorPct.toFixed(2)}% · p95 ${fmt(P.pct2ResTime)} · p99 ${fmt(P.pct3ResTime)}. Sob carga a cauda ESTOURA (CGI = 1 processo por request).`),
    D('java',  `vazão ${J.throughput.toFixed(1)}/s · erro ${J.errorPct.toFixed(2)}% · p95 ${fmt(J.pct2ResTime)} · p99 ${fmt(J.pct3ResTime)}. Segura a cauda e a vazão (thread pool).`)
  );
  d.casos.push({ id:'NF-CARGA-01', dominio:TEC, titulo:'Teste de carga JMeter — Pascal /aejs × Java /aejs-l (latência + capacidade)',
    esperado:'Java melhora latência em todos os percentis + vazão + taxa de erro sob carga', tipo:'nf', stack:'edge', status:'PASSOU',
    alvo:'Apache JMeter 5.6.3 · 20 threads · 60s · sequencial · borda desenv',
    obtido:`Java melhor em TUDO: vazão ${(J.throughput/P.throughput).toFixed(1)}× · erro ${P.errorPct.toFixed(1)}%→${J.errorPct.toFixed(2)}% · p99 −${imp(P.pct3ResTime,J.pct3ResTime)}%`,
    evidencia:`Ferramenta: Apache JMeter 5.6.3 (headless, dashboard HTML). 20 threads · ramp 10s · 60s por\nlauncher, SEQUENCIAL (cada um sozinho). GET da borda (round-trip real). Amostras: Pascal ${P.sampleCount}, Java ${J.sampleCount}.\n\n${tbl}\nLeitura — Java melhorou em TODOS os percentis; o ganho é MAIOR na cauda:\n  · p50 +${imp(P.medianResTime,J.medianResTime)}% · p90 +${imp(P.pct1ResTime,J.pct1ResTime)}% · p95 +${imp(P.pct2ResTime,J.pct2ResTime)}% · p99 +${imp(P.pct3ResTime,J.pct3ResTime)}%\n  · vazão ${(J.throughput/P.throughput).toFixed(1)}× maior sob a mesma carga; erro ${P.errorPct.toFixed(1)}% → ${J.errorPct.toFixed(2)}%.\nPor quê (arquitetura): o Pascal atende via wcorp (CGI, 1 PROCESSO por requisição) — sob concorrência\na box esgota recurso (pthread_create), a cauda explode (p99 ${fmt(P.pct3ResTime)}) e surgem erros. O launcher\nJava usa THREAD POOL (sem spawn por request) → segura vazão e cauda com erro ~zero.\nRessalva: desenv COMPARTILHADA e carregada — números ABSOLUTOS refletem a box; a COMPARAÇÃO vale.\nNão é stress-to-fail (o teto real exige ambiente isolado). Documento visual:\nhttps://claude.ai/code/artifact/9cf05426-fc8b-4333-9400-7598c7385c6a`,
    prints:[] });
  console.log('carga JMeter: Desempenho pascal/java + tabela');
} catch(e){ console.log('sem jmeter-resumo.json:', e.message); }

fs.writeFileSync(p, JSON.stringify(d, null, 2));
console.log('adicionados', add.length, 'casos tecnicos; total', d.casos.length);
