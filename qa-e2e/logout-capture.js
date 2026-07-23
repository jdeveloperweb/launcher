// Captura QUAL url o "Sair" do front chama no /aejs-l (para descobrir por que a SAIDA nao registra).
const { chromium } = require('playwright');
const path = require('path');

const URL = 'https://desenv.prognum.com.br/aejs-l/';
const AMB = '/u11/caixa/dados';
const USER = 'supervisor', PASS = 'Tempo+2023';

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 810 } });
  const page = await ctx.newPage();

  await page.goto(URL, { waitUntil: 'networkidle', timeout: 35000 });
  await page.fill('input[name="name"]', USER);
  await page.fill('input[name="password"]', PASS);
  await page.fill('input[name="ambienteOperacional"]', AMB);
  await page.click('text="Login"');
  await page.waitForSelector('text=/Sair/i', { timeout: 20000 });
  console.log('login OK — capturando requests do logout...');

  const reqs = [];
  const interessa = (u) => !/\.(js|css|png|jpg|jpeg|gif|svg|woff2?|ico)(\?|$)/i.test(u);
  page.on('request', r => { if (interessa(r.url())) reqs.push({ m: r.method(), u: r.url() }); });
  const respStatus = {};
  page.on('response', r => { if (interessa(r.url())) respStatus[r.url()] = r.status(); });

  // clica Sair e aguarda a navegacao/efeito
  await page.click('text=/Sair/i').catch(() => {});
  await page.waitForTimeout(4000);
  // confirma dialog se houver (Sim/OK/Confirmar)
  for (const t of ['Sim', 'OK', 'Confirmar', 'Yes']) {
    const b = page.locator(`.x-message-box:visible a:has-text("${t}"), .x-btn:visible:has-text("${t}")`).first();
    if (await b.count()) { await b.click().catch(() => {}); await page.waitForTimeout(2500); break; }
  }
  await page.waitForTimeout(2000);

  console.log('--- requests (nao-estaticos) durante o logout ---');
  for (const r of reqs) {
    const s = respStatus[r.u] != null ? respStatus[r.u] : '?';
    console.log(`  [${s}] ${r.m} ${r.u}`);
  }
  console.log('URL atual apos Sair:', page.url());
  await browser.close();
})().catch(e => { console.error('ERRO:', e.message); process.exit(1); });
