// Verificacao READ-ONLY: re-navega do zero e le o estado da linha "Documento de Identificacao".
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;
const { irParaDocumentos } = require('./docsflow');

(async () => {
  const stack = CFG.stacks[process.argv[2] === 'java' ? 1 : 0];
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);
  await page.waitForTimeout(2000);
  await shot(page, stack.id, 'VERIFY-grid');

  const info = await page.evaluate(() => {
    const row = [...document.querySelectorAll('tr.x-grid-row')].find(r => /Documento de Identifica/i.test(r.innerText || ''));
    if (!row) return { achou: false };
    const txt = (row.innerText || '').replace(/\s+/g, ' ').trim();
    const anexarCell = row.querySelectorAll('td')[2];
    const icone = anexarCell ? (anexarCell.querySelector('[class*=icone], .x-action-col-icon')?.className || '') : '';
    return { achou: true, txt, alterado: /ALTERADO/i.test(txt), temMini: !!row.querySelector('img'), icone };
  });
  console.log('LINHA Documento de Identificacao:', JSON.stringify(info));
  console.log(info.alterado ? '=> AINDA COM CONTEUDO (ALTERADO)' : '=> LIMPO (sem ALTERADO)');
  await browser.close();
})();
