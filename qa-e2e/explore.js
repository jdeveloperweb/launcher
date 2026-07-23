// Exploracao do DOM das telas de login (Pascal x Java) para construir seletores.
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, 'evidencias', 'explore');
fs.mkdirSync(OUT, { recursive: true });

const TARGETS = [
  { id: 'pascal', url: 'https://desenv.prognum.com.br/aejs/' },
  { id: 'java', url: 'https://desenv.prognum.com.br/aejs-l/' },
];

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1366, height: 768 } });
  const page = await ctx.newPage();
  for (const t of TARGETS) {
    try {
      await page.goto(t.url, { waitUntil: 'networkidle', timeout: 30000 });
    } catch (e) {
      console.log(`[${t.id}] goto aviso: ${e.message}`);
    }
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(OUT, `${t.id}-login.png`), fullPage: true });
    console.log(`\n===== ${t.id} :: ${page.url()} =====`);
    console.log('title:', await page.title());
    console.log('frames:', page.frames().length);
    for (const f of page.frames()) {
      const els = await f.$$eval('input, button, a', nodes => nodes.map(e => ({
        tag: e.tagName, type: e.getAttribute('type') || '', name: e.getAttribute('name') || '',
        id: e.id || '', ph: e.getAttribute('placeholder') || '',
        val: (e.value || '').slice(0, 24), txt: (e.innerText || '').trim().slice(0, 28)
      }))).catch(() => []);
      if (els.length) {
        console.log(`-- frame [${f.name() || 'main'}] ${f.url()} --`);
        els.forEach(i => console.log('   ', JSON.stringify(i)));
      }
    }
  }
  await browser.close();
  console.log('\nOK: screenshots em evidencias/explore/');
})();
