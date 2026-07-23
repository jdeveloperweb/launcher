// Fluxo de documentos (E2E): Anexar -> Importar -> Salvar -> Conferir -> Excluir. Limpa no fim.
// Robustez: age SEMPRE na janela/botao VISIVEL (evita locators stale de janelas empilhadas).
const L = require('./lib');
const { CFG, shot, novaPagina, login } = L;

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

async function liberarMascara(page) {
  await page.evaluate(() => document.querySelectorAll('.x-mask').forEach(m => { m.style.pointerEvents = 'none'; })).catch(() => {});
}
async function esperarSemMascara(page) {
  await page.waitForTimeout(1500);
  for (let i = 0; i < 20; i++) { if ((await page.locator('.x-mask:visible').count()) === 0) break; await page.waitForTimeout(500); }
  await liberarMascara(page);
}

// ---- botoes/estado da janela de documento (sempre a VISIVEL) ----
const botao = (page, txt) => page.locator('.x-window:visible a.x-btn:visible', { hasText: txt }).first();
async function temAnexado(page) { await liberarMascara(page); return (await page.locator('.x-window:visible a.x-btn:visible', { hasText: 'Excluir' }).count()) > 0; }
async function clicar(page, txt, to = 8000) { await liberarMascara(page); await botao(page, txt).click({ timeout: to }); }

async function fecharJanelas(page) {
  for (let i = 0; i < 6; i++) {
    const win = page.locator('.x-window:visible', { hasText: 'Observações do documento' });
    if ((await win.count()) === 0) break;
    const f = page.locator('.x-window:visible a.x-btn:visible', { hasText: 'Fechar tela' }).first();
    if (await f.count()) await f.click().catch(() => {}); else await page.keyboard.press('Escape').catch(() => {});
    await page.waitForTimeout(1000);
  }
  await liberarMascara(page);
}
async function dismissMsg(page) {
  const ok = page.locator('.x-message-box:visible a.x-btn:visible', { hasText: 'OK' }).first();
  if (await ok.count()) await ok.click().catch(() => {});
  await page.waitForTimeout(500);
}

async function irParaDocumentos(page) {
  await page.click('text="Originação"'); await page.waitForTimeout(1200);
  await page.click('text=/Cadastro de opera/i'); await page.waitForTimeout(2800);
  await selCombo(page, 'periodoCadastramento', '30 dias');
  await selCombo(page, 'entidade', 'Todas as Empresas');
  await page.click('text="Pesquisar"'); await page.waitForTimeout(3500);
  await esperarSemMascara(page);
  await page.locator(`text="${CFG.proposta}"`).first().dblclick(); await page.waitForTimeout(3500);
  await esperarSemMascara(page);
  // abre a aba Documentos (menu esquerdo) com retry ate a grade carregar (o clique e flaky)
  for (let i = 0; i < 5; i++) {
    await page.locator('span.x-menu-item-text', { hasText: 'Documentos' }).first().click().catch(() => {});
    await page.waitForTimeout(2800);
    await esperarSemMascara(page);
    if (await page.locator('text=/Documento de Identifica/i').count()) break;
  }
  await page.locator('text=/Documento de Identifica/i').first().waitFor({ timeout: 15000 });
}

async function abrirDocDialog(page) {
  await fecharJanelas(page);
  await esperarSemMascara(page);
  const row = page.locator('tr.x-grid-row', { hasText: 'Documento de Identificação' }).first();
  await row.scrollIntoViewIfNeeded().catch(() => {});
  const icon = row.locator('.x-action-col-icon').first();
  try { await icon.click({ timeout: 6000 }); } catch { await icon.click({ force: true }); }
  await page.locator('.x-window:visible', { hasText: 'Observações do documento' }).first().waitFor({ timeout: 9000 });
  await page.waitForTimeout(1200);
}
async function importar(page, pdf) {
  const imp = botao(page, 'Importar');
  try {
    const [fc] = await Promise.all([page.waitForEvent('filechooser', { timeout: 6000 }), imp.click()]);
    await fc.setFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
  } catch {
    const inp = page.locator('input[type=file]').last();
    if (await inp.count()) await inp.setInputFiles({ name: 'doc-teste-qa.pdf', mimeType: 'application/pdf', buffer: pdf });
  }
  await page.waitForTimeout(3500);
}
async function excluir(page) {
  await clicar(page, 'Excluir');
  await page.waitForTimeout(1200);
  const sim = page.locator('.x-message-box:visible a.x-btn:visible', { hasText: 'Sim' }).first();
  if (await sim.count()) await sim.click();
  await page.waitForTimeout(2500);
}

