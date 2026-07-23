// Rasteriza o comparativo de arquitetura (HTML+SVG do scratchpad) para PNG em 2x.
const { chromium } = require('playwright');
const SCR = 'C:/Users/JAIME~1.VIC/AppData/Local/Temp/claude/c--Users-Jaime-Vicente-Projetos-launcher-java-launcher/c8cb6d21-1e60-4dcd-883c-4ee46f71dd82/scratchpad';
const W = 1760, H = 1200;
(async () => {
  const b = await chromium.launch({ headless: true });
  const p = await b.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 2 });
  await p.goto('file:///' + SCR + '/arquitetura-tradeoffs.html', { waitUntil: 'networkidle' });
  await p.screenshot({ path: SCR + '/arquitetura-tradeoffs.png', clip: { x: 0, y: 0, width: W, height: H } });
  await b.close();
  console.log('PNG 2x gerado em', SCR + '/arquitetura-tradeoffs.png');
})().catch(e => { console.error('ERRO:', e.message); process.exit(1); });
