// Acha o "Documentos" do menu ESQUERDO + estrutura da linha "Documento de Identificacao".
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;

async function selCombo(page, name, texto) {
  const inp = page.locator(`input[name="${name}"]`);
  await inp.click(); await page.waitForTimeout(400);
  let item = page.locator('.x-boundlist-item:visible', { hasText: texto }).first();
  if (!(await item.count())) { await inp.press('ArrowDown').catch(() => {}); await page.waitForTimeout(400); item = page.locator('.x-boundlist-item:visible', { hasText: texto }).first(); }
  await item.click({ timeout: 5000 }); await page.waitForTimeout(300);
}

(async () => {
  const stack = CFG.stacks[0];
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await page.click('text="Originação"'); await page.waitForTimeout(1200);
  await page.click('text=/Cadastro de opera/i'); await page.waitForTimeout(2800);
  await selCombo(page, 'periodoCadastramento', '30 dias');
  await selCombo(page, 'entidade', 'Todas as Empresas');
  await page.click('text="Pesquisar"'); await page.waitForTimeout(3500);
  await page.locator('text="000000075"').first().dblclick(); await page.waitForTimeout(3500);

  // candidatos "Documentos"
  const cands = await page.locator(':text-is("Documentos")').evaluateAll(ns => ns.map(e => {
    const r = e.getBoundingClientRect();
    return { tag: e.tagName, id: e.id, cls: (e.className || '').toString().slice(0, 45), x: Math.round(r.x), y: Math.round(r.y) };
  }));
  console.log('CAND Documentos:', JSON.stringify(cands));
  const left = cands.find(c => c.x < 220 && c.y > 150);
  console.log('ESCOLHIDO (esquerdo):', JSON.stringify(left));
  if (left) {
    await page.mouse.click(left.x + 25, left.y + 6);
    await page.waitForTimeout(3500);
  }
  await shot(page, 'explore', 'e20-doc-lista');

  const temIdent = await page.locator('text=/Documento de Identifica/i').count();
  console.log('tem "Documento de Identificacao":', temIdent);
  if (temIdent) {
    const rowInfo = await page.locator('text=/Documento de Identifica/i').first().evaluate(el => {
      let row = el.closest('tr') || el.closest('.x-grid-row') || el.parentElement;
      const cells = [...row.querySelectorAll('td')].map((c, i) => ({ i, cls: (c.className || '').slice(0, 24), imgs: c.querySelectorAll('img').length, html: (c.innerHTML || '').replace(/\s+/g, ' ').slice(0, 70) }));
      return { rowCls: (row.className || '').slice(0, 40), nCells: cells.length, cells };
    });
    console.log('ROW ident:', JSON.stringify(rowInfo, null, 0));
  }
  await browser.close();
  console.log('OK explore5');
})();
