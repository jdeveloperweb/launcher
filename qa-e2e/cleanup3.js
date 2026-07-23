// Cleanup diagnostico: loga botoes a cada passo, mira so no excluir de doc/versao (nunca Avulso).
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;
const { irParaDocumentos } = require('./docsflow');

async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }
async function fechar(page) {
  await page.evaluate(() => [...document.querySelectorAll('a.x-btn')].forEach(b => { if (/Fechar tela/i.test(b.innerText || '') && b.offsetParent) b.click(); })).catch(() => {});
  await page.waitForTimeout(900); await liberar(page);
}
async function abrir(page) {
  await fechar(page); await liberar(page);
  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.scrollIntoViewIfNeeded().catch(() => {});
  await row.locator('.x-action-col-icon').first().click({ force: true });
  await page.waitForTimeout(2500); await liberar(page);
}

(async () => {
  const stack = CFG.stacks[process.argv[2] === 'java' ? 1 : 0];
  console.log('cleanup3 em', stack.nome);
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);

  let semProgresso = 0, ultima = '';
  for (let i = 0; i < 25; i++) {
    await abrir(page);
    const info = await page.evaluate(() => {
      const vis = el => el && el.offsetParent !== null;
      const btns = [...document.querySelectorAll('a.x-btn')].filter(vis).map(b => (b.innerText || '').trim()).filter(Boolean);
      const alvo = [...document.querySelectorAll('a.x-btn')].find(b => vis(b)
        && /Excluir Vers|Exclui o documento|Excluir Documento/i.test((b.innerText || '') + ' ' + (b.getAttribute('data-qtip') || ''))
        && !/Avulso/i.test(b.innerText || ''));
      if (alvo) { alvo.click(); return { clicou: (alvo.innerText || '').trim(), btns }; }
      return { clicou: null, btns };
    });
    const assinatura = info.btns.join('|');
    console.log(`iter ${i}: clicou="${info.clicou}" botoes=[${info.btns.slice(0, 7).join(', ')}]`);
    if (!info.clicou) { console.log('>>> CLEAN (sem botao de excluir doc/versao)'); break; }
    await page.waitForTimeout(1300);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^Sim$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(1000);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^OK$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(2500);
    // deteccao de nao-progresso (mesma assinatura de botoes 3x seguidas)
    if (assinatura === ultima) { semProgresso++; } else { semProgresso = 0; }
    ultima = assinatura;
    if (semProgresso >= 3) { console.log('!!! PAROU: sem progresso (mesma tela 3x) — verificar manualmente'); break; }
  }
  await fechar(page); await liberar(page);
  await shot(page, stack.id, 'CLEAN3-final');
  await browser.close();
  console.log('cleanup3 done');
})();
