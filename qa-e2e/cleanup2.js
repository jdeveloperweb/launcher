// Cleanup PRECISO: remove versoes do "Documento de Identificacao" clicando SOMENTE
// "Excluir Versão Documento" (via JS nativo), reabrindo o dialog e verificando ate zerar.
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;
const { irParaDocumentos } = require('./docsflow');

async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }
async function fecharJanelas(page) {
  await page.evaluate(() => [...document.querySelectorAll('a.x-btn')].forEach(b => { if (/Fechar tela/i.test(b.innerText || '') && b.offsetParent) b.click(); })).catch(() => {});
  await page.waitForTimeout(1000); await liberar(page);
}
async function abrir(page) {
  await fecharJanelas(page); await liberar(page);
  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.scrollIntoViewIfNeeded().catch(() => {});
  await row.locator('.x-action-col-icon').first().click({ force: true });
  await page.waitForTimeout(2500); await liberar(page);
}

(async () => {
  const stack = CFG.stacks[process.argv[2] === 'java' ? 1 : 0];
  console.log('cleanup2 em', stack.nome);
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);

  let restantes = 0;
  for (let i = 0; i < 8; i++) {
    await abrir(page);
    const temBtn = await page.evaluate(() => {
      const b = [...document.querySelectorAll('a.x-btn')].find(x => /Excluir Vers/i.test((x.innerText || '').trim()) && x.offsetParent);
      if (!b) return false; b.click(); return true;
    });
    if (!temBtn) { console.log('limpo (sem "Excluir Versao Documento")'); break; }
    await page.waitForTimeout(1300);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^Sim$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(1000);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^OK$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(2000);
    restantes = i + 1;
    console.log('removida versao', i + 1);
  }
  await fecharJanelas(page);
  await liberar(page);
  await shot(page, stack.id, 'CLEAN2-final');
  await browser.close();
  console.log('cleanup2 done (', restantes, 'removidas)');
})();
