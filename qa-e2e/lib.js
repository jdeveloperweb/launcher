// Helpers compartilhados do harness de evidencias (Pascal x Java).
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const EVID = path.join(__dirname, 'evidencias');
const CFG = {
  amb: '/u10/c6bank/suporte/scat112934',
  user: 'supervisor',
  pass: 'Tempo+2024',
  proposta: '000000075',
  stacks: [
    { id: 'pascal', nome: 'Launcher Pascal (/aejs)', url: 'https://desenv.prognum.com.br/aejs/' },
    { id: 'java', nome: 'Launcher Java (/aejs-l)', url: 'https://desenv.prognum.com.br/aejs-l/' },
  ],
};

// ---------- gravador de resultados ----------
class Recorder {
  constructor() {
    this.arqCasos = path.join(EVID, 'resultado.json');
    this.casos = fs.existsSync(this.arqCasos) ? (JSON.parse(fs.readFileSync(this.arqCasos, 'utf8')).casos || []) : [];
  }
  registrar(c) {
    // substitui caso com mesmo id+stack (idempotente ao re-rodar)
    this.casos = this.casos.filter(x => !(x.id === c.id && x.stack === c.stack));
    this.casos.push(c);
    fs.writeFileSync(this.arqCasos, JSON.stringify({ geradoEmISO: new Date().toISOString(), casos: this.casos }, null, 2));
    const icon = c.status === 'PASSOU' ? 'OK ' : c.status === 'FALHOU' ? 'XX ' : '.. ';
    console.log(`${icon}[${c.stack}] ${c.id} ${c.titulo} -> ${c.status}${c.obtido ? ' :: ' + c.obtido.slice(0, 70) : ''}`);
    return c;
  }
}

async function shot(page, stackId, nome) {
  const dir = path.join(EVID, 'casos', stackId);
  fs.mkdirSync(dir, { recursive: true });
  const rel = ['casos', stackId, nome + '.png'].join('/');
  await page.screenshot({ path: path.join(EVID, rel) });
  return rel;
}

// ---------- navegacao ----------
async function novaPagina(browser, stack) {
  const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1600, height: 900 } });
  const page = await ctx.newPage();
  await page.goto(stack.url, { waitUntil: 'networkidle', timeout: 35000 });
  return { ctx, page };
}

async function preencherLogin(page, user, pass, amb) {
  await page.fill('input[name="name"]', user);
  await page.fill('input[name="password"]', pass);
  await page.fill('input[name="ambienteOperacional"]', amb);
}

// Clica Login e aguarda: sucesso (menu com "Sair") OU dialog de erro (ignora "Aguarde/Transmitindo").
async function submeterLogin(page) {
  await page.click('text="Login"');
  const inicio = Date.now();
  while (Date.now() - inicio < 22000) {
    const sair = page.locator('a:has-text("Sair")');
    if (await sair.count() && await sair.first().isVisible().catch(() => false)) return { ok: true };
    const mb = page.locator('.x-message-box:visible').first();
    if (await mb.count()) {
      const t = (await mb.innerText().catch(() => '')).replace(/\s+/g, ' ').trim();
      if (t && !/Transmitindo|Aguarde/i.test(t)) return { ok: false, msg: t };
    }
    await page.waitForTimeout(400);
  }
  return { ok: false, msg: 'sem resposta (timeout 22s)' };
}

async function login(page, user, pass, amb) {
  await preencherLogin(page, user, pass, amb);
  return submeterLogin(page);
}

// fecha qualquer message-box visivel (clica OK)
async function fecharDialog(page) {
  const ok = page.locator('.x-message-box:visible a:has-text("OK")').first();
  if (await ok.count()) await ok.click().catch(() => {});
  await page.waitForTimeout(400);
}

module.exports = { chromium, fs, path, EVID, CFG, Recorder, shot, novaPagina, preencherLogin, submeterLogin, login, fecharDialog };
