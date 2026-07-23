// Gera o relatorio HTML de evidencias (auto-contido, prints embutidos em base64).
const fs = require('fs');
const path = require('path');
const EVID = path.join(__dirname, 'evidencias');
const SAIDA = path.join(__dirname, 'relatorio-evidencias.html');

const dados = JSON.parse(fs.readFileSync(path.join(EVID, 'resultado.json'), 'utf8'));
const casos = dados.casos || [];

function b64(rel) {
  try {
    const p = path.join(EVID, rel);
    const buf = fs.readFileSync(p);
    const ext = rel.toLowerCase().endsWith('.jpg') || rel.toLowerCase().endsWith('.jpeg') ? 'jpeg' : 'png';
    return `data:image/${ext};base64,${buf.toString('base64')}`;
  } catch { return null; }
}
const esc = s => (s == null ? '' : String(s)).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

// ---- pontuacao ----
const stat = { PASSOU: 0, FALHOU: 0, INFO: 0, BLOQUEADO: 0 };
casos.forEach(c => { stat[c.status] = (stat[c.status] || 0) + 1; });
const total = casos.length;
const verdict = stat.PASSOU + stat.FALHOU;
const taxa = verdict ? Math.round((stat.PASSOU / verdict) * 100) : 0;
function taxaStack(id) { const cs = casos.filter(c => c.stack === id); const ok = cs.filter(c => c.status === 'PASSOU').length; return { ok, total: cs.length, pct: cs.length ? Math.round(ok / cs.length * 100) : 0 }; }
const tPas = taxaStack('pascal'), tJav = taxaStack('java');

// ---- agrupar por dominio -> id -> {pascal, java} ----
const dominios = {};
for (const c of casos) {
  (dominios[c.dominio] = dominios[c.dominio] || {});
  (dominios[c.dominio][c.id] = dominios[c.dominio][c.id] || { id: c.id, titulo: c.titulo, tipo: c.tipo, esperado: c.esperado });
  dominios[c.dominio][c.id][c.stack] = c;
}
const TEC = 'Não-funcional / Técnico';
const ordemDom = ['Acesso', 'Documentos', TEC];
const domNomes = Object.keys(dominios).sort((a, b) => (ordemDom.indexOf(a) + 99) - (ordemDom.indexOf(b) + 99));

// ---- pontos de atencao (nao-PASSOU) ----
const atencao = casos.filter(c => c.status === 'FALHOU' || c.status === 'BLOQUEADO');

function badge(st) {
  const map = { PASSOU: ['ok', 'PASSOU'], FALHOU: ['fail', 'FALHOU'], INFO: ['info', 'INFO'], BLOQUEADO: ['blk', 'BLOQUEADO'] };
  const [cls, txt] = map[st] || ['blk', st];
  return `<span class="badge ${cls}">${txt}</span>`;
}
function coluna(c) {
  if (!c) return `<div class="col vazio">— nao executado —</div>`;
  const imgs = (c.prints || []).map(p => { const d = b64(p); return d ? `<button type="button" class="thumb"><img loading="lazy" src="${d}" alt="${esc(p)}"></button>` : ''; }).join('');
  return `<div class="col">
    <div class="col-top">${badge(c.status)}</div>
    <div class="obtido">${esc(c.obtido)}</div>
    <div class="shots">${imgs}</div>
  </div>`;
}

