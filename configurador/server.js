/* ============================================================================
 *  Configurador SCCI — serviço STANDALONE, opcional, desacoplado (Node puro).
 *  - Auth: login admin (senha gerada no 1o boot), sessão por cookie assinado,
 *          store local (users/audit/overrides). [H2 = versão Spring Boot futura]
 *  - Config: parseia TODOS os yml (jar + externo), overlay de args de runtime,
 *            editar -> salvar (override) -> aplicar (restart) -> reload de ambiente.
 *  - Logs: tail -F real -> SSE (o tail liga/desliga no front).
 *  Porta 8095. Node 10 compatível (sem ?. / ??).
 * ==========================================================================*/
'use strict';
var http=require('http'), fs=require('fs'), path=require('path'), cp=require('child_process'), url=require('url'), crypto=require('crypto'), net=require('net');
var PORT=process.env.PORT||8095, HOME=process.env.HOME||'/home/jaime.vicente', DIR=__dirname;
var OVR_FILE=path.join(DIR,'overrides.json'), USERS_FILE=path.join(DIR,'users.json'),
    AUDIT_FILE=path.join(DIR,'audit.jsonl'), SECRET_FILE=path.join(DIR,'secret.key');

function shortP(x){ return String(x==null?'':x).split(HOME).join('~'); }   // encurta o HOME nos caminhos exibidos

/* ---------------- store / auth ---------------- */
function loadJson(f,def){ try{ return JSON.parse(fs.readFileSync(f,'utf8')); }catch(e){ return def; } }
function secret(){ try{ return fs.readFileSync(SECRET_FILE); }catch(e){ var s=crypto.randomBytes(32); fs.writeFileSync(SECRET_FILE,s); return s; } }
function hashPw(pw,salt){ return crypto.pbkdf2Sync(pw,salt,120000,32,'sha256').toString('hex'); }
function seedAdmin(){
  if(fs.existsSync(USERS_FILE)) return;
  var pw=crypto.randomBytes(6).toString('hex');           // ex.: a3f9c2e18b04
  var salt=crypto.randomBytes(16).toString('hex');
  fs.writeFileSync(USERS_FILE,JSON.stringify({admin:{salt:salt,hash:hashPw(pw,salt),role:'admin'}},null,2));
  console.log('==================================================');
  console.log('  CREDENCIAIS ADMIN (1o boot) -> usuario: admin  senha: '+pw);
  console.log('==================================================');
}
function checkLogin(user,pw){ var u=loadJson(USERS_FILE,{})[user]; if(!u) return false; return hashPw(pw,u.salt)===u.hash; }
function signSession(user){ var exp=Date.now()+8*3600*1000; var payload=user+'|'+exp;
  var sig=crypto.createHmac('sha256',secret()).update(payload).digest('hex');
  return Buffer.from(payload).toString('base64')+'.'+sig; }
function verifySession(cookie){ if(!cookie) return null;
  var m=/sess=([^;]+)/.exec(cookie); if(!m) return null;
  var parts=decodeURIComponent(m[1]).split('.'); if(parts.length!==2) return null;
  var payload; try{ payload=Buffer.from(parts[0],'base64').toString('utf8'); }catch(e){ return null; }
  var sig=crypto.createHmac('sha256',secret()).update(payload).digest('hex');
  if(sig!==parts[1]) return null;
  var f=payload.split('|'); if(parseInt(f[1],10)<Date.now()) return null;
  return f[0]; }
function audit(user,action,detail){ try{ fs.appendFileSync(AUDIT_FILE,JSON.stringify({ts:new Date().toISOString(),user:user,action:action,detail:detail})+'\n'); }catch(e){} }
function readAudit(n){ try{ var l=fs.readFileSync(AUDIT_FILE,'utf8').trim().split('\n'); return l.slice(-n).reverse().map(function(x){ try{return JSON.parse(x);}catch(e){return null;} }).filter(Boolean); }catch(e){ return []; } }

