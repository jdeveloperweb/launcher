// Prova definitiva pelo FRONT: apos logar no /aejs-l (caixa), abre Manutencao ->
// Gerenciar logs de eventos -> Consultar e le a linha de topo (deve haver ENTRADA nova de hoje).
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');

const URL = 'https://desenv.prognum.com.br/aejs-l/';
const AMB = '/u11/caixa/dados';
const USER = 'supervisor', PASS = 'Tempo+2023';
const OUT = path.join(__dirname, 'evidencias', 'log-ui-caixa'); fs.mkdirSync(OUT, { recursive: true });

async function clickTexto(page, txt, timeout = 8000) {
  const el = page.locator(`text="${txt}"`).first();
  await el.waitFor({ state: 'visible', timeout });
  await el.click();
}

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1600, height: 900 } });
  const page = await ctx.newPage();

  await page.goto(URL, { waitUntil: 'networkidle', timeout: 35000 });
  await page.fill('input[name="name"]', USER);
  await page.fill('input[name="password"]', PASS);
  await page.fill('input[name="ambienteOperacional"]', AMB);
  await page.click('text="Login"');
  await page.waitForSelector('text=/Sair/i', { timeout: 20000 });
  console.log('login OK');

  // Manutencao -> Gerenciar logs de eventos
  await clickTexto(page, 'Manutenção');
  await page.waitForTimeout(800);
  await clickTexto(page, 'Gerenciar logs de eventos');
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, '01-tela-log.png'), fullPage: true });

  // Consultar (carrega o grid)
  try { await clickTexto(page, 'Consultar', 6000); } catch { console.log('botao Consultar nao encontrado (grid pode ja vir carregado)'); }
  await page.waitForTimeout(3500);
  await page.screenshot({ path: path.join(OUT, '02-grid-consultado.png'), fullPage: true });

  // Le as primeiras linhas do grid (Data/Hora/Usuario/Aplicacao)
  const linhas = await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll('.x-grid-row, .x-grid-item, table.x-grid-item tr')).slice(0, 8);
    return rows.map(r => (r.innerText || '').replace(/\s+/g, ' ').trim()).filter(Boolean).slice(0, 8);
  });
  console.log('--- topo do grid de log ---');
  linhas.forEach((l, i) => console.log(`${i + 1}: ${l.slice(0, 120)}`));

  await browser.close();
  console.log('prints em evidencias/log-ui-caixa/');
})().catch(e => { console.error('ERRO:', e.message); process.exit(1); });