function cardTecnico(cc) {
  const c = cc.edge || Object.values(cc).find(v => v && v.status);
  if (!c) return '';
  const imgs = (c.prints || []).map(p => { const d = b64(p); return d ? `<button type="button" class="thumb"><img loading="lazy" src="${d}" alt="${esc(p)}"></button>` : ''; }).join('');
  return `<article class="caso tec">
    <div class="caso-h"><span class="cid">${esc(cc.id)}</span><span class="ctit">${esc(cc.titulo)}</span>${badge(c.status)}${c.alvo ? `<span class="alvo">${esc(c.alvo)}</span>` : ''}</div>
    <div class="esp"><b>Esperado:</b> ${esc(cc.esperado)}</div>
    ${c.obtido ? `<div class="obtido"><b>Resultado:</b> ${esc(c.obtido)}</div>` : ''}
    ${c.evidencia ? `<pre class="evid">${esc(c.evidencia)}</pre>` : ''}
    ${imgs ? `<div class="shots">${imgs}</div>` : ''}
  </article>`;
}
let cards = '';
for (const dom of domNomes) {
  const ids = Object.values(dominios[dom]);
  cards += `<section class="dom"><h2>${esc(dom)} <span class="cnt">${ids.length} casos</span></h2>`;
  if (dom === TEC) {
    for (const cc of ids) cards += cardTecnico(cc);
  } else {
    for (const cc of ids) {
      cards += `<article class="caso">
        <div class="caso-h"><span class="cid">${esc(cc.id)}</span><span class="ctit">${esc(cc.titulo)}</span><span class="ctipo ${cc.tipo}">${esc(cc.tipo)}</span></div>
        <div class="esp"><b>Esperado:</b> ${esc(cc.esperado)}</div>
        <div class="cols">
          <div class="colwrap"><div class="stacklbl pascal">Pascal · /aejs</div>${coluna(cc.pascal)}</div>
          <div class="colwrap"><div class="stacklbl java">Java · /aejs-l</div>${coluna(cc.java)}</div>
        </div>
      </article>`;
    }
  }
  cards += `</section>`;
}

const atencaoHtml = atencao.length ? `<aside class="scopebox"><h4>▲ Pontos de atenção (${atencao.length})</h4><ul>${atencao.map(c => `<li><b>${esc(c.stack)}</b> · ${esc(c.id)} ${esc(c.titulo)} — ${esc(c.obtido)}</li>`).join('')}</ul></aside>` : `<aside class="scopebox ok"><h4>✓ Nenhum ponto de atenção — todos os casos passaram nos dois launchers.</h4></aside>`;

