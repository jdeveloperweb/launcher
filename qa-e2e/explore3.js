// Dump direcionado: campos da troca de senha + combos do filtro de operacoes.
const { chromium } = require('playwright');
const AMB = '/u10/c6bank/suporte/scat112934', USER = 'supervisor', PASS = 'Tempo+2024';
const URL = 'https://desenv.prognum.com.br/aejs/';

(async () => {
  const b = await chromium.launch({ headless: true });
  const ctx = await b.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1600, height: 900 } });
  const p = await ctx.newPage();
  await p.goto(URL, { waitUntil: 'networkidle', timeout: 30000 });
  await p.fill('input[name="name"]', USER); await p.fill('input[name="password"]', PASS); await p.fill('input[name="ambienteOperacional"]', AMB);
  await p.click('text="Login"'); await p.waitForSelector('text=Sair', { timeout: 20000 }); await p.waitForTimeout(1200);

  // troca senha
  await p.click('text="supervisor"'); await p.waitForTimeout(1000);
  await p.click('text=/Troca Senha/i'); await p.waitForTimeout(1200);
  const win = p.locator('.x-window', { hasText: 'Troca de senha do Usuário' }).first();
  const ins = await win.locator('input').evaluateAll(ns => ns.map(e => ({ type: e.type, name: e.name, id: e.id })));
  console.log('TROCA SENHA inputs:', JSON.stringify(ins));
  const btns = await win.locator('a.x-btn').evaluateAll(ns => ns.map(e => (e.innerText || '').trim()).filter(Boolean));
  console.log('TROCA SENHA botoes:', JSON.stringify(btns));
  await p.click('text="Cancelar"').catch(() => {});
  await p.waitForTimeout(500);
  await p.click('text="Fechar tela"').catch(() => {});
  await p.waitForTimeout(500);

  // originacao -> cadastro operacoes
  await p.click('text="Originação"'); await p.waitForTimeout(1200);
  await p.click('text=/Cadastro de opera/i'); await p.waitForTimeout(2500);
  const combos = await p.locator('input[name]').evaluateAll(ns => ns.map(e => ({ type: e.type, name: e.name, val: e.value })).filter(x => x.name));
  console.log('FILTRO inputs:', JSON.stringify(combos));
  // abre combo periodo (procura por rotulo)
  const per = p.locator('input').filter({ hasNot: p.locator('[readonly]') });
  await b.close();
  console.log('OK explore3');
})();
