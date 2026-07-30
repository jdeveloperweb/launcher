#!/usr/bin/env node
/* Bundler do Configurador SCCI.
   Gera um configurador.bundle.js AUTOCONTIDO: server.js + index.html + logo.png embutidos.
   Distribuicao vira 1 arquivo -> `node configurador.bundle.js`. Uso: `node bundle.js`. */
'use strict';
var fs = require('fs'), path = require('path'), DIR = __dirname;

function read(f, enc) { return fs.readFileSync(path.join(DIR, f), enc); }

var server = read('server.js', 'utf8');
var html   = read('index.html', 'utf8');
var logoB64 = '';
try { logoB64 = read('logo.png').toString('base64'); } catch (e) { console.warn('aviso: logo.png ausente — bundle sem logo'); }

var injected = 'var EMBED = { html: ' + JSON.stringify(html) + ', logo: ' + JSON.stringify(logoB64) + ' };';
var out = server.replace(/\/\*__EMBED_START__\*\/[\s\S]*?\/\*__EMBED_END__\*\//, '/*__EMBED_START__*/ ' + injected + ' /*__EMBED_END__*/');
if (out === server) { console.error('ERRO: marcador __EMBED_START__/__EMBED_END__ nao encontrado no server.js'); process.exit(1); }

var dest = path.join(DIR, 'configurador.bundle.js');
fs.writeFileSync(dest, out);
console.log('OK -> configurador.bundle.js  (' + (out.length / 1024 | 0) + ' KB | html ' + (html.length / 1024 | 0) + ' KB | logo ' + (logoB64.length / 1024 | 0) + ' KB b64)');
console.log('teste:  node configurador.bundle.js   ->  http://localhost:8095');
