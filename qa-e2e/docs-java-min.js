// Upload minimo via edge JAVA (prova que o /aejs-l trata o upload de documento). Registra 1 caso.
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login, Recorder } = L;
const { irParaDocumentos, pdfMinimo } = require('./docsflow');
async function liberar(page) { await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {}); }

(async () => {
  const stack = CFG.stacks[1]; // java
  const rec = new Recorder();
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page); await liberar(page);
  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.scrollIntoViewIfNeeded().catch(() => {});
  await row.locator('.x-action-col-icon').first().click({ force: true });
  await page.waitForTimeout(2500); await liberar(page);
  const p1 = await shot(page, stack.id, 'DO-03-01-dialog');

  const pdf = pdfMinimo('QA E2E Java - doc teste');
  try {
    const [fc] = await Promise.all([
      page.waitForEvent('filechooser', { timeout: 6000 }),
      page.evaluate(() => { const b = [...document.querySelectorAll('a.x-btn')].find(x => x.offsetParent && /Importar/i.test(x.innerText || '')); if (b) b.click(); }),
    ]);
    await fc.setFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
  } catch {
    const inp = page.locator('input[type=file]').last();
    if (await inp.count()) await inp.setInputFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
  }
  await page.waitForTimeout(4500); await liberar(page);
  const anexou = await page.evaluate(() => [...document.querySelectorAll('a.x-btn')].some(b => b.offsetParent && /Excluir Vers/i.test((b.innerText || '') + (b.getAttribute('data-qtip') || ''))));
  const p2 = await shot(page, stack.id, 'DO-03-01-importado');
  rec.registrar({
    id: 'CT-DO-03-01', dominio: 'Documentos', titulo: 'Anexar documento (upload)', stack: stack.id, stackNome: stack.nome,
    tipo: 'positivo', esperado: 'Arquivo anexado pelo edge Java (dialog passa a ter versao / Anexado por)',
    obtido: anexou ? 'Documento anexado com sucesso pelo edge Java (/aejs-l)' : 'Nao anexou', status: anexou ? 'PASSOU' : 'FALHOU', prints: [p1, p2],
  });
  await browser.close();
  console.log('java upload =>', anexou ? 'PASSOU' : 'FALHOU');
})();