const html = `<title>Evidências E2E — SCCI Launcher (Pascal × Java)</title>
<style>
  :root{--bg:#f4f6f7;--surface:#fff;--surface-2:#eef2f4;--ink:#16202a;--ink-soft:#556370;--ink-faint:#8492a0;--border:#d9e1e6;--accent:#0e6b83;--accent-ink:#0a556a;--ok:#2f7d54;--ok-soft:#e5f2ea;--fail:#c23b3b;--fail-soft:#fae9e9;--blk:#a9660f;--blk-soft:#f6ecd9;--pascal:#856527;--pascal-soft:#f1ebda;--java:#0f7d70;--java-soft:#dff1ee;--warn-soft:#fbf1dc;--warn-ink:#8a5a12;--font:"Segoe UI",system-ui,-apple-system,Roboto,sans-serif;--mono:"Cascadia Code","JetBrains Mono",Consolas,ui-monospace,monospace}
  @media(prefers-color-scheme:dark){:root{--bg:#0d1218;--surface:#141b23;--surface-2:#1b242e;--ink:#e6edf2;--ink-soft:#9dabb8;--ink-faint:#6a7a88;--border:#283340;--accent:#38b0cb;--accent-ink:#5cc6de;--ok:#5bbd86;--ok-soft:#12291f;--fail:#e07d7d;--fail-soft:#2f1819;--blk:#d69a4a;--blk-soft:#2c2211;--pascal:#c2a468;--pascal-soft:#292110;--java:#4dc0b0;--java-soft:#0f2b25;--warn-soft:#2c2412;--warn-ink:#d9ab5e}}
  :root[data-theme=dark]{--bg:#0d1218;--surface:#141b23;--surface-2:#1b242e;--ink:#e6edf2;--ink-soft:#9dabb8;--ink-faint:#6a7a88;--border:#283340;--accent:#38b0cb;--accent-ink:#5cc6de;--ok:#5bbd86;--ok-soft:#12291f;--fail:#e07d7d;--fail-soft:#2f1819;--blk:#d69a4a;--blk-soft:#2c2211;--pascal:#c2a468;--pascal-soft:#292110;--java:#4dc0b0;--java-soft:#0f2b25;--warn-soft:#2c2412;--warn-ink:#d9ab5e}
  :root[data-theme=light]{--bg:#f4f6f7;--surface:#fff;--surface-2:#eef2f4;--ink:#16202a;--ink-soft:#556370;--ink-faint:#8492a0;--border:#d9e1e6;--accent:#0e6b83;--accent-ink:#0a556a;--ok:#2f7d54;--ok-soft:#e5f2ea;--fail:#c23b3b;--fail-soft:#fae9e9;--blk:#a9660f;--blk-soft:#f6ecd9;--pascal:#856527;--pascal-soft:#f1ebda;--java:#0f7d70;--java-soft:#dff1ee;--warn-soft:#fbf1dc;--warn-ink:#8a5a12}
  *{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--font);font-size:15px;line-height:1.55}
  .wrap{max-width:1120px;margin:0 auto;padding:26px 22px 70px}
  header{border-bottom:2px solid var(--border);padding-bottom:18px;margin-bottom:22px}
  .eyebrow{font-family:var(--mono);font-size:.72rem;letter-spacing:.16em;text-transform:uppercase;color:var(--accent-ink);margin:0 0 8px}
  h1{font-size:1.9rem;margin:0 0 8px;font-weight:680;letter-spacing:-.01em}
  .lede{color:var(--ink-soft);max-width:75ch;margin:0 0 14px}
  .meta{display:flex;flex-wrap:wrap;gap:8px}.meta .m{background:var(--surface);border:1px solid var(--border);border-radius:999px;padding:5px 12px;font-size:.8rem;color:var(--ink-soft)}.meta .m b{color:var(--ink)}
  .score{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin:20px 0}
  .card{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:14px 16px}
  .card .k{font-family:var(--mono);font-size:.66rem;letter-spacing:.1em;text-transform:uppercase;color:var(--ink-faint)}
  .card .v{font-size:1.9rem;font-weight:680;margin-top:2px;font-variant-numeric:tabular-nums}
  .bar{height:8px;border-radius:4px;background:var(--surface-2);overflow:hidden;margin-top:8px}.bar > i{display:block;height:100%;background:var(--ok)}
  .scopebox{background:var(--warn-soft);border:1px solid color-mix(in srgb,var(--warn-ink) 30%,transparent);border-radius:12px;padding:14px 18px;margin:18px 0}
  .scopebox.ok{background:var(--ok-soft);border-color:color-mix(in srgb,var(--ok) 34%,transparent)}
  .scopebox h4{margin:0 0 6px;color:var(--warn-ink);font-size:.95rem}.scopebox.ok h4{color:var(--ok)}
  .scopebox ul{margin:6px 0 0;padding-left:18px;color:var(--ink-soft);font-size:.87rem;display:flex;flex-direction:column;gap:4px}
  section.dom{margin:30px 0}section.dom > h2{font-size:1.4rem;border-bottom:1px solid var(--border);padding-bottom:8px;margin:0 0 16px}
  section.dom h2 .cnt{font-family:var(--mono);font-size:.7rem;color:var(--ink-faint);font-weight:400}
  .caso{background:var(--surface);border:1px solid var(--border);border-radius:14px;padding:16px 18px;margin-bottom:16px}
  .caso-h{display:flex;flex-wrap:wrap;align-items:center;gap:8px}
  .cid{font-family:var(--mono);font-size:.74rem;background:var(--accent);color:#fff;border-radius:6px;padding:2px 8px}
  :root[data-theme=dark] .cid{color:#06232b}@media(prefers-color-scheme:dark){.cid{color:#06232b}}
  .ctit{font-weight:640}.ctipo{font-size:.7rem;padding:1px 8px;border-radius:999px;border:1px solid var(--border);color:var(--ink-soft);text-transform:capitalize}
  .ctipo.positivo{background:var(--ok-soft);color:var(--ok)}.ctipo.negativo{background:var(--fail-soft);color:var(--fail)}
  .esp{color:var(--ink-soft);font-size:.9rem;margin:8px 0 12px}
  .cols{display:grid;grid-template-columns:1fr 1fr;gap:14px}@media(max-width:680px){.cols{grid-template-columns:1fr}}
  .colwrap{border:1px solid var(--border);border-radius:10px;overflow:hidden}
  .stacklbl{font-family:var(--mono);font-size:.72rem;font-weight:600;padding:6px 12px}
  .stacklbl.pascal{background:var(--pascal-soft);color:var(--pascal)}.stacklbl.java{background:var(--java-soft);color:var(--java)}
  .col{padding:12px}.col.vazio{color:var(--ink-faint);font-size:.85rem}
  .obtido{font-size:.86rem;color:var(--ink-soft);margin:8px 0}
  .caso.tec .caso-h{margin-bottom:4px}
  .alvo{font-family:var(--mono);font-size:.7rem;color:var(--ink-soft);background:var(--surface-2);border:1px solid var(--border);border-radius:6px;padding:2px 8px;margin-left:auto}
  pre.evid{background:var(--surface-2);border:1px solid var(--border);border-radius:8px;padding:12px 14px;overflow-x:auto;font-family:var(--mono);font-size:.79rem;color:var(--ink);white-space:pre;margin:10px 0 0;line-height:1.5}
  .badge{font-size:.72rem;font-weight:700;padding:2px 9px;border-radius:999px}
  .badge.ok{background:var(--ok-soft);color:var(--ok)}.badge.fail{background:var(--fail-soft);color:var(--fail)}.badge.blk{background:var(--blk-soft);color:var(--blk)}
  .badge.info{background:var(--surface-2);color:var(--accent-ink);border:1px solid var(--border)}
  .shots{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}
  .thumb{display:block;padding:0;background:none;border:1px solid var(--border);border-radius:8px;overflow:hidden;width:calc(50% - 4px);cursor:zoom-in;position:relative}
  .thumb:hover{border-color:var(--accent)}
  .thumb:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
  .thumb img{display:block;width:100%;height:auto}
  .thumb::after{content:"\\2922";position:absolute;top:6px;right:6px;width:22px;height:22px;line-height:22px;text-align:center;font-size:.8rem;color:#fff;background:rgba(16,32,42,.55);border-radius:5px;opacity:0;transition:opacity .15s}
  .thumb:hover::after{opacity:1}
  .lb{position:fixed;inset:0;z-index:1000;display:none;align-items:center;justify-content:center;padding:20px;background:rgba(8,12,16,.92);cursor:zoom-out}
  .lb.open{display:flex}
  .lb img{max-width:96vw;max-height:90vh;border-radius:6px;box-shadow:0 10px 50px rgba(0,0,0,.6);cursor:default}
  .lb .x{position:absolute;top:14px;right:20px;width:40px;height:40px;font-size:1.7rem;line-height:1;color:#fff;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.25);border-radius:8px;cursor:pointer}
  .lb .x:hover{background:rgba(255,255,255,.18)}
  .lb .hint{position:absolute;bottom:14px;left:0;right:0;text-align:center;color:#cbd5e1;font-size:.76rem;font-family:var(--mono)}
  footer{margin-top:40px;padding-top:18px;border-top:1px solid var(--border);color:var(--ink-faint);font-size:.82rem}
</style>
<div class="wrap">
<header>
  <p class="eyebrow">Evidências de Teste · Execução real (Playwright)</p>
  <h1>Evidências E2E — SCCI Launcher: Pascal × Java</h1>
  <p class="lede">Reprodução automatizada dos fluxos in-scope pela interface real, no launcher legado (<b>/aejs</b>) e no novo (<b>/aejs-l</b>),
    com prints anexados de cada passo. Escopo: login, troca de senha (validações) e ciclo de documentos (anexar/persistir/excluir).
    <b>Clique numa miniatura para ampliar.</b></p>
  <div class="meta">
    <span class="m">Ambiente <b>${esc(dados.casos[0] ? '/u10/c6bank/suporte/scat112934' : '')}</b></span>
    <span class="m">Proposta <b>000000075</b></span>
    <span class="m">Usuário <b>supervisor</b></span>
    <span class="m">Casos <b>${total}</b></span>
    <span class="m">Gerado <b>${esc((dados.geradoEmISO || '').slice(0, 16).replace('T', ' '))}</b></span>
  </div>
</header>

<div class="score">
  <div class="card"><div class="k">Aprovação (com veredito)</div><div class="v">${taxa}%</div><div class="bar"><i style="width:${taxa}%"></i></div></div>
  <div class="card"><div class="k">Passou</div><div class="v" style="color:var(--ok)">${stat.PASSOU}</div></div>
  <div class="card"><div class="k">Falhou</div><div class="v" style="color:var(--fail)">${stat.FALHOU}</div></div>
  <div class="card"><div class="k">Info / parcial</div><div class="v" style="color:var(--blk)">${stat.INFO + stat.BLOQUEADO}</div></div>
  <div class="card"><div class="k">Pascal</div><div class="v">${tPas.ok}/${tPas.total}</div><div class="bar"><i style="width:${tPas.pct}%"></i></div></div>
  <div class="card"><div class="k">Java</div><div class="v">${tJav.ok}/${tJav.total}</div><div class="bar"><i style="width:${tJav.pct}%"></i></div></div>
</div>

${atencaoHtml}
${cards}

<footer>Relatório gerado automaticamente a partir da execução Playwright (headless Chromium) contra os ambientes de desenvolvimento.
Prints capturados em cada passo e embutidos neste arquivo. Documentos de teste anexados foram removidos ao fim de cada ciclo (limpeza).</footer>
</div>
<div class="lb" id="lb" role="dialog" aria-modal="true" aria-label="Evidência ampliada">
  <button class="x" type="button" aria-label="Fechar (Esc)">&times;</button>
  <img alt="Evidência ampliada">
  <div class="hint">clique fora ou tecle Esc para fechar · ← → para navegar</div>
</div>
<script>
(function(){
  var lb=document.getElementById('lb'), lbImg=lb.querySelector('img'), thumbs=[], idx=-1;
  function all(){ return [].slice.call(document.querySelectorAll('.thumb img')); }
  function show(i){ thumbs=all(); idx=(i+thumbs.length)%thumbs.length; lbImg.src=thumbs[idx].src; lb.classList.add('open'); }
  function close(){ lb.classList.remove('open'); lbImg.removeAttribute('src'); idx=-1; }
  document.addEventListener('click',function(e){
    var t=e.target.closest('.thumb');
    if(t){ thumbs=all(); show(thumbs.indexOf(t.querySelector('img'))); return; }
    if(e.target===lb || e.target.classList.contains('x')) close();
  });
  document.addEventListener('keydown',function(e){
    if(!lb.classList.contains('open')) return;
    if(e.key==='Escape') close();
    else if(e.key==='ArrowRight') show(idx+1);
    else if(e.key==='ArrowLeft') show(idx-1);
  });
})();
</script>`;

fs.writeFileSync(SAIDA, html);
const kb = Math.round(fs.statSync(SAIDA).size / 1024);
console.log(`OK relatorio: ${SAIDA} (${kb} KB, ${total} casos, ${taxa}% aprovacao)`);
