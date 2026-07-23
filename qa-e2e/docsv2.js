// Documentos v2 (robusto, JS-native): Anexar -> Persistencia -> Excluir, nos 2 edges. Limpa no fim.
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login, Recorder } = L;
const { irParaDocumentos, pdfMinimo } = require('./docsflow');

async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }
async function fechar(page) {
  await page.evaluate(() => [...document.querySelectorAll('a.x-btn')].forEach(b => { if (/Fechar tela/i.test(b.innerText || '') && b.offsetParent) b.click(); })).catch(() => {});
  await page.waitForTimeout(900); await liberar(page);
}
async function abrirDoc(page) {
  await fechar(page); await liberar(page);
  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.scrollIntoViewIfNeeded().catch(() => {});
  await row.locator('.x-action-col-icon').first().click({ force: true });
  await page.waitForTimeout(2200); await liberar(page);
}
async function temVersao(page) {
  return await page.evaluate(() => [...document.querySelectorAll('a.x-btn')].some(b => b.offsetParent && /Excluir Vers/i.test((b.innerText || '') + (b.getAttribute('data-qtip') || ''))));
}
async function importar(page, pdf) {
  try {
    const [fc] = await Promise.all([page.waitForEvent('filechooser', { timeout: 6000 }),
      page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => x.offsetParent && /Importar/i.test(x.innerText || '')); if (b) b.click(); })]);
    await fc.setFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
  } catch {
    const inp = page.locator('input[type=file]').last();
    if (await inp.count()) await inp.setInputFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
  }
  await page.waitForTimeout(4000); await liberar(page);
}
// remove todas as versoes (reabre a janela "Apaga versoes" por versao, pois ela fecha a cada exclusao)
async function limparVersoes(page) {
  let n = 0;
  for (let k = 0; k < 40; k++) {
    await abrirDoc(page);
    if (!(await temVersao(page))) break;
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => x.offsetParent && /Excluir Vers/i.test((x.innerText || '') + (x.getAttribute('data-qtip') || ''))); if (b) b.click(); });
    await page.waitForTimeout(2000); await liberar(page);
    const sel = await page.evaluate(() => {
      const vis = el => el && el.offsetParent !== null;
      const win = [...document.querySelectorAll('.x-window')].filter(vis).find(w => /Apaga vers/i.test((w.querySelector('[id$=header-title-textEl]') || {}).innerText || ''));
      if (!win) return false; const rows = [...win.querySelectorAll('tr.x-grid-row')].filter(vis); if (!rows.length) return false; rows[0].click(); return true;
    });
    if (!sel) break;
    await page.waitForTimeout(500);
    await page.evaluate(() => {
      const vis = el => el && el.offsetParent !== null;
      const win = [...document.querySelectorAll('.x-window')].filter(vis).find(w => /Apaga vers/i.test((w.querySelector('[id$=header-title-textEl]') || {}).innerText || ''));
      if (win) { const e = [...win.querySelectorAll('a.x-btn')].find(b => vis(b) && /^Excluir$/i.test((b.innerText || '').trim())); if (e) e.click(); }
    });
    await page.waitForTimeout(1200);
    await page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => /^(Sim|OK)$/i.test((x.innerText || '').trim()) && x.offsetParent); if (b) b.click(); });
    await page.waitForTimeout(2000);
    n++;
  }
  await fechar(page);
  return n;
}

async function docs(browser, stack, rec) {
  const pdf = pdfMinimo('QA E2E - doc teste');
  const reg = (id, tit, esp, obt, ok, prints) => rec.registrar({ id, dominio: 'Documentos', titulo: tit, stack: stack.id, stackNome: stack.nome, tipo: 'positivo', esperado: esp, obtido: obt, status: ok ? 'PASSOU' : 'FALHOU', prints: prints || [] });
  const { ctx, page } = await novaPagina(browser, stack);
  try {
    const rl = await login(page, CFG.user, CFG.pass, CFG.amb); if (!rl.ok) throw new Error('login falhou');
    await irParaDocumentos(page);
    await limparVersoes(page); // estado limpo

    await abrirDoc(page);
    const p1 = await shot(page, stack.id, 'DO-03-01-dialog');
    await importar(page, pdf);
    const anexou = await temVersao(page);
    const p2 = await shot(page, stack.id, 'DO-03-01-importado');
    reg('CT-DO-03-01', 'Anexar documento (upload)', 'Arquivo anexado (dialog passa a ter "Excluir Versao Documento")', anexou ? 'Documento anexado com sucesso' : 'Nao anexou', anexou, [p1, p2]);

    await abrirDoc(page);
    const persistiu = await temVersao(page);
    const p3 = await shot(page, stack.id, 'DO-01-01-conferir');
    reg('CT-DO-01-01', 'Persistencia do documento (reabrir)', 'Ao reabrir, o documento continua anexado', persistiu ? 'Documento persistido' : 'Nao encontrado ao reabrir', persistiu, [p3]);

    const rem = await limparVersoes(page);
    await abrirDoc(page);
    const aindaTem = await temVersao(page);
    const p4 = await shot(page, stack.id, 'DO-03-03-excluido');
    reg('CT-DO-03-03', 'Excluir documento (remove versoes)', 'Documento removido (sem versoes ao reabrir)', aindaTem ? 'ATENCAO: ainda anexado' : `Documento removido (${rem} versao/oes)`, !aindaTem, [p4]);
    await fechar(page);
  } catch (e) {
    console.log(`[${stack.id}] docsv2 ERRO: ${e.message}`);
    ['CT-DO-03-01', 'CT-DO-01-01', 'CT-DO-03-03'].forEach(id => rec.registrar({ id, dominio: 'Documentos', titulo: 'Documentos (E2E)', stack: stack.id, stackNome: stack.nome, tipo: 'positivo', esperado: '-', obtido: 'BLOQUEADO: ' + e.message.slice(0, 60), status: 'BLOQUEADO', prints: [] }));
  }
  await ctx.close();
}

(async () => {
  const alvo = process.argv[2];
  const rec = new Recorder();
  const browser = await chromium.launch({ headless: true });
  for (const stack of CFG.stacks) { if (alvo && stack.id !== alvo) continue; console.log('=== DOCS v2 ::', stack.nome, '==='); await docs(browser, stack, rec); }
  await browser.close();
  console.log('fim docsv2');
})();