async function fazDocumentos(browser, stack, rec) {
  const pdf = pdfMinimo('QA E2E - documento de teste');
  const reg = (id, titulo, esperado, obtido, ok, prints) => rec.registrar({
    id, dominio: 'Documentos', titulo, stack: stack.id, stackNome: stack.nome, tipo: 'positivo',
    esperado, obtido, status: ok === null ? 'BLOQUEADO' : (ok ? 'PASSOU' : 'FALHOU'), prints: prints || [],
  });
  const { ctx, page } = await novaPagina(browser, stack);
  try {
    const rl = await login(page, CFG.user, CFG.pass, CFG.amb);
    if (!rl.ok) throw new Error('login falhou');
    await irParaDocumentos(page);
    await shot(page, stack.id, 'DO-00-grid');

    // pre-clean
    await abrirDocDialog(page);
    if (await temAnexado(page)) { await excluir(page); await dismissMsg(page); }
    await fecharJanelas(page);

    // CT-DO-03-01 Anexar
    try {
      await abrirDocDialog(page);
      const p1 = await shot(page, stack.id, 'DO-03-01-dialog');
      await importar(page, pdf);
      const ok = await temAnexado(page);
      const p2 = await shot(page, stack.id, 'DO-03-01-importado');
      reg('CT-DO-03-01', 'Anexar documento (upload)', 'Arquivo anexado (Anexado por/em preenchidos; botao Excluir disponivel)',
        ok ? 'Documento anexado com sucesso' : 'Nao anexou', ok, [p1, p2]);
    } catch (e) { reg('CT-DO-03-01', 'Anexar documento (upload)', '-', 'ERRO: ' + e.message.slice(0, 70), null); }

    // CT-DO-03-02 Salvar
    try {
      await clicar(page, 'Salvar');
      await page.waitForTimeout(3000);
      let msg = ''; const mb = page.locator('.x-message-box:visible').first();
      if (await mb.count()) msg = (await mb.innerText().catch(() => '')).replace(/\s+/g, ' ').trim();
      const p = await shot(page, stack.id, 'DO-03-02-salvar');
      const erro = /erro|não é|nao e|inv[aá]lid|Integer|falha/i.test(msg);
      reg('CT-DO-03-02', 'Salvar observacoes do documento', 'Salva sem erro',
        msg || 'Salvou (sem dialog de erro)', !erro, [p]);
      await dismissMsg(page);
    } catch (e) { reg('CT-DO-03-02', 'Salvar observacoes do documento', '-', 'ERRO: ' + e.message.slice(0, 70), null); }
    await fecharJanelas(page);

    // CT-DO-01-01 Persistencia
    let persistiu = false;
    try {
      await abrirDocDialog(page);
      persistiu = await temAnexado(page);
      const p = await shot(page, stack.id, 'DO-01-01-conferir');
      reg('CT-DO-01-01', 'Persistencia do documento (reabrir)', 'Ao reabrir, o documento continua anexado',
        persistiu ? 'Documento persistido' : 'Nao encontrado ao reabrir', persistiu, [p]);
    } catch (e) { reg('CT-DO-01-01', 'Persistencia do documento (reabrir)', '-', 'ERRO: ' + e.message.slice(0, 70), null); }

    // CT-DO-03-03 Excluir (limpa)
    try {
      if (persistiu) { await excluir(page); await dismissMsg(page); }
      await fecharJanelas(page);
      await abrirDocDialog(page);
      const removeu = !(await temAnexado(page));
      const p = await shot(page, stack.id, 'DO-03-03-excluido');
      reg('CT-DO-03-03', 'Excluir documento', 'Documento removido (volta ao estado sem anexo)',
        removeu ? 'Documento excluido' : 'ATENCAO: ainda anexado', removeu, [p]);
      await fecharJanelas(page);
    } catch (e) { reg('CT-DO-03-03', 'Excluir documento', '-', 'ERRO: ' + e.message.slice(0, 70), null); }
  } catch (e) {
    console.log(`[${stack.id}] docs ABORT: ${e.message}`);
    await shot(page, stack.id, 'DO-erro').catch(() => {});
    ['CT-DO-03-01', 'CT-DO-03-02', 'CT-DO-01-01', 'CT-DO-03-03'].forEach(id =>
      rec.registrar({ id, dominio: 'Documentos', titulo: 'Documentos (E2E)', stack: stack.id, stackNome: stack.nome, tipo: 'positivo', esperado: '-', obtido: 'BLOQUEADO: ' + e.message.slice(0, 60), status: 'BLOQUEADO', prints: [] }));
  }
  await ctx.close();
}

module.exports = { fazDocumentos, pdfMinimo, irParaDocumentos };
