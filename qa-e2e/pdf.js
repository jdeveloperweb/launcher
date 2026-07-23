// Renderiza o relatorio HTML em PDF (Chromium do Playwright), tema claro, sem quebras feias.
const { chromium } = require('playwright');
const path = require('path');

(async () => {
  const file = path.join(__dirname, 'relatorio-evidencias.html').replace(/\\/g, '/');
  const out = path.join(__dirname, 'relatorio-evidencias.pdf');
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file:///' + file, { waitUntil: 'load' });
  await page.evaluate(() => document.documentElement.setAttribute('data-theme', 'light'));
  await page.addStyleTag({ content: `
    .lb{display:none !important}
    .caso, .stat, .scopebox, pre.evid, .thumb, article { break-inside: avoid; }
    section.dom > h2 { break-after: avoid; }
    body { background: #fff; }
  ` });
  await page.emulateMedia({ media: 'screen', colorScheme: 'light' });
  await page.waitForTimeout(400);
  await page.pdf({
    path: out, format: 'A4', printBackground: true, scale: 0.82,
    margin: { top: '10mm', bottom: '12mm', left: '8mm', right: '8mm' },
    displayHeaderFooter: true, headerTemplate: '<span></span>',
    footerTemplate: '<div style="width:100%;font-size:8px;color:#8492a0;padding:0 10mm;text-align:right;">Evidências E2E — SCCI Launcher · pág. <span class="pageNumber"></span>/<span class="totalPages"></span></div>',
  });
  await browser.close();
  const kb = Math.round(require('fs').statSync(out).size / 1024);
  console.log('PDF gerado:', out, '(' + kb + ' KB)');
})();
