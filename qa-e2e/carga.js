// Sondagem de CAPACIDADE (não stress-to-fail) — Pascal /aejs × Java /aejs-l.
// GET da página de entrada (round-trip pela borda real), rampa de concorrência, sem efeito colateral.
// Para a rampa de um stack se a taxa de erro passar de 20% (protege a desenv compartilhada).
const https = require('https');
const fs = require('fs'); const path = require('path');
const STACKS = [
  { id:'pascal', nome:'Pascal /aejs',  url:'https://desenv.prognum.com.br/aejs/' },
  { id:'java',   nome:'Java /aejs-l',   url:'https://desenv.prognum.com.br/aejs-l/' },
];
const LEVELS = [2,5,10,20,40];     // concorrência
const PER = 60;                    // requisições por nível
const OUT = path.join(__dirname,'evidencias'); fs.mkdirSync(OUT,{recursive:true});

function req(url){ return new Promise(res=>{ const t=Date.now();
  const r=https.get(url,{rejectUnauthorized:false,timeout:20000},resp=>{ resp.on('data',()=>{}); resp.on('end',()=>res({ms:Date.now()-t,ok:resp.statusCode<400,code:resp.statusCode})); });
  r.on('error',()=>res({ms:Date.now()-t,ok:false,code:0}));
  r.on('timeout',()=>{ r.destroy(); res({ms:Date.now()-t,ok:false,code:0}); }); }); }
async function level(url,conc,total){ let i=0; const out=[]; const t0=Date.now();
  async function worker(){ while(i<total){ i++; out.push(await req(url)); } }
  await Promise.all(Array.from({length:conc},worker));
  return { out, wall:(Date.now()-t0)/1000 }; }
function pct(a,p){ if(!a.length)return 0; const s=a.slice().sort((x,y)=>x-y); return s[Math.min(s.length-1,Math.floor(s.length*p/100))]; }

(async()=>{
  const results = {};
  for (const s of STACKS){
    await req(s.url); await req(s.url);                 // warmup
    results[s.id]=[]; let stop=false;
    for (const c of LEVELS){
      if (stop){ results[s.id].push({conc:c,skip:true}); continue; }
      const { out, wall } = await level(s.url, c, PER);
      const ms = out.map(x=>x.ms), errs = out.filter(x=>!x.ok).length;
      const row = { conc:c, n:out.length, err:errs, errPct:Math.round(100*errs/out.length),
        rps:+(out.length/wall).toFixed(1), p50:pct(ms,50), p95:pct(ms,95), max:Math.max.apply(null,ms) };
      results[s.id].push(row);
      console.log(`[${s.id}] conc=${String(c).padStart(2)}  rps=${String(row.rps).padStart(5)}  p50=${String(row.p50).padStart(4)}ms  p95=${String(row.p95).padStart(5)}ms  max=${String(row.max).padStart(5)}ms  err=${row.errPct}%`);
      if (row.errPct>20){ console.log(`  -> ${s.id}: taxa de erro ${row.errPct}% > 20% — parando a rampa (protege a desenv).`); stop=true; }
      await new Promise(r=>setTimeout(r,800));          // respiro entre níveis
    }
  }
  fs.writeFileSync(path.join(OUT,'carga.json'), JSON.stringify(results,null,2));
  console.log('\nOK: resultados em evidencias/carga.json');
})().catch(e=>{ console.error('ERRO:',e.message); process.exit(1); });
