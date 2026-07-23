const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const file = path.join(__dirname, 'relatorio-evidencias.html').replace(/\\/g, '/');
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 940, height: 1360 } });
  await p.goto('file:///' + file, { waitUntil: 'load' });
  await p.evaluate(() => document.documentElement.setAttribute('data-theme', 'light'));
  await p.waitForTimeout(400);
  await p.screenshot({ path: path.join(__dirname, 'evidencias', 'verify-look.png') });
  await b.close();
  console.log('ok');
})();