/* ---------------- serviços ---------------- */
var SVC={
  gateway: {label:'gateway-scci',port:8083,jar:HOME+'/gateway-scci/app/gateway-scci.jar',ext:HOME+'/gateway-scci/app/application.yml',dir:HOME+'/gateway-scci/app',xmx:'512m',logFmt:'json',log:HOME+'/gateway-scci/app/app.log'},
  scci:    {label:'scci-core',port:8090,jar:HOME+'/scci-core/app/scci-core.jar',dir:HOME+'/scci-core/app',xmx:'768m',logFmt:'json',log:HOME+'/scci-core/app/app.log'},
  scciPuro:{label:'scci-core-puro',port:8092,jar:HOME+'/scci-core-puro/app/scci-core.jar',dir:HOME+'/scci-core-puro/app',xmx:'512m',logFmt:'json',log:HOME+'/scci-core-puro/app/app.log'},
  launcher:{label:'launcher',port:8091,jar:HOME+'/launcher/app/launcher.jar',dir:HOME+'/launcher/app',xmx:'384m',logFmt:'json',log:HOME+'/launcher/app/app.log'}
};
var ORDER=['gateway','launcher','scci','scciPuro'];
var AMBIENTES=[{nome:'caixa',path:'/u11/caixa/dados'},{nome:'c6bank',path:'/u10/c6bank/suporte/scat112934'}];
/* perfis de subida — o que cada serviço precisa de env/heap p/ subir no MODO certo (hibrido/uds etc.) */
var SHIM=HOME+'/launcher/app/oserver-shim';
var LAUNCH={
  gateway: { env:{},                                                                 xmx:'512m' }, // executor-url + rotas vêm do ROTEAMENTO
  scci:    { env:{SCCI_SDK:'true', EXECUTOR_TRANSPORTE:'uds', EXECUTOR_SHIM:SHIM},    xmx:'768m' }, // HÍBRIDO: Java + Pascal (SDK/uds)
  scciPuro:{ env:{SCCI_SDK:'false'},                                                 xmx:'512m' }, // PURO: só Java, sem SDK/Pascal
  launcher:{ env:{EXECUTOR_TRANSPORTE:'uds', EXECUTOR_SHIM:SHIM},                     xmx:'384m' }  // executor Pascal (uds)
};
var ROUTE_FILE=path.join(DIR,'routing.json');   // {executor:'hibrido'|'launcher'} — p/ onde o gateway manda a execucao Pascal
var ROTAS_FILE=path.join(DIR,'rotas.json');      // {rotaDefault, rotas:{<programa>:'puro'|'hibrido'|'pascal'}} — feature-flags de trilho
// opções dos enums (viram listbox no front, cada opção com o que ela faz)
var TRILHO_OPTS=[
  {v:'pascal', d:'não migrado → executor Pascal legado (padrão seguro)'},
  {v:'hibrido',d:'Java + Pascal via SDK, in-process no scci-core híbrido (:8090)'},
  {v:'puro',   d:'100% Java no scci-core puro (:8092), sem Pascal'}
];
var TRANSPORTE_OPTS=[
  {v:'jna',d:'ponte JNA/JNI atual (libc: socketpair + posix_spawn). Estável — mas NÃO usar com virtual threads (pinning)'},
  {v:'uds',d:'UDS+shim v2 (Java puro por Unix socket + shim em C). VT-friendly; exige o shim-path válido'}
];
var META={
  // ---- cripto / sessão ----
  'launcher.wcop.exigir-cifrado':{d:'Exige que a requisição venha CIFRADA (W_COP). Ligado: rejeita texto puro com E006 (produção). Desligado: aceita JSON puro (modo dev/teste).',danger:true},
  'launcher.legacy.wcop.contexto':{d:'Contexto do cabeçalho W_COP legado (combina com o front). Só mexer alinhado com o cliente.'},
  'launcher.sessao.ttl-segundos':{d:'Timeout de sessão OCIOSA no Redis (porte do GLOBALTIMEOUT). 0 = nunca expira.',u:'seg'},
  'launcher.log.anonimizar-usuario':{d:'Pseudonimiza o usuário nos logs (u_<hash>). Desligar mostra o usuário REAL (ops interno). IP e sessão seguem mascarados.'},
  // ---- autenticação / política de senha ----
  'launcher.auth.max-erros':{d:'Bloqueia o usuário após N logins com senha errada.',u:'tent.'},
  'launcher.auth.login-err-delay-ms':{d:'Espera imposta após erro de login (freia brute-force).',u:'ms'},
  'launcher.auth.dias-aviso-expiracao':{d:'Com quantos dias de antecedência avisar que a senha vai expirar.',u:'dias'},
  'launcher.auth.max-logins-simultaneos':{d:'Teto de sessões ativas por usuário. 0 = ilimitado.',u:'sessões'},
  'launcher.auth.captcha-habilitado':{d:'Liga o CAPTCHA no login (após erros). Desligado, nunca pede CAPTCHA.'},
  'launcher.auth.max-erros-captcha':{d:'Após N erros de senha, passa a exigir CAPTCHA no próximo login.',u:'tent.'},
  'launcher.auth.policy.requer-composicao':{d:'Liga a política de composição da senha (os mínimos abaixo). Desligado, só o tamanho vale.'},
  'launcher.auth.policy.min-caracteres':{d:'Tamanho mínimo da senha.',u:'chars'},
  'launcher.auth.policy.min-letras':{d:'Mínimo de letras na senha.',u:'letras'},
  'launcher.auth.policy.min-maiusculas':{d:'Mínimo de letras MAIÚSCULAS.',u:'maiúsc.'},
  'launcher.auth.policy.min-digitos':{d:'Mínimo de dígitos (0-9).',u:'dígitos'},
  'launcher.auth.policy.min-especiais':{d:'Mínimo de caracteres especiais (!@#…).',u:'especiais'},
  'launcher.auth.policy.max-repetidos':{d:'Máx. de caracteres iguais em sequência (ex.: "aaa"). Acima disso, rejeita.',u:'seguidos'},
  'launcher.auth.policy.max-sequenciais':{d:'Máx. de caracteres em sequência (ex.: "123", "abc"). Acima disso, rejeita.',u:'seguidos'},
  // ---- roteamento (Strangler) ----
  'gateway.execucao.rota-default':{d:'Trilho para operações SEM flag específica. Padrão pascal (legado). Editável também na aba Serviços → Roteamento.',opts:TRILHO_OPTS},
  'gateway.executor-url':{d:'URL do executor Pascal (trilho pascal): serviço launcher (:8091) OU scci-core híbrido raw (:8090). Trocado pelo switch da aba Serviços.'},
  'launcher.pascal-executor.url':{d:'URL do serviço launcher usada só para o LOG-EVENTO (sccilog). A EXECUÇÃO usa gateway.executor-url.'},
  'launcher.scci-core.url':{d:'URL do scci-core (domínios Java migrados: acesso, documentos, sessão).'},
  // ---- executor Pascal (oserver) ----
  'executor.timeout-ms':{d:'Timeout de recepção do oserver (SO_RCVTIMEO), em MILISSEGUNDOS. Aceita sub-segundo.',u:'ms',danger:true},
  'executor.max-concorrentes':{d:'Semáforo de execuções Pascal simultâneas (espelha o MAXCONN).',u:'slots'},
  'executor.max-tentativas':{d:'Máx. de tentativas (retry) — só em GET idempotente.',u:'×'},
  'executor.retry-delay-ms':{d:'Espera entre tentativas de retry.',u:'ms'},
  'executor.transporte':{d:'Como o Java fala com o Pascal (oserver, FD 6). Nenhum toca no programa Pascal.',opts:TRANSPORTE_OPTS,danger:true},
  'executor.shim-path':{d:'Caminho do binário shim (C) usado quando transporte=uds. Sem ele, o modo uds falha.'},
  'launcher.executor.max-concorrentes':{d:'Semáforo de execuções Pascal simultâneas no gateway (espelha o MAXCONN).',u:'slots'},
  'launcher.executor.max-tentativas':{d:'Máx. de tentativas (retry) — só em GET idempotente.',u:'×'},
  'launcher.executor.retry-delay-ms':{d:'Espera entre tentativas de retry.',u:'ms'},
  'launcher.executor.timeout-segundos':{d:'CONFIG MORTA (nenhum código lê). O timeout real é executor.timeout-ms no launcher/executor.',dead:true,u:'seg'},
  // ---- documentos / upload ----
  'launcher.documentos.extensoes-permitidas':{d:'Allow-list de extensões aceitas no upload (separadas por vírgula). O que não estiver aqui é recusado.'},
  'launcher.documentos.chunked.tamanho-maximo-bytes':{d:'Tamanho máx. TOTAL de um arquivo no upload em blocos.',u:'bytes'},
  'launcher.documentos.chunked.tamanho-bloco-maximo-bytes':{d:'Tamanho máx. de CADA bloco do upload chunked.',u:'bytes'},
  'launcher.documentos.chunked.staging-dir':{d:'Pasta temporária onde os blocos ficam até o upload concluir.'},
  'launcher.documentos.chunked.limpeza.intervalo-ms':{d:'De quanto em quanto tempo varre uploads incompletos p/ limpar.',u:'ms'},
  'launcher.documentos.chunked.limpeza.max-idade-minutos':{d:'Idade máx. de um upload incompleto antes de ser descartado.',u:'min'},
  // ---- ambiente / infra ----
  'common.environment.cache-habilitado':{d:'Liga o cache da config por ambiente (launcherenv.ini). A CREDENCIAL nunca é cacheada.'},
  'common.environment.cache-ttl-segundos':{d:'Expiração de cada entrada do cache de ambiente.',u:'seg'},
  'spring.data.redis.host':{d:'Host do Redis (cache de sessão).'},
  'spring.data.redis.port':{d:'Porta do Redis.'},
  'spring.data.redis.timeout':{d:'Timeout de conexão/comando com o Redis (ex.: 2s).'},
  'spring.servlet.multipart.max-file-size':{d:'Tamanho máx. de UM arquivo no upload multipart (ex.: 50MB).'},
  'spring.servlet.multipart.max-request-size':{d:'Tamanho máx. da REQUISIÇÃO inteira no upload multipart (ex.: 60MB).'},
  'spring.codec.max-in-memory-size':{d:'Buffer máx. em memória para corpo de requisição/resposta antes de ir a disco.'},
  'spring.threads.virtual.enabled':{d:'Liga Virtual Threads (Java 21). SÓ com transporte UDS — com JNA há pinning. Desligado por padrão.',danger:true},
  'scci.sdk.habilitado':{d:'Modo do scci-core: LIGADO = HÍBRIDO (embute o launcher-sdk e roda Pascal in-process). DESLIGADO = PURO (só Java). Muda no deploy (env SCCI_SDK).',danger:true},
  // scci-core: mesmas famílias do gateway, mas com prefixo scci.
  'scci.auth.max-erros':{d:'Bloqueia o usuário após N logins com senha errada.',u:'tent.'},
  'scci.auth.login-err-delay-ms':{d:'Espera imposta após erro de login (freia brute-force).',u:'ms'},
  'scci.auth.dias-aviso-expiracao':{d:'Com quantos dias de antecedência avisar que a senha vai expirar.',u:'dias'},
  'scci.auth.tentativas-ttl-segundos':{d:'Janela em que os erros de senha são contados antes de zerar o contador.',u:'seg'},
  'scci.documentos.extensoes-permitidas':{d:'Allow-list de extensões aceitas no upload (separadas por vírgula). O que não estiver aqui é recusado.'},
  'scci.log.anonimizar-usuario':{d:'Pseudonimiza o usuário nos logs (u_<hash>). Desligar mostra o usuário REAL (ops interno).'},
  'scci.sessao.ttl-segundos':{d:'Timeout de sessão OCIOSA (idle). 0 = nunca expira.',u:'seg'}
};

