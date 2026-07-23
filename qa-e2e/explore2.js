// Exploracao das telas internas (troca de senha + originacao/cadastro de operacoes) para seletores.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const OUT = path.join(__dirname, 'evidencias', 'explore2'); fs.mkdirSync(OUT, { recursive: true });
const AMB = '/u10/c6bank/suporte/scat112934', USER = 'supervisor', PASS = 'Tempo+2024';
const URL = 'https://desenv.prognum.com.br/aejs/'; // referencia Pascal

async function dump(scope, label) {
  const els = await scope.$$eval('input,button,a,span.x-btn-inner,div.x-menu-item-text', ns => ns.map(e => ({
    tag: e.tagName, type: e.getAttribute('type') || '', name: e.getAttribute('name') || '', id: e.id || '',
    txt: (e.innerText || '').trim().slice(0, 34)
  })).filter(x => x.txt || x.name)).catch(() => []);
  console.log(`\n--- ${label} (${els.length}) ---`);
  els.slice(0, 70).forEach(i => console.log('  ', JSON.stringify(i)));
}

(async () => {
  const b = await chromium.launch({ headless: true });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1600, height: 900 } });
  const p = await ctx.newPage();
  await p.goto(URL, { waitUntil: 'networkidle', timeout: 30000 });
  await p.fill('input[name="name"]', USER); await p.fill('input[name="password"]', PASS); await p.fill('input[name="ambienteOperacional"]', AMB);
  await p.click('text="Login"');
  await p.waitForSelector('text=Sair', { timeout: 20000 });
  await p.waitForTimeout(1500);

  // ---- troca senha
  await p.click('text="supervisor"');
  await p.waitForTimeout(1500);
  await p.screenshot({ path: path.join(OUT, '02-user-panel.png') });
  await dump(p, 'user panel');
  await p.click('text=/Troca Senha/i').catch(e => console.log('click troca senha:', e.message));
  await p.waitForTimeout(1500);
  await p.screenshot({ path: path.join(OUT, '03-troca-senha.png') });
  await dump(p, 'troca senha form');
  const fechar = p.locator('text=/Fechar tela/i').first();
  if (await fechar.count()) await fechar.click().catch(() => {});
  await p.waitForTimeout(600);

  // ---- originacao -> cadastro de operacoes
  await p.click('text="Originação"');
  await p.waitForTimeout(1500);
  await p.screenshot({ path: path.join(OUT, '04-originacao-menu.png') });
  await dump(p, 'originacao menu');
  await p.click('text=/Cadastro de opera/i').catch(e => console.log('click cad op:', e.message));
  await p.waitForTimeout(3000);
  await p.screenshot({ path: path.join(OUT, '05-cad-operacoes.png'), fullPage: true });
  await dump(p, 'cad operacoes');

  await b.close();
  console.log('\nOK explore2 -> evidencias/explore2/');
})();
