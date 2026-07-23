// Evidencia E2E do LOG DE EVENTOS pelo front (/aejs-l, caixa/Oracle):
// gera LOGIN INCORRETO (1 senha errada), ENTRADA (login ok), SAIDA (logout),
// depois abre Manutencao->Gerenciar logs->Consultar e printa o grid com os 3 eventos frescos.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');

const URL = 'https://desenv.prognum.com.br/aejs-l/';
const AMB = '/u11/caixa/dados';
const USER = 'supervisor', PASS = 'Tempo+2023', PASS_ERRADA = 'ErradaDeProposito#1';
const OUT = path.join(__dirname, 'evidencias', 'log-eventos-e2e'); fs.mkdirSync(OUT, { recursive: true });

async function preencher(page, user, pass) {
  await page.goto(URL, { waitUntil: 'networkidle', timeout: 35000 });
  await page.fill('input[name="name"]', user);
  await page.fill('input[name="password"]', pass);
  await page.fill('input[name="ambienteOperacional"]', AMB);
}
async function clickTexto(page, txt, timeout = 8000) {
  const el = page.locator(`text="${txt}"`).first();
  await el.waitFor({ state: 'visible', timeout });
  await el.click();
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1600, height: 900 } });
  const page = await ctx.newPage();

  // 1) LOGIN INCORRETO (1 tentativa errada -> loginerr/LOGINERR)
  await preencher(page, USER, PASS_ERRADA);
  await page.click('text="Login"');
  let msgErro = '';
  try {
    await page.waitForSelector('.x-message-box:visible, .x-window:visible', { timeout: 12000 });
    msgErro = (await page.locator('.x-message-box:visible, .x-window:visible').first().innerText()).replace(/\s+/g, ' ').slice(0, 90);
  } catch {}
  await page.screenshot({ path: path.join(OUT, '01-login-incorreto.png') });
  console.log('LOGIN INCORRETO ->', msgErro || '(sem dialog)');
  const okb = page.locator('.x-message-box:visible a:has-text("OK")').first();
  if (await okb.count()) await okb.click().catch(() => {});
  await page.waitForTimeout(800);

  // 2) LOGIN OK (ENTRADA) — tambem zera o contador de tentativas
  await preencher(page, USER, PASS);
  await page.click('text="Login"');
  await page.waitForSelector('text=/Sair/i', { timeout: 20000 });
  console.log('ENTRADA -> login OK');
  await page.waitForTimeout(1200);

  // 3) SAIDA (logout via Sair -> /w/logoff)
  await page.click('text=/Sair/i').catch(() => {});
  await page.waitForTimeout(3000);
  console.log('SAIDA -> logout disparado');

  // 4) Novo login e abre a tela de log pra printar o grid com os 3 eventos frescos
  await preencher(page, USER, PASS);
  await page.click('text="Login"');
  await page.waitForSelector('text=/Sair/i', { timeout: 20000 });
  await clickTexto(page, 'Manutenção'); await page.waitForTimeout(800);
  await clickTexto(page, 'Gerenciar logs de eventos'); await page.waitForTimeout(1500);
  try { await clickTexto(page, 'Consultar', 6000); } catch {}
  await page.waitForTimeout(3500);
  await page.screenshot({ path: path.join(OUT, '02-grid-eventos.png'), fullPage: true });

  const linhas = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll('.x-grid-row, .x-grid-item')).slice(0, 10);
    const vistos = new Set();
    const out = [];
    for (const r of rows) {
      const t = (r.innerText || '').replace(/\s+/g, ' ').trim();
      if (t && !vistos.has(t)) { vistos.add(t); out.push(t.slice(0, 110)); }
    }
    return out.slice(0, 8);
  });
  console.log('--- grid de log (topo) ---');
  linhas.forEach((l, i) => console.log(`${i + 1}: ${l}`));

  await browser.close();
  console.log('prints em evidencias/log-eventos-e2e/');
})().catch(e => { console.error('ERRO:', e.message); process.exit(1); });
