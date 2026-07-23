// Validacao rapida do fluxo de login (valido + senha errada) nos 2 stacks.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');

const AMB = '/u10/c6bank/suporte/scat112934';
const USER = 'supervisor', PASS = 'Tempo+2024';
const STACKS = [
  { id: 'pascal', url: 'https://desenv.prognum.com.br/aejs/' },
  { id: 'java', url: 'https://desenv.prognum.com.br/aejs-l/' },
];
const OUT = path.join(__dirname, 'evidencias', 'login'); fs.mkdirSync(OUT, { recursive: true });

async function preencher(page, url, user, pass, amb) {
  await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
  await page.fill('input[name="name"]', user);
  await page.fill('input[name="password"]', pass);
  await page.fill('input[name="ambienteOperacional"]', amb);
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  for (const s of STACKS) {
    // ---- login valido
    let ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1366, height: 768 } });
    let page = await ctx.newPage();
    await preencher(page, s.url, USER, PASS, AMB);
    await page.screenshot({ path: path.join(OUT, `${s.id}-01-preenchido.png`) });
    await page.click('text="Login"');
    let outcome = 'indefinido';
    try {
      await page.waitForSelector('text=/Sair/i', { timeout: 18000 });
      outcome = 'SUCESSO (menu carregado)';
    } catch {
      try { outcome = 'SEM SUCESSO: ' + (await page.locator('.x-message-box, .x-window').first().innerText()).replace(/\s+/g, ' ').slice(0, 90); }
      catch { outcome = 'SEM SUCESSO (sem menu / sem msgbox)'; }
    }
    await page.waitForTimeout(1200);
    await page.screenshot({ path: path.join(OUT, `${s.id}-02-pos-login.png`), fullPage: true });
    console.log(`[${s.id}] login VALIDO   -> ${outcome}`);
    await ctx.close();

    // ---- senha errada
    ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1366, height: 768 } });
    page = await ctx.newPage();
    await preencher(page, s.url, USER, 'SenhaErrada#000', AMB);
    await page.click('text="Login"');
    let out2 = 'sem retorno detectado';
    try {
      await page.waitForSelector('.x-message-box, .x-window', { timeout: 10000 });
      out2 = (await page.locator('.x-message-box, .x-window').first().innerText()).replace(/\s+/g, ' ').slice(0, 120);
    } catch { /* pode nao abrir msgbox */ }
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(OUT, `${s.id}-03-senha-errada.png`), fullPage: true });
    console.log(`[${s.id}] senha ERRADA   -> ${out2}`);
    await ctx.close();
  }
  await browser.close();
  console.log('OK: prints em evidencias/login/');
})();
