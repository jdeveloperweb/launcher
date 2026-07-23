// Limpa TODAS as versoes de teste do "Documento de Identificacao".
// Clica via JS nativo (element.click()) para ignorar janelas empilhadas que interceptam.
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;
const { irParaDocumentos } = require('./docsflow');

async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }

(async () => {
  const stack = CFG.stacks[process.argv[2] === 'java' ? 1 : 0];
  console.log('cleanup em', stack.nome);
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);
  await liberar(page);

  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.scrollIntoViewIfNeeded().catch(() => {});
  await row.locator('.x-action-col-icon').first().click({ force: true });
  await page.waitForTimeout(3000);
  await liberar(page);
  await shot(page, stack.id, 'CLEAN-01-dialog');

  for (let i = 0; i < 12; i++) {
    await liberar(page);
    const r = await page.evaluate(() => {
      const vis = el => el && el.offsetParent !== null;
      let btn = null;
      const wins = [...document.querySelectorAll('.x-window')].filter(vis);
      for (const w of wins) {
        if (/Apaga vers/i.test(w.innerText || '')) {
          btn = [...w.querySelectorAll('a.x-btn')].find(b => /^Excluir/i.test((b.innerText || '').trim()) && vis(b));
          if (btn) break;
        }
      }
      if (!btn) { const all = [...document.querySelectorAll('a.x-btn')].filter(b => /^Excluir/i.test((b.innerText || '').trim()) && vis(b)); btn = all[all.length - 1]; }
      if (!btn) return 'none';
      btn.click(); return 'clicked';
    });
    if (r === 'none') { console.log('sem mais Excluir visivel'); break; }
    await page.waitForTimeout(1300);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^Sim$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(1000);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^OK$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(2500);
    console.log('iter', i, '-> excluiu');
  }

  await liberar(page);
  await shot(page, stack.id, 'CLEAN-02-apos');
  await browser.close();
  console.log('cleanup done');
})();