/* ---------------- parser YAML (subconjunto dos application.yml) ---------------- */
function stripComment(v){ return v.replace(/\s+#.*$/,'').trim(); }
function unq(s){ s=s.trim(); if((s[0]==='"'&&s.slice(-1)==='"')||(s[0]==="'"&&s.slice(-1)==="'")) return s.slice(1,-1); return s; }
function flattenYaml(text){
  var out={}, stack=[], lines=String(text).split(/\r?\n/);
  for(var i=0;i<lines.length;i++){ var raw=lines[i]; if(!raw.trim()||/^\s*#/.test(raw)) continue;
    var indent=raw.match(/^ */)[0].length, line=raw.trim(), ci=line.indexOf(':'); if(ci<0) continue;
    var key=unq(line.slice(0,ci)), val=stripComment(line.slice(ci+1));
    while(stack.length && stack[stack.length-1].indent>=indent) stack.pop();
    var full=stack.map(function(s){return s.key;}).concat(key).join('.');
    if(val===''){ stack.push({indent:indent,key:key}); continue; }
    if(/^\{.*\}$/.test(val)){ val.slice(1,-1).split(',').forEach(function(pp){ var pi=pp.indexOf(':'); if(pi<0)return; out[full+'.'+unq(pp.slice(0,pi))]=stripComment(pp.slice(pi+1)); }); }
    else out[full]=val;
  } return out;
}
function envDefault(v){ var m=/^\$\{[^:}]+:?([^}]*)\}$/.exec(String(v)); return m?{env:true,val:m[1]}:{env:false,val:v}; }
function inferType(v){ v=String(v).trim(); if(v==='true'||v==='false')return 'bool'; if(/^-?\d+$/.test(v))return 'int'; return 'string'; }
function getYmlText(svc){ try{ return cp.execSync('unzip -p "'+svc.jar+'" BOOT-INF/classes/application.yml',{encoding:'utf8',maxBuffer:2<<20}); }catch(e){ return ''; } }
function readExt(svc){ try{ return fs.readFileSync(svc.ext,'utf8'); }catch(e){ return null; } }
function liveArgs(svc){ var o={}; try{ var jar=path.basename(svc.jar);
    var out=cp.execSync("ps -eo args | grep '[" + jar[0] + "]" + jar.slice(1) + "'",{encoding:'utf8'});
    var re=/--([\w.\-\[\]]+)=(\S+)/g,m; while((m=re.exec(out))) if(m[1].indexOf('server.port')<0) o[m[1]]=m[2]; }catch(e){} return o; }
function loadOverrides(){ return loadJson(OVR_FILE,{}); }
function saveOverrides(o){ fs.writeFileSync(OVR_FILE,JSON.stringify(o,null,2)); }

function serviceConfig(svcId){
  var svc=SVC[svcId], base=flattenYaml(getYmlText(svc)), ext=svc.ext?flattenYaml(readExt(svc)||''):{}, live=liveArgs(svc), ovr=(loadOverrides()[svcId])||{};
  var keys={}; [base,ext,live,ovr].forEach(function(s){ for(var k in s) keys[k]=1; });
  return Object.keys(keys).sort().map(function(k){
    var rawJar=base[k], rawExt=ext[k], rawOvr=ovr[k], rawLive=live[k];
    var baseRaw=(rawExt!=null?rawExt:rawJar), ed=baseRaw!=null?envDefault(baseRaw):{env:false,val:''};
    var baseOrigin=rawExt!=null?'yml externo':(rawJar!=null?'yml (jar)':'runtime'); if(ed.env) baseOrigin='env var';
    var effRaw, effOrigin, pending=false;
    if(rawOvr!=null){ effRaw=rawOvr; effOrigin='override'; if(String(rawLive)!==String(rawOvr)) pending=true; }
    else if(rawLive!=null){ effRaw=rawLive; effOrigin='arg runtime'; }
    else { effRaw=ed.val; effOrigin=baseOrigin; }
    var type=inferType(effRaw!==''&&effRaw!=null?effRaw:ed.val), m=META[k]||{};
    var desc=m.d||'', opts=m.opts||null;
    if(k.indexOf('gateway.execucao.rotas.')===0){ var prog=k.slice('gateway.execucao.rotas.'.length);   // flag de trilho por programa (chave dinâmica)
      desc='Trilho do programa "'+prog+'" (Strangler). Também editável na aba Serviços → Roteamento.'; opts=TRILHO_OPTS; }
    var editable = k.indexOf('[')<0 && k.indexOf('management.')!==0 && k.indexOf('server.')!==0 && k.indexOf('spring.application')!==0 && !m.dead;
    // roteamento do gateway é gerenciado pela aba Serviços (routing.json/rotas.json) -> read-only aqui p/ não ter 2 fontes
    if(k==='gateway.executor-url'||k==='gateway.execucao.rota-default'||k.indexOf('gateway.execucao.rotas.')===0) editable=false;
    return { svc:svcId, key:k, type:(opts?'enum':type), unit:m.u||'', desc:desc, opts:opts, danger:!!m.danger, dead:!!m.dead,
      value: type==='bool'?(String(effRaw)==='true'):effRaw, baseValue:ed.val, origin:effOrigin, envVar:ed.env,
      editable:editable, requiresRestart:true, pending:pending };
  });
}
function allConfig(){ var r={}; ORDER.forEach(function(s){ r[s]=serviceConfig(s); }); return r; }

function overrideArgs(svcId){ var svc=SVC[svcId], live=liveArgs(svc), ovr=(loadOverrides()[svcId])||{}, merged={};
  for(var k in live) merged[k]=live[k]; for(var k2 in ovr) merged[k2]=ovr[k2];
  return Object.keys(merged).map(function(k){ return '--'+k+'='+merged[k]; }); }
function shArg(s){ return "'"+String(s).replace(/'/g,"'\\''")+"'"; }   // aspa simples segura p/ shell
/* p/ onde a execucao Pascal vai: 'launcher' (8091, processo dedicado) ou 'hibrido' (8090, in-process no scci-core).
   Verdade = args vivos do gateway; senao o estado salvo; default hibrido. */
function currentRoute(){ try{ var u=(liveArgs(SVC.gateway)['gateway.executor-url']||''); if(u.indexOf('8091')>=0)return 'launcher'; if(u.indexOf('8090')>=0)return 'hibrido'; }catch(e){} return (loadJson(ROUTE_FILE,{}).executor)||'hibrido'; }
/* monta o comando de subida de um serviço no modo certo (env + ulimit + heap + roteamento + overrides do usuario) */
function buildLaunch(svcId){ var svc=SVC[svcId], L=LAUNCH[svcId]||{env:{},xmx:svc.xmx};
  var extra=[];
  if(svcId==='gateway'){ var route=(loadJson(ROUTE_FILE,{}).executor)||currentRoute();   // DESEJADO (arquivo) vence os args vivos do gateway velho
    extra.push('--gateway.executor-url=http://localhost:'+(route==='launcher'?8091:8090));
    var rf=loadJson(ROTAS_FILE,{});   // feature-flags de trilho (arquivo = fonte da verdade; permite ADD e REMOVE)
    if(rf.rotaDefault) extra.push('--gateway.execucao.rota-default='+rf.rotaDefault);
    var rr=rf.rotas||{}; for(var pg in rr) extra.push('--gateway.execucao.rotas.'+pg+'='+rr[pg]); }
  // overrides/args vivos do usuario, MENOS o que a gente gerencia por ARQUIVO (executor-url + rotas de execucao)
  var ovr=overrideArgs(svcId).filter(function(a){ return a.indexOf('--gateway.executor-url=')!==0 && a.indexOf('--gateway.execucao.rot')!==0; });
  var allArgs=extra.concat(ovr).join(' ');
  var jmem='-Xmx'+(L.xmx||svc.xmx)+' -XX:MaxMetaspaceSize=256m -XX:CompressedClassSpaceSize=128m -XX:+ExitOnOutOfMemoryError';
  var envStr=Object.keys(L.env||{}).map(function(k){ return k+'='+shArg(L.env[k]); }).join(' ');
  // ulimit -v unlimited (endereçamento) + ulimit -u p/ o hard (nproc soft=200 estoura c/ vários JVMs -> "unable to create native thread")
  var inner='cd '+shArg(svc.dir)+'; mkdir -p tmp; ulimit -v unlimited; ulimit -u $(ulimit -Hu) 2>/dev/null || true; J=./jdk/bin/java; [ -x "$J" ] || J=java; '
    +'exec "$J" -Djava.io.tmpdir="$(pwd)/tmp" '+jmem+' -jar '+path.basename(svc.jar)+' --server.port='+svc.port+(allArgs?' '+allArgs:'');
  return 'fuser -k '+svc.port+'/tcp >/dev/null 2>&1; sleep 1; '+envStr+' setsid bash -c '+shArg(inner)+' >> '+shArg(svc.dir+'/app.log')+' 2>&1 </dev/null &';
}
function powerStart(svcId,cb){ if(!SVC[svcId])return cb('serviço desconhecido');
  try{ cp.spawn('bash',['-c',buildLaunch(svcId)],{detached:true,stdio:'ignore'}).unref(); cb(null); }catch(e){ cb(String(e.message)); } }
function powerStop(svcId,cb){ if(!SVC[svcId])return cb('serviço desconhecido');
  try{ cp.execSync('fuser -k '+SVC[svcId].port+'/tcp >/dev/null 2>&1'); }catch(e){} cb(null); }
function applyRestart(svcId,cb){ return powerStart(svcId,cb); }   // "salvar & aplicar" = subir no modo certo
function reloadEnv(ambiente,cb){ var q=ambiente?('?ambiente='+encodeURIComponent(ambiente)):'';
  try{ cb(null,cp.execSync('curl -fs -m6 -X POST "localhost:8083/admin/env/reload'+q+'"',{encoding:'utf8'})); }catch(e){ cb('falha no reload (gateway-scci no ar?)'); } }

/* tokens de sessao VIVOS no Redis (sess:<SESSION_KEY> com TTL) -> validade real da sessao.
   Conexao TCP direta (RESP) ao Redis 127.0.0.1:6379 — sem docker exec (que estoura recurso na box). */
var REDIS_HOST=process.env.REDIS_HOST||'127.0.0.1', REDIS_PORT=process.env.REDIS_PORT||6379;
function parseResp(s){ if(s[0]!=='*')return null; var i=s.indexOf('\r\n'); if(i<0)return null; var n=parseInt(s.slice(1,i),10);
  if(isNaN(n))return null; if(n<=0)return []; var pos=i+2, out=[];
  for(var k=0;k<n;k++){ if(s[pos]!=='$')return null; var j=s.indexOf('\r\n',pos); if(j<0)return null; var len=parseInt(s.slice(pos+1,j),10);
    if(len===-1){ out.push(null); pos=j+2; continue; } var st=j+2; if(s.length<st+len+2)return null; out.push(s.slice(st,st+len)); pos=st+len+2; } return out; }
/* {SESSION_KEY: "usuario/ambiente"} das sessoes vivas (KEYS sess:* + MGET), numa conexao */
function liveSessions(cb){ var done=false,c,phase=0,keys=[],buf='';
  function finish(map){ if(done)return; done=true; try{c.destroy();}catch(e){} cb(map||{}); }
  try{ c=net.connect({host:REDIS_HOST,port:REDIS_PORT}); }catch(e){ return cb({}); }
  c.setTimeout(2200,function(){finish({});});
  c.on('connect',function(){ c.write('KEYS sess:*\r\n'); });
  c.on('data',function(d){ buf+=d.toString('utf8');
    if(phase===0){ var ks=parseResp(buf); if(ks){ keys=ks.filter(function(k){return k&&k.indexOf('sess:')===0;}); if(!keys.length)return finish({}); buf=''; phase=1; c.write('MGET '+keys.join(' ')+'\r\n'); } }
    else { var vs=parseResp(buf); if(vs){ var m={}; keys.forEach(function(k,i){ m[k.slice(5)]=vs[i]; }); finish(m); } } });
  c.on('error',function(){finish({});}); c.on('close',function(){finish({});}); }
/* valor "usuario/ambiente" -> {usuario, ambiente} (usuario nao tem '/', ambiente comeca em '/') */
function parseSess(v){ if(!v)return null; var i=v.indexOf('/'); if(i<0)return {usuario:v,ambiente:''}; return {usuario:v.slice(0,i),ambiente:v.slice(i)}; }
function nomeAmb(p){ var seg=String(p).split('/').filter(Boolean); return seg.length>=2?seg[1]:(seg[0]||p); }

/* ---------------- logs SSE ---------------- */
var CONSOLE_RE=/^(\S+)\s+(TRACE|DEBUG|INFO|WARN|ERROR)\s+(\d+)\s+---\s+\[([^\]]*)\]\s+\[([^\]]*)\]\s+(\S+)\s*:\s*([\s\S]*)$/;
var KNOWN={'@timestamp':1,'timestamp':1,'@version':1,'level':1,'logger_name':1,'logger':1,'message':1,'thread_name':1,'thread':1,'level_value':1,'stack_trace':1,'traceId':1,'spanId':1,'requestId':1};
function shortLogger(l){ if(!l)return ''; var p=String(l).split('.'); return p[p.length-1]; }
function shortTs(ts){ if(!ts)return ''; var m=/T(\d{2}:\d{2}:\d{2})(\.\d{1,3})?/.exec(ts); return m?(m[1]+(m[2]?m[2].slice(0,3):'')):ts; }
function parseLine(svc,line){ line=line.replace(/\r$/,''); if(!line.trim())return null;
  if(svc.logFmt==='json'){ try{ var o=JSON.parse(line); var kv={}; for(var k in o) if(!KNOWN[k]&&o[k]!==''&&o[k]!=null) kv[k]=o[k];
      return {svc:svc.id,svcLabel:svc.label,ts:shortTs(o['@timestamp']||o.timestamp||''),level:(o.level||'INFO'),logger:shortLogger(o.logger_name||o.logger||''),msg:o.message||'',kv:kv,stack:o.stack_trace||null,raw:o}; }
    catch(e){ return {svc:svc.id,svcLabel:svc.label,ts:'',level:'INFO',logger:'',msg:line,kv:{},raw:{line:line}}; } }
  var mm=CONSOLE_RE.exec(line);
  if(mm) return {svc:svc.id,svcLabel:svc.label,ts:shortTs(mm[1]),level:mm[2],logger:shortLogger(mm[6]),msg:mm[7],kv:{},thread:(mm[5]||mm[4]),raw:{line:line}};
  return {svc:svc.id,svcLabel:svc.label,ts:'',level:'',logger:'',msg:line,kv:{},cont:true,raw:{line:line}};
}
function streamLogs(req,res){
  res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-cache','Connection':'keep-alive','X-Accel-Buffering':'no'});
  res.write('retry: 3000\n\n'); var procs=[];
  ORDER.forEach(function(id){ var svc=SVC[id]; svc.id=id; var p; try{ p=cp.spawn('tail',['-n','20','-F',svc.log]); }catch(e){ return; }
    var buf=''; p.stdout.on('data',function(d){ buf+=d.toString('utf8'); var idx;
      while((idx=buf.indexOf('\n'))>=0){ var ln=buf.slice(0,idx); buf=buf.slice(idx+1); var o=parseLine(svc,ln); if(o){ try{ res.write('data: '+JSON.stringify(o)+'\n\n'); }catch(e){} } } });
    p.on('error',function(){}); procs.push(p); });
  var keep=setInterval(function(){ try{ res.write(': ping\n\n'); }catch(e){} },20000);
  req.on('close',function(){ clearInterval(keep); procs.forEach(function(p){ try{ p.kill(); }catch(e){} }); });
}
function health(){ return ORDER.map(function(id){ var s=SVC[id],up=false; try{ cp.execSync('curl -fs -m2 localhost:'+s.port+'/actuator/health >/dev/null 2>&1'); up=true; }catch(e){} return {id:id,label:s.label,port:s.port,up:up}; }); }

/* ---------------- RTT: cascata de tempo por chamada, CORRELACIONADA por traceId ----------------
   Reune as linhas de log dos 3 serviços (mesmo traceId = mesma requisicao, ligada pelo traceparent
   que o RestClient do gateway propaga). NAO conecta no banco: os tempos vem so dos campos ja logados
     - gateway http_request.duracaoMs  -> total (edge, ponta a ponta)
     - scci-core sdk_hibrido_ok.ms     -> tempo no scci-core executando Pascal via SDK (hibrido)
     - scci-core java_puro             -> marcador do modulo Java (sem ms proprio)
     - program_exec.ms                 -> tempo do PASCAL (roundtrip oserver), dentro do de cima
   O aninhamento e real: duracaoMs >= sdk_hibrido.ms >= program_exec.ms. */
function numOr(v,d){ var n=parseInt(v,10); return isNaN(n)?(d===undefined?null:d):n; }
function tailJson(file,n){ var out=[]; try{ cp.execSync('tail -n '+n+' "'+file+'" 2>/dev/null',{encoding:'utf8',maxBuffer:16<<20})
    .split('\n').forEach(function(l){ l=l.replace(/\r$/,''); if(l.trim()) try{ out.push(JSON.parse(l)); }catch(e){} }); }catch(e){} return out; }
function rttData(limit){ limit=limit||60; var by={}, edges={}, r2t={};
  function rec(tid){ return by[tid]||(by[tid]={tid:tid,ts:'',metodo:'',path:'',status:null,via:null,trilho:null,label:'',erro:false,edge:null,scci:null,pascal:null,mod:null,pascalSvc:null,usuario:null}); }
  ORDER.forEach(function(id){ var svc=SVC[id];
    tailJson(svc.log,900).forEach(function(o){ var tid=o.traceId, rid=o.requestId;
      // ponte requestId->traceId: o gateway loga o http_request (com duracaoMs) FORA do span, so com requestId,
      // mas w_dispatch/web_login (dentro do span) carregam os DOIS. Aqui casamos os dois mundos.
      if(tid&&rid) r2t[rid]=tid;
      if(o.message==='http_request'){ var e={dur:numOr(o.duracaoMs),path:o.path||'',metodo:o.metodo||'',status:(o.status!=null?o.status:null),ts:(o['@timestamp']||o.timestamp||'')};
        if(rid) edges[rid]=e; else if(tid){ var re=rec(tid); re.edge=e.dur; if(e.path)re.path=e.path; if(e.metodo)re.metodo=e.metodo; if(e.status!=null)re.status=e.status; }
        return; }
      if(!tid) return;
      var r=rec(tid); var ts=o['@timestamp']||o.timestamp||''; if(ts>r.ts)r.ts=ts;
      if(o.usuario&&!r.usuario)r.usuario=o.usuario;
      switch(o.message){
        case 'w_dispatch': if(o.trilho)r.trilho=o.trilho; if(o.programName&&!r.label)r.label=o.programName; break;   // gateway decidiu o trilho (fonte da verdade)
        case 'rota_nao_migrada': r.erro=true; if(!r.trilho)r.trilho='puro'; break;
        case 'sdk_hibrido_ok': r.via='launcher-sdk'; r.scci=numOr(o.ms); if(o.programa)r.label=o.programa; if(o.erro===true)r.erro=true; break;
        case 'sdk_hibrido_exec': r.via=r.via||'launcher-sdk'; if(o.programa&&!r.label)r.label=o.programa; break;
        case 'java_puro': if(!r.via)r.via='java-puro'; r.mod={modulo:o.modulo,operacao:o.operacao}; if(o.ms!=null)r.scci=numOr(o.ms); if(o.erro===true)r.erro=true; if(!r.label&&o.modulo)r.label=o.modulo+(o.operacao?'.'+o.operacao:''); break;
        case 'program_exec': r.pascal=numOr(o.ms); r.pascalSvc=id; if(!r.label)r.label=o.programa; if(!r.via)r.via=(id==='launcher'?'launcher':'launcher-sdk'); break;
        case 'program_exec_erro': r.pascal=numOr(o.ms,r.pascal); r.pascalSvc=id; r.erro=true; if(!r.label)r.label=o.programa; if(!r.via)r.via=(id==='launcher'?'launcher':'launcher-sdk'); break;
      }
    });
  });
  // anexa o total do edge (http_request) ao trace, resolvendo requestId->traceId pela ponte
  Object.keys(edges).forEach(function(rid){ var tid=r2t[rid]; if(!tid)return; var e=edges[rid], r=rec(tid);
    r.edge=e.dur; if(e.path)r.path=e.path; if(e.metodo)r.metodo=e.metodo; if(e.status!=null){r.status=e.status; if(+e.status>=400)r.erro=true;} if(e.ts>r.ts)r.ts=e.ts; });
  return Object.keys(by).map(function(t){ return by[t]; })
    .filter(function(r){ return String(r.path).indexOf('/actuator')<0 && (r.edge!=null||r.scci!=null||r.pascal!=null||r.mod); })
    .sort(function(a,b){ return String(b.ts).localeCompare(String(a.ts)); })
    .slice(0,limit)
    .map(function(r){
      var total = r.edge!=null?r.edge:(r.scci!=null?r.scci:(r.pascal!=null?r.pascal:null));
      return {traceId:r.tid,ts:shortTs(r.ts),metodo:r.metodo,path:r.path,status:r.status,usuario:r.usuario,
        via:r.via||(r.mod?'java-puro':null),trilho:r.trilho||null,label:r.label||r.path||'(edge)',erro:!!r.erro,
        total:total,edgeMs:r.edge,scciMs:r.scci,pascalMs:r.pascal,
        modulo:r.mod?r.mod.modulo:null,operacao:r.mod?r.mod.operacao:null,
        pascalOnde:(r.pascalSvc==='launcher'?'launcher':(r.pascal!=null?'scci-core (SDK)':null))};
    });
}

/* ---------------- assets (disco em DEV; EMBUTIDOS no bundle p/ distribuir 1 arquivo) ----------------
   O bundler (bundle.js) injeta index.html + logo.png aqui, gerando um configurador.bundle.js
   autocontido. Em runtime: se o arquivo existir no disco, ele vence (permite hot-edit em dev);
   senao serve o embutido. Assim o "source" fica limpo e a "distribuicao" e um unico .js. */
/*__EMBED_START__*/
var EMBED = { html: null, logo: null };
/*__EMBED_END__*/
function assetHtml(){ try{ return fs.readFileSync(path.join(DIR,'index.html')); }catch(e){ return EMBED.html!=null?Buffer.from(EMBED.html,'utf8'):null; } }
function assetLogo(){ try{ return fs.readFileSync(path.join(DIR,'logo.png')); }catch(e){ return EMBED.logo!=null?Buffer.from(EMBED.logo,'base64'):null; } }

/* ---------------- HTTP ---------------- */
function send(res,code,type,body,extra){ var h={'Content-Type':type}; if(extra) for(var k in extra) h[k]=extra[k]; res.writeHead(code,h); res.end(body); }
function json(res,obj,code){ send(res,code||200,'application/json; charset=utf-8',JSON.stringify(obj)); }
function readBody(req,cb){ var b=''; req.on('data',function(d){ b+=d; if(b.length>1e6) req.destroy(); }); req.on('end',function(){ try{ cb(JSON.parse(b||'{}')); }catch(e){ cb({}); } }); }

// diagnostico CLI: `node server.js --rtt [n]` imprime o RTT correlacionado e sai (sem subir o server).
if(process.argv[2]==='--rtt'){ console.log(JSON.stringify(rttData(parseInt(process.argv[3],10)||60),null,2)); process.exit(0); }

seedAdmin();
http.createServer(function(req,res){
  var u=url.parse(req.url,true), p=u.pathname, user=verifySession(req.headers.cookie);
  // públicas
  if(p==='/'||p==='/index.html'){ var h=assetHtml(); if(h) send(res,200,'text/html; charset=utf-8',h); else send(res,500,'text/plain','index.html ausente'); return; }
  if(p==='/logo.png'){ var l=assetLogo(); if(l) send(res,200,'image/png',l,{'Cache-Control':'max-age=86400'}); else send(res,404,'text/plain','sem logo'); return; }
  if(p==='/api/login'&&req.method==='POST'){ readBody(req,function(b){
      if(checkLogin(b.user,b.pass)){ audit(b.user,'login','ok'); send(res,200,'application/json','{"ok":true}',{'Set-Cookie':'sess='+signSession(b.user)+'; HttpOnly; Path=/; Max-Age=28800; SameSite=Lax'}); }
      else { audit(b.user||'?','login','falha'); json(res,{ok:false,erro:'usuário ou senha inválidos'},401); } }); return; }
  if(p==='/api/me'){ if(user) json(res,{user:user}); else json(res,{erro:'nao autenticado'},401); return; }
  if(p==='/api/logout'&&req.method==='POST'){ send(res,200,'application/json','{"ok":true}',{'Set-Cookie':'sess=; Path=/; Max-Age=0'}); return; }
  // protegidas
  if(!user){ json(res,{erro:'nao autenticado'},401); return; }
  if(p==='/api/logs/stream'){ streamLogs(req,res); }
  else if(p==='/api/config'){ json(res,allConfig()); }
  else if(p==='/api/health'){ json(res,health()); }
  else if(p==='/api/paths'){ var pr={}; ORDER.forEach(function(id){ var s=SVC[id];
      pr[id]={jar:shortP(s.jar),ext:s.ext?shortP(s.ext):null,extExiste:s.ext?fs.existsSync(s.ext):false,log:shortP(s.log),overrides:shortP(OVR_FILE),dir:shortP(s.dir)}; });
      json(res,pr); }
  else if(p==='/api/rtt'){ json(res,rttData(parseInt(u.query.n,10)||60)); }
  else if(p==='/api/audit'){ json(res,readAudit(100)); }
  else if(p==='/api/ambientes'){ json(res,AMBIENTES); }
  else if(p==='/api/sessoes'){ liveSessions(function(sess){ var cut=Date.now()-24*3600*1000, liveKeys={}, liveAmbs={};
      for(var k in sess){ liveKeys[k]=1; var ps=parseSess(sess[k]); if(ps&&ps.ambiente) liveAmbs[ps.ambiente]=(liveAmbs[ps.ambiente]||0)+1; }
      var seen={}, ambs=[]; AMBIENTES.forEach(function(a){ seen[a.path]=1; ambs.push(a); });
      Object.keys(liveAmbs).forEach(function(pth){ if(!seen[pth]){ seen[pth]=1; ambs.push({nome:nomeAmb(pth),path:pth}); } });   // ambientes com sessão viva entram na lista
      json(res, ambs.map(function(a){
        try{ var r=cp.execSync('curl -fs -m10 "localhost:8083/admin/sessoes?ambiente='+encodeURIComponent(a.path)+'"',{encoding:'utf8'});
             var arr=JSON.parse(r)||[], validas=0;
             var ss=arr.map(function(s){ var v=!!(s.chave&&liveKeys[s.chave]); if(v)validas++; return {usuario:s.usuario,ip:s.ip,desde:s.desde,valida:v}; });
             ss.sort(function(x,y){ if(x.valida!==y.valida)return x.valida?-1:1; return String(y.desde||'').localeCompare(String(x.desde||'')); });
             var rec=ss.filter(function(s){return s.desde&&Date.parse(s.desde)>cut;}).length;
             return {nome:a.nome,path:a.path,total:arr.length,recentes:rec,validas:validas,vivas:liveAmbs[a.path]||0,sessoes:ss.slice(0,80)}; }
        catch(e){ return {nome:a.nome,path:a.path,total:0,recentes:0,validas:0,vivas:liveAmbs[a.path]||0,sessoes:[],erro:'gateway-scci indisponível'}; }
      })); }); }
  else if(p==='/api/save'&&req.method==='POST'){ readBody(req,function(b){ if(!SVC[b.svc])return json(res,{ok:false,erro:'serviço inválido'},400);
      var all=loadOverrides(); all[b.svc]=all[b.svc]||{}; var ch=b.changes||{}; for(var k in ch){ if(ch[k]===null) delete all[b.svc][k]; else all[b.svc][k]=String(ch[k]); }
      saveOverrides(all); audit(user,'save',{svc:b.svc,changes:ch}); json(res,{ok:true,overrides:all[b.svc]}); }); }
  else if(p==='/api/apply'&&req.method==='POST'){ readBody(req,function(b){ if(!SVC[b.svc])return json(res,{ok:false,erro:'serviço inválido'},400);
      audit(user,'apply',{svc:b.svc,args:overrideArgs(b.svc)}); applyRestart(b.svc,function(err){ if(err)return json(res,{ok:false,erro:err},500); json(res,{ok:true,reiniciando:b.svc}); }); }); }
  else if(p==='/api/reload'&&req.method==='POST'){ readBody(req,function(b){ audit(user,'reload',{ambiente:b.ambiente}); reloadEnv(b.ambiente,function(err,out){ if(err)return json(res,{ok:false,erro:err},500); json(res,{ok:true,resp:out}); }); }); }
  else if(p==='/api/routing'&&req.method!=='POST'){ json(res,{target:currentRoute()}); }
  else if(p==='/api/power'&&req.method==='POST'){ readBody(req,function(b){ if(!SVC[b.svc])return json(res,{ok:false,erro:'serviço inválido'},400);
      var act=(b.action==='stop')?'stop':(b.action==='restart'?'restart':'start'); audit(user,'power',{svc:b.svc,action:act});
      var fn=(act==='stop')?powerStop:powerStart; fn(b.svc,function(err){ if(err)return json(res,{ok:false,erro:err},500); json(res,{ok:true,svc:b.svc,action:act}); }); }); }
  else if(p==='/api/routing'&&req.method==='POST'){ readBody(req,function(b){ var t=(b.target==='launcher')?'launcher':'hibrido'; audit(user,'routing',{target:t});
      try{ fs.writeFileSync(ROUTE_FILE,JSON.stringify({executor:t})); }catch(e){}
      powerStart('gateway',function(err){ if(err)return json(res,{ok:false,erro:err},500); json(res,{ok:true,target:t}); }); }); }
  else if(p==='/api/rotas'&&req.method!=='POST'){ var rf=loadJson(ROTAS_FILE,{rotaDefault:'pascal',rotas:{}}); json(res,{rotaDefault:rf.rotaDefault||'pascal',rotas:rf.rotas||{}}); }
  else if(p==='/api/rotas'&&req.method==='POST'){ readBody(req,function(b){ var rf=loadJson(ROTAS_FILE,{rotaDefault:'pascal',rotas:{}}); rf.rotas=rf.rotas||{};
      var norm=function(t){ return (t==='puro'||t==='hibrido')?t:'pascal'; };
      if(b.rotaDefault!=null) rf.rotaDefault=norm(b.rotaDefault);
      if(b.programa){ var pg=String(b.programa).trim(), t=norm(b.trilho); if(!pg)return json(res,{ok:false,erro:'programa vazio'},400);
        if(t===(rf.rotaDefault||'pascal')&&t==='pascal') delete rf.rotas[pg]; else rf.rotas[pg]=t; }   // pascal(default) nao precisa de flag
      try{ fs.writeFileSync(ROTAS_FILE,JSON.stringify(rf)); }catch(e){} audit(user,'rota',{programa:b.programa,trilho:b.trilho,rotaDefault:b.rotaDefault});
      powerStart('gateway',function(err){ if(err)return json(res,{ok:false,erro:err},500); json(res,{ok:true,rotaDefault:rf.rotaDefault,rotas:rf.rotas}); }); }); }
  else send(res,404,'text/plain','nao encontrado');
}).listen(PORT,function(){ console.log('configurador SCCI on :'+PORT+' ('+new Date().toISOString()+')'); });
