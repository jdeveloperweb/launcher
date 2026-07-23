// Captura o CORPO real que o front /aejs-l manda no login -> mostra se vem cifrado (marcador W_COP "____").
const { chromium } = require('playwright');
const URL='https://desenv.prognum.com.br/aejs-l/', AMB='/u11/caixa/dados', USER='supervisor', PASS='Tempo+2023';
(async()=>{
  const b=await chromium.launch({headless:true});
  const ctx=await b.newContext({ignoreHTTPSErrors:true}); const p=await ctx.newPage();
  const caps=[];
  p.on('request',r=>{ if(/\/w\/(login|logoff|password)/.test(r.url())&&r.method()==='POST'){ caps.push({url:r.url(), body:(r.postData()||'').slice(0,60)}); }});
  await p.goto(URL,{waitUntil:'networkidle',timeout:35000});
  await p.fill('input[name="name"]',USER); await p.fill('input[name="password"]',PASS); await p.fill('input[name="ambienteOperacional"]',AMB);
  await p.click('text="Login"'); await p.waitForTimeout(4000);
  console.log('--- corpo(s) enviado(s) pelo front ---');
  caps.forEach(c=>{ const cif=c.body.startsWith('____'); console.log(`  ${c.url.split('/aejs-l')[1]}`); console.log(`  cifrado(W_COP)=${cif}  inicio="${c.body.replace(/\n/g,' ')}"`); });
  if(!caps.length) console.log('  (nenhum POST /w/* capturado)');
  await b.close();
})().catch(e=>{console.error('ERRO:',e.message);process.exit(1);});
