// Valida o log de eventos pelo FRONT no Java (/aejs-l), ambiente caixa:
// login (LOGON/ENTRADA) + logout (LOGOFF/SAIDA) -> o pascal-executor deve rodar o sccilog.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');

const URL = 'https://desenv.prognum.com.br/aejs-l/';
const AMB = '/u11/caixa/dados';
const USER = 'supervisor', PASS = 'Tempo+2023';
const OUT = path.join(__dirname, 'evidencias', 'log-caixa'); fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 810 } });
  const page = await ctx.newPage();

  await page.goto(URL, { waitUntil: 'networkidle', timeout: 35000 });
  await page.fill('input[name="name"]', USER);
  await page.fill('input[name="password"]', PASS);
  await page.fill('input[name="ambienteOperacional"]', AMB);
  await page.screenshot({ path: path.join(OUT, '01-preenchido.png') });

  const tLogin = new Date().toISOString();
  await page.click('text="Login"');
  let logado = false;
  try { await page.waitForSelector('text=/Sair/i', { timeout: 20000 }); logado = true; } catch {}
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, '02-pos-login.png'), fullPage: true });
  console.log(`LOGIN  (${tLogin}) -> ${logado ? 'SUCESSO (menu carregado)' : 'FALHOU'}`);

  if (logado) {
    // LOGOUT -> deve disparar LOGOFF (SAIDA) + eliminar a sessao
    await page.click('text=/Sair/i').catch(() => {});
    await page.waitForTimeout(2500);
    // confirma dialog de saida se houver
    const ok = page.locator('.x-message-box:visible a:has-text("Sim"), .x-message-box:visible a:has-text("OK")').first();
    if (await ok.count()) await ok.click().catch(() => {});
    await page.waitForTimeout(2000);
    await page.screenshot({ path: path.join(OUT, '03-pos-logout.png'), fullPage: true });
    console.log('LOGOUT -> disparado');
  }

  await browser.close();
  console.log('prints em evidencias/log-caixa/');
})().catch(e => { console.error('ERRO:', e.message); process.exit(1); });
