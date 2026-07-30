#!/usr/bin/env bash
# ============================================================================
#  Sobe TODOS os serviços SCCI na desenv, integrados e na ordem certa.
#  Roda NA BOX (é enviado pelos launchers subir-desenv.bat / .sh).
#  Também pode ser rodado direto:  bash ~/subir-desenv.sh
#
#  Sobe: Configurador (:8095) -> scci-core híbrido (:8090) + puro (:8092) -> gateway (:8083).
#  O launcher (:8091) fica DOWN por padrão (o trilho 'pascal' vai pro híbrido) — o nproc=200
#  do usuário não comporta os 4 JVMs. Para subir também:  SUBIR_LAUNCHER=1 bash ~/subir-desenv.sh
# ============================================================================
set -u
ulimit -u 47000 2>/dev/null || true          # nproc alto (senão vários JVMs travam "unable to create native thread")
CFG="$HOME/configurador"
cd "$CFG" 2>/dev/null || { echo "ERRO: $CFG não existe"; exit 1; }

# 1) estado desejado — só cria se faltar (não sobrescreve as flags que você ajustou na UI)
[ -f routing.json ] || printf '%s' '{"executor":"hibrido"}' > routing.json
[ -f rotas.json ]   || printf '%s' '{"rotaDefault":"pascal","rotas":{"ping-java":"puro","wmenu":"hibrido"}}' > rotas.json

# 2) Configurador (se estiver caído), sob ulimit alto p/ os filhos herdarem
if ! curl -fs -m2 http://localhost:8095/ >/dev/null 2>&1; then
  echo "-> subindo Configurador (:8095)"
  setsid bash -c "ulimit -u 47000; exec node server.js" >> configurador.log 2>&1 </dev/null &
  for i in $(seq 1 15); do curl -fs -m2 http://localhost:8095/ >/dev/null 2>&1 && break; sleep 1; done
fi

# 3) cookie admin (lê o secret.key local) — reusa o /api/power do Configurador (mesma lógica de subida)
COOKIE=$(node -e 'var c=require("crypto"),f=require("fs");var s=f.readFileSync("secret.key");var p="admin|"+(Date.now()+3600000);process.stdout.write("sess="+Buffer.from(p).toString("base64")+"."+c.createHmac("sha256",s).update(p).digest("hex"));' 2>/dev/null)
[ -n "$COOKIE" ] || { echo "ERRO: não consegui gerar o cookie admin (secret.key?)"; exit 1; }

power(){ curl -s -m6 -H "Cookie: $COOKIE" -H "Content-Type: application/json" \
  -X POST http://localhost:8095/api/power -d "{\"svc\":\"$1\",\"action\":\"start\"}" >/dev/null; }
espera(){ for i in $(seq 1 30); do curl -fs -m2 "http://localhost:$1/actuator/health" >/dev/null 2>&1 && { echo "   $2 (:$1) UP"; return; }; sleep 2; done; echo "   $2 (:$1) NÃO subiu — veja o log"; }
sobe(){  # svc porta nome  — só sobe se estiver DOWN (idempotente, seguro re-rodar)
  if curl -fs -m2 "http://localhost:$2/actuator/health" >/dev/null 2>&1; then echo "   $3 (:$2) já UP"; return; fi
  echo "-> subindo $3 (:$2)"; power "$1"; espera "$2" "$3"; }

# 4) ordem: backends primeiro, gateway por último (ele aponta pros backends)
sobe scci     8090 "scci-core híbrido"
sobe scciPuro 8092 "scci-core puro"
sobe gateway  8083 "gateway-scci"
[ "${SUBIR_LAUNCHER:-0}" = "1" ] && sobe launcher 8091 "launcher (executor Pascal)"

echo ""; echo "======================= STATUS ======================="
for s in "Configurador:8095" "gateway-scci:8083" "scci-core-híbrido:8090" "scci-core-puro:8092"; do
  n=${s%:*}; p=${s#*:}
  if curl -fs -m2 "http://localhost:$p/" >/dev/null 2>&1 || curl -fs -m2 "http://localhost:$p/actuator/health" >/dev/null 2>&1
    then echo "   $n (:$p): UP"; else echo "   $n (:$p): DOWN"; fi
done
curl -fs -m2 http://localhost:8091/actuator/health >/dev/null 2>&1 && echo "   launcher (:8091): UP" || echo "   launcher (:8091): DOWN (de propósito — SUBIR_LAUNCHER=1 p/ ligar)"
echo "   threads=$(ps -eLo user 2>/dev/null | grep -c "^$(id -un | cut -c1-8)")/200 (nproc soft)"
echo "======================================================"
echo "Abra o Configurador:  http://$(hostname -I 2>/dev/null | awk '{print $1}'):8095"
