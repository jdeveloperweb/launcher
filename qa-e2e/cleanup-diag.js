// Diagnostico: clica "Excluir Versao Documento" UMA vez e mostra qual confirmacao aparece.
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;
const { irParaDocumentos } = require('./docsflow');

async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }

(async () => {
  const stack = CFG.stacks[0];
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);
  await liberar(page);
  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.locator('.x-action-col-icon').first().click({ force: true });
  await page.waitForTimeout(2500); await liberar(page);
  await shot(page, 'explore', 'DIAG-antes');

  const clicou = await page.evaluate(() => {
    const vis = el => el && el.offsetParent !== null;
    const b = [...document.querySelectorAll('a.x-btn')].find(x => vis(x) && /Excluir Vers/i.test((x.innerText || '') + (x.getAttribute('data-qtip') || '')));
    if (b) { b.click(); return (b.innerText || '').trim(); } return null;
  });
  console.log('clicou:', clicou);
  await page.waitForTimeout(2500);

  // dump janelas/mensagens visiveis + seus botoes
  const dump = await page.evaluate(() => {
    const vis = el => el && el.offsetParent !== null;
    const out = [];
    [...document.querySelectorAll('.x-message-box, .x-window')].filter(vis).forEach(w => {
      const titEl = w.querySelector('[id$=header-title-textEl], .x-title-text');
      const tit = titEl ? titEl.innerText.trim() : '(sem titulo)';
      const txt = (w.innerText || '').replace(/\s+/g, ' ').slice(0, 160);
      const btns = [...w.querySelectorAll('a.x-btn')].filter(vis).map(b => (b.innerText || '').trim()).filter(Boolean);
      out.push({ tit, txt, btns });
    });
    return out;
  });
  console.log('JANELAS VISIVEIS:', JSON.stringify(dump, null, 1));
  await shot(page, 'explore', 'DIAG-depois');
  await browser.close();
})();
