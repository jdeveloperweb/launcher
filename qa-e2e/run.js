// Harness de evidencias: reproduz os fluxos IN-SCOPE no Pascal e no Java, captura prints
// e grava resultado.json. Fase atual: Login + Troca de senha (validacoes negativas seguras).
const L = require('./lib');
const { chromium, CFG, Recorder, shot, novaPagina, login, fecharDialog } = L;

async function resultadoTroca(page, troca) {
  await page.waitForTimeout(3500);
  let msg = '';
  const mb = page.locator('.x-message-box:visible').first();
  if (await mb.count()) msg = (await mb.innerText().catch(() => '')).replace(/\s+/g, ' ').trim();
  const aberta = await troca.isVisible().catch(() => false);
  const sucesso = /sucesso|alterad|trocad/i.test(msg);
  return { msg, aberta, sucesso };
}

async function abrirTrocaSenha(page) {
  const troca = page.locator('.x-window', { hasText: 'Troca de senha do Usuário' }).first();
  if (await troca.isVisible().catch(() => false)) return troca;
  await page.click('text="supervisor"'); await page.waitForTimeout(1000);
  await page.click('text=/Troca Senha/i');
  await troca.waitFor({ timeout: 9000 });
  await page.waitForTimeout(500);
  return troca;
}

(async () => {
  const rec = new Recorder();
  const browser = await chromium.launch({ headless: true });

  for (const stack of CFG.stacks) {
    // ================= LOGIN =================
    // CT-AC-01-01 login valido
    {
      const { ctx, page } = await novaPagina(browser, stack);
      await L.preencherLogin(page, CFG.user, CFG.pass, CFG.amb);
      const p1 = await shot(page, stack.id, 'AC01-01-preenchido');
      const r = await L.submeterLogin(page);
      await page.waitForTimeout(1200);
      const p2 = await shot(page, stack.id, 'AC01-01-resultado');
      rec.registrar({
        id: 'CT-AC-01-01', dominio: 'Acesso', titulo: 'Login com credencial valida', stack: stack.id, stackNome: stack.nome,
        tipo: 'positivo', esperado: 'Autentica e carrega o menu principal',
        obtido: r.ok ? 'Login efetuado, menu carregado (Sair visivel)' : ('Nao logou: ' + (r.msg || '')),
        status: r.ok ? 'PASSOU' : 'FALHOU', prints: [p1, p2],
      });
      await ctx.close();
    }
    // CT-AC-01-02 senha incorreta
    {
      const { ctx, page } = await novaPagina(browser, stack);
      await L.preencherLogin(page, CFG.user, 'SenhaErrada#000', CFG.amb);
      const r = await L.submeterLogin(page);
      await page.waitForTimeout(800);
      const p = await shot(page, stack.id, 'AC01-02-senha-errada');
      rec.registrar({
        id: 'CT-AC-01-02', dominio: 'Acesso', titulo: 'Login com senha incorreta', stack: stack.id, stackNome: stack.nome,
        tipo: 'negativo', esperado: 'Rejeita o acesso; nao carrega o menu',
        obtido: !r.ok ? ('Acesso negado' + (r.msg ? ': ' + r.msg : '')) : 'ATENCAO: logou com senha errada',
        status: !r.ok ? 'PASSOU' : 'FALHOU', prints: [p],
      });
      await ctx.close();
    }

    // ================= TROCA DE SENHA (negativas seguras) =================
    {
      const { ctx, page } = await novaPagina(browser, stack);
      const rl = await login(page, CFG.user, CFG.pass, CFG.amb);
      if (!rl.ok) {
        for (const id of ['CT-AC-04-04', 'CT-AC-04-06']) {
          rec.registrar({ id, dominio: 'Acesso', titulo: 'Troca de senha (validacao)', stack: stack.id, stackNome: stack.nome, tipo: 'negativo', esperado: '-', obtido: 'BLOQUEADO: login falhou', status: 'BLOQUEADO', prints: [] });
        }
        await ctx.close(); continue;
      }

      // CT-AC-04-04: senha atual incorreta (nova senha forte -> mas atual errada bloqueia; senha NAO muda)
      let troca = await abrirTrocaSenha(page);
      await page.fill('input[name="senhaAtual"]', 'ErradaAtual#9');
      await page.fill('input[name="novaSenha"]', 'NovaSenha#2099');
      await page.fill('input[name="repetirSenha"]', 'NovaSenha#2099');
      const pa = await shot(page, stack.id, 'AC04-04-atual-errada');
      await troca.locator('a.x-btn:has-text("Ok")').click();
      let res = await resultadoTroca(page, troca);
      const pr = await shot(page, stack.id, 'AC04-04-atual-errada-resultado');
      rec.registrar({
        id: 'CT-AC-04-04', dominio: 'Acesso', titulo: 'Troca de senha - senha atual incorreta', stack: stack.id, stackNome: stack.nome,
        tipo: 'negativo', esperado: 'Rejeita a troca (senha atual nao confere); senha inalterada',
        obtido: res.sucesso ? 'ALERTA: troca efetuada' : (res.msg || (res.aberta ? 'Rejeitado (janela permaneceu / validacao)' : 'Rejeitado')),
        status: res.sucesso ? 'FALHOU' : 'PASSOU', prints: [pa, pr],
      });
      await fecharDialog(page);

      // CT-AC-04-06: confirmacao divergente (Nova != Repita) -> 100% seguro (nunca troca)
      troca = await abrirTrocaSenha(page);
      await page.fill('input[name="senhaAtual"]', CFG.pass);
      await page.fill('input[name="novaSenha"]', 'NovaSenha#Aaa1');
      await page.fill('input[name="repetirSenha"]', 'Diferente#Bbb2');
      const pb = await shot(page, stack.id, 'AC04-06-mismatch');
      await troca.locator('a.x-btn:has-text("Ok")').click();
      res = await resultadoTroca(page, troca);
      const pr2 = await shot(page, stack.id, 'AC04-06-mismatch-resultado');
      rec.registrar({
        id: 'CT-AC-04-06', dominio: 'Acesso', titulo: 'Troca de senha - confirmacao divergente', stack: stack.id, stackNome: stack.nome,
        tipo: 'negativo', esperado: 'Rejeita (Nova Senha != Repita a senha); senha inalterada',
        obtido: res.sucesso ? 'ALERTA: troca efetuada' : (res.msg || (res.aberta ? 'Rejeitado (validacao no cliente / janela permaneceu)' : 'Rejeitado')),
        status: res.sucesso ? 'FALHOU' : 'PASSOU', prints: [pb, pr2],
      });
      await fecharDialog(page);
      await ctx.close();
    }
  }

  await browser.close();
  console.log('\nFase login+troca-senha concluida.');
})();
