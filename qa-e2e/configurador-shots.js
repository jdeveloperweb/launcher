// Screenshots do Configurador SCCI (via túnel localhost:8095) para o relatório de evidências.
const { chromium } = require('playwright');
const fs = require('fs'); const path = require('path');
const URL='http://localhost:8095/', USER='admin', PASS='1f873a78c711';
const OUT=path.join(__dirname,'evidencias','configurador'); fs.mkdirSync(OUT,{recursive:true});
async function shot(page,n){ await page.screenshot({path:path.join(OUT,n+'.png'),fullPage:false}); }
(async()=>{
  const b=await chromium.launch({headless:true});
  const ctx=await b.newContext({viewport:{width:1500,height:900}}); const p=await ctx.newPage();
  await p.goto(URL,{waitUntil:'networkidle',timeout:20000});
  // login
  await p.fill('#lu',USER); await p.fill('#lp',PASS); await p.click('#lbtn');
  await p.waitForSelector('#app:not(.hidden)',{timeout:12000});
  await p.waitForTimeout(3500);                              // deixa as métricas agregarem do stream
  await shot(p,'01-metricas'); console.log('metricas ok');
  // sessões
  await p.click('.nav a[data-view="sessions"]'); await p.waitForTimeout(2500);
  await shot(p,'02-sessoes'); console.log('sessoes ok');
  // logs
  await p.click('.nav a[data-view="logs"]'); await p.waitForTimeout(3000);
  await shot(p,'03-logs'); console.log('logs ok');
  // config
  await p.click('.nav a[data-view="config"]'); await p.waitForTimeout(2000);
  await shot(p,'04-config'); console.log('config ok');
  await b.close(); console.log('shots em evidencias/configurador/');
})().catch(e=>{console.error('ERRO:',e.message);process.exit(1);});
