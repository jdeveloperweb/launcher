// Testa o ciclo de documento (Anexar->Importar->Salvar->conferir->Excluir) no Pascal (referencia).
const L = require('./lib');
const { chromium, CFG, shot, novaPagina, login } = L;

function pdfMinimo(texto) {
  const objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 340 120] /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  const stream = `BT /F1 16 Tf 20 60 Td (${texto}) Tj ET`;
  objs.push(`<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`);
  let pdf = '%PDF-1.4\n'; const off = [];
  objs.forEach((b, i) => { off.push(pdf.length); pdf += `${i + 1} 0 obj\n${b}\nendobj\n`; });
  const xs = pdf.length;
  pdf += `xref\n0 ${objs.length + 1}\n0000000000 65535 f \n`;
  off.forEach(o => { pdf += String(o).padStart(10, '0') + ' 00000 n \n'; });
  pdf += `trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\nstartxref\n${xs}\n%%EOF`;
  return Buffer.from(pdf, 'latin1');
}

async function selCombo(page, name, texto) {
  const inp = page.locator(`input[name="${name}"]`); await inp.click(); await page.waitForTimeout(400);
  let it = page.locator('.x-boundlist-item:visible', { hasText: texto }).first();
  if (!(await it.count())) { await inp.press('ArrowDown').catch(() => {}); await page.waitForTimeout(400); it = page.locator('.x-boundlist-item:visible', { hasText: texto }).first(); }
  await it.click({ timeout: 5000 }); await page.waitForTimeout(300);
}

async function irParaDocumentos(page) {
  await page.click('text="Originação"'); await page.waitForTimeout(1200);
  await page.click('text=/Cadastro de opera/i'); await page.waitForTimeout(2800);
  await selCombo(page, 'periodoCadastramento', '30 dias');
  await selCombo(page, 'entidade', 'Todas as Empresas');
  await page.click('text="Pesquisar"'); await page.waitForTimeout(3500);
  await page.locator(`text="${CFG.proposta}"`).first().dblclick(); await page.waitForTimeout(3500);
  await page.locator('span.x-menu-item-text', { hasText: 'Documentos' }).first().click(); await page.waitForTimeout(3500);
}

(async () => {
  const stack = CFG.stacks[0];
  const browser = await chromium.launch({ headless: true });
  const { page } = await novaPagina(browser, stack);
  await login(page, CFG.user, CFG.pass, CFG.amb); await page.waitForTimeout(1000);
  await irParaDocumentos(page);
  await shot(page, 'explore', 'd01-grid');

  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  const icons = await row.locator('.x-action-col-icon').evaluateAll(ns => ns.map(e => ({ qtip: e.getAttribute('data-qtip') || '', cls: (e.className || '').slice(0, 50) })));
  console.log('icones acao da linha:', JSON.stringify(icons));

  // Anexar = icone cujo qtip casa com "anexar", senao o primeiro
  let idx = icons.findIndex(i => /anexar|importar/i.test(i.qtip)); if (idx < 0) idx = 0;
  console.log('clicando icone idx', idx);
  await row.locator('.x-action-col-icon').nth(idx).click();
  await page.waitForTimeout(2500);
  await shot(page, 'explore', 'd02-dialog-anexar');

  // Importar -> filechooser
  const pdf = pdfMinimo('QA E2E - documento de teste');
  try {
    const [fc] = await Promise.all([
      page.waitForEvent('filechooser', { timeout: 8000 }),
      page.click('text=/Importar/i'),
    ]);
    await fc.setFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
    console.log('filechooser OK (setFiles)');
  } catch (e) {
    console.log('filechooser falhou, tentando input[type=file]:', e.message);
    const inp = page.locator('input[type=file]').first();
    if (await inp.count()) { await inp.setInputFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf }); console.log('setInputFiles OK'); }
  }
  await page.waitForTimeout(3000);
  await shot(page, 'explore', 'd03-pos-import');

  // Salvar
  await page.click('text=/^Salvar$/i').catch(e => console.log('salvar erro:', e.message));
  await page.waitForTimeout(3000);
  await shot(page, 'explore', 'd04-pos-salvar');

  await browser.close();
  console.log('OK docs-explore (parou antes de excluir; conferir prints)');
})();
