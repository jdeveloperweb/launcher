#!/usr/bin/env bash
# ====================================================================
#  Instalador do scci-core (rode NO SERVIDOR). Porta 8090 (interno; o launcher
#  chama por REST em SCCI_CORE_URL). Coloque nesta pasta o scci-core.tar.gz +
#  este instalar.sh e rode:   bash instalar.sh [porta]
#  JDK 21 embutido, sem cron, sem Kong (nao e exposto ao front).
# ====================================================================
set -e
PORT="${1:-8090}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
TGZ="scci-core.tar.gz"
APP="$HERE/app"

[ -f "$TGZ" ] || { echo "ERRO: $TGZ nao encontrado em $HERE"; exit 1; }

echo "==> Descompactando em $APP ..."
mkdir -p "$APP"
tar -xzf "$TGZ" -C "$APP"
chmod +x "$APP"/run.sh 2>/dev/null || true

echo "==> Parando instancia anterior na porta $PORT (se houver)..."
if command -v fuser >/dev/null 2>&1; then fuser -k "${PORT}/tcp" 2>/dev/null || true
else pkill -f 'scci-core.*\.jar' 2>/dev/null || true
fi
sleep 2

echo "==> Subindo o scci-core (porta $PORT) com o JDK 21 embutido..."
cd "$APP"
nohup bash run.sh "$PORT" > app.log 2>&1 &
echo "    PID=$!   log=$APP/app.log"

echo "==> Aguardando ficar no ar..."
ok=0
for i in $(seq 1 90); do
  if curl -fs "http://localhost:$PORT/actuator/health" >/dev/null 2>&1; then ok=1; break; fi
  sleep 1
done
[ "$ok" = 1 ] && echo "    OK! /actuator/health respondeu." || echo "    Ainda nao subiu. Veja: tail -n 40 $APP/app.log"

cat <<EOF

============================================================
 SCCI-CORE  ->  http://localhost:$PORT   (interno; o launcher chama por REST)
 status: $([ "$ok" = 1 ] && echo NO_AR || echo VERIFICAR_LOG)
============================================================
 Health:  curl -s http://localhost:$PORT/actuator/health
 Logs:    $APP/app.log   (JSON)
 Parar:   fuser -k $PORT/tcp
 Proximo: no LAUNCHER, aponte  launcher.scci-core.url = http://localhost:$PORT
          e ligue a flag  launcher.roteamento.documentos.GetDocumento = { habilitado: true }
============================================================
EOF
