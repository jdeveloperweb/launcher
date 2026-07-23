// Cleanup CORRETO: "Excluir Versao Documento" abre a janela "Apaga versoes"; nela,
// seleciona cada versao e clica Excluir ate zerar.
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;
const { irParaDocumentos } = require('./docsflow');

async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }
async function fechar(page) {
  await page.evaluate(() => [...document.querySelectorAll('a.x-btn')].forEach(b => { if (/Fechar tela/i.test(b.innerText || '') && b.offsetParent) b.click(); })).catch(() => {});
  await page.waitForTimeout(900); await liberar(page);
}

(async () => {
  const stack = CFG.stacks[process.argv[2] === 'java' ? 1 : 0];
  console.log('cleanup4 em', stack.nome);
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);
  await fechar(page);

  // reabre doc dialog -> "Excluir Versao Documento" -> janela "Apaga versoes". retorna false se o doc nao tem versoes (limpo).
  async function abrirVersoes() {
    await fechar(page); await liberar(page);
    const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
    await row.scrollIntoViewIfNeeded().catch(() => {});
    await row.locator('.x-action-col-icon').first().click({ force: true });
    await page.waitForTimeout(2200); await liberar(page);
    const abriu = await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => x.offsetParent && /Excluir Vers/i.test((x.innerText || '') + (x.getAttribute('data-qtip') || ''))); if (b) { b.click(); return true; } return false; });
    await page.waitForTimeout(2200); await liberar(page);
    return abriu;
  }

  let removidas = 0;
  for (let k = 0; k < 40; k++) {
    const abriu = await abrirVersoes();
    if (!abriu) { console.log('>>> LIMPO: doc sem "Excluir Versao Documento" (zero versoes)'); break; }
    await liberar(page);
    const nRows = await page.evaluate(() => {
      const vis = el => el && el.offsetParent !== null;
      const win = [...document.querySelectorAll('.x-window')].filter(vis).find(w => /Apaga vers/i.test((w.querySelector('[id$=header-title-textEl]') || {}).innerText || ''));
      if (!win) return -1;
      const rows = [...win.querySelectorAll('tr.x-grid-row')].filter(vis);
      if (rows.length) rows[0].click(); // seleciona a 1a versao
      return rows.length;
    });
    if (nRows === -1) { console.log('janela de versoes fechou (limpo?)'); break; }
    if (nRows === 0) { console.log('>>> ZERADO: nao ha mais versoes'); break; }
    await page.waitForTimeout(600);
    const clicou = await page.evaluate(() => {
      const vis = el => el && el.offsetParent !== null;
      const win = [...document.querySelectorAll('.x-window')].filter(vis).find(w => /Apaga vers/i.test((w.querySelector('[id$=header-title-textEl]') || {}).innerText || ''));
      if (!win) return false;
      const exc = [...win.querySelectorAll('a.x-btn')].find(b => vis(b) && /^Excluir$/i.test((b.innerText || '').trim()));
      if (!exc) return false; exc.click(); return true;
    });
    if (!clicou) { console.log('sem botao Excluir na janela de versoes'); break; }
    await page.waitForTimeout(1200);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^(Sim|OK)$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(2000);
    removidas++;
    console.log(`versoes restantes antes: ${nRows} -> removida (${removidas})`);
  }

  await fechar(page); await liberar(page);
  await shot(page, stack.id, 'CLEAN4-final');
  await browser.close();
  console.log('cleanup4 done -', removidas, 'removidas');
})();
