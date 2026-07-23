// Executa o fluxo de documentos. Uso: node run-docs.js [pascal|java]  (sem arg = os dois)
const L = require('./lib');
const { chromium, CFG, Recorder } = L;
const { fazDocumentos } = require('./docsflow');

(async () => {
  const alvo = process.argv[2];
  const rec = new Recorder();
  const browser = await chromium.launch({ headless: true });
  for (const stack of CFG.stacks) {
    if (alvo && stack.id !== alvo) continue;
    console.log(`\n===== DOCUMENTOS :: ${stack.nome} =====`);
    await fazDocumentos(browser, stack, rec);
  }
  await browser.close();
  console.log('\nFim documentos.');
})();
