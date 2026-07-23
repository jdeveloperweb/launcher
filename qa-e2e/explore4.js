// Exploracao do fluxo de documentos (best-effort, screenshot em cada passo).
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;

async function selCombo(page, name, texto) {
  const inp = page.locator(`input[name="${name}"]`);
  await inp.click();
  await page.waitForTimeout(400);
  let item = page.locator('.x-boundlist-item:visible', { hasText: texto }).first();
  if (!(await item.count())) { await inp.press('ArrowDown').catch(() => {}); await page.waitForTimeout(400); item = page.locator('.x-boundlist-item:visible', { hasText: texto }).first(); }
  await item.click({ timeout: 5000 });
  await page.waitForTimeout(300);
}

(async () => {
  const stack = CFG.stacks[0]; // pascal referencia
  const browser = await chromium.launch({ headless: true });
  const { ctx, page } = await novaPagina(browser, stack);
  const step = async (n, fn) => { try { await fn(); } catch (e) { console.log(`passo ${n} ERRO: ${e.message}`); } await page.waitForTimeout(800); await shot(page, 'explore', n); };

  await login(page, CFG.user, CFG.pass, CFG.amb);
  await page.waitForTimeout(1000);

  await step('e10-orig', async () => { await page.click('text="Originação"'); await page.waitForTimeout(1200); });
  await step('e11-cadop', async () => { await page.click('text=/Cadastro de opera/i'); await page.waitForTimeout(2800); });
  await step('e12-periodo', async () => { await selCombo(page, 'periodoCadastramento', '30 dias'); });
  await step('e13-unidade', async () => { await selCombo(page, 'entidade', 'Todas as Empresas'); });
  await step('e14-pesquisar', async () => { await page.click('text="Pesquisar"'); await page.waitForTimeout(3500); });

  // dump linhas do grid
  try {
    const rows = await page.locator('.x-grid-row, tr.x-grid-row').evaluateAll(rs => rs.slice(0, 8).map(r => (r.innerText || '').replace(/\s+/g, ' ').trim().slice(0, 70)));
    console.log('GRID rows:', JSON.stringify(rows, null, 0));
  } catch (e) { console.log('grid dump erro:', e.message); }

  await step('e15-abrir75', async () => {
    const cell = page.locator('text="000000075"').first();
    await cell.dblclick();
    await page.waitForTimeout(3500);
  });
  await step('e16-documentos', async () => {
    await page.click('text="Documentos"');  // menu esquerdo da proposta
    await page.waitForTimeout(3500);
  });

  // dump da tela de documentos
  try {
    const txt = await page.locator('body').innerText();
    console.log('DOC screen tem "Documento de Identificação":', /Documento de Identifica/i.test(txt));
    const btns = await page.locator('a.x-btn, span.x-btn-inner').evaluateAll(ns => [...new Set(ns.map(e => (e.innerText || '').trim()).filter(Boolean))].slice(0, 40));
    console.log('DOC botoes:', JSON.stringify(btns));
    const imgs = await page.locator('img').evaluateAll(ns => ns.map(e => e.getAttribute('data-qtip') || e.getAttribute('title') || e.className).filter(Boolean).slice(0, 30));
    console.log('DOC icones (qtip/title/class):', JSON.stringify([...new Set(imgs)].slice(0, 20)));
  } catch (e) { console.log('doc dump erro:', e.message); }

  await shot(page, 'explore', 'e17-doc-final');
  await browser.close();
  console.log('OK explore4 -> evidencias/casos/explore/');
})();
