#!/usr/bin/env bash
# ====================================================================
#  Instalador do reator HEXAGONAL (rode NO SERVIDOR). Porta 8083 — coexiste
#  com o Kong (8082). Coloque nesta pasta o launcher.tar.gz
#  + este instalar.sh e rode:   bash instalar.sh [porta] [kong_reload] [kong_mode]
#    kong_reload = true|false   kong_mode = reload|deck|docker
#  (o enviar-pacote.bat faz isso via SSH). JDK 21 embutido, sem cron.
# ====================================================================
set -e
PORT="${1:-8083}"
KONG_RELOAD="${2:-false}"
KONG_MODE="${3:-reload}"
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
TGZ="launcher.tar.gz"
APP="$HERE/app"

[ -f "$TGZ" ] || { echo "ERRO: $TGZ nao encontrado em $HERE"; exit 1; }

echo "==> Descompactando em $APP ..."
mkdir -p "$APP"
tar -xzf "$TGZ" -C "$APP"
chmod +x "$APP"/run.sh "$APP"/smoke-test.sh "$APP"/manter.sh 2>/dev/null || true

echo "==> Parando instancia anterior na porta $PORT (se houver)..."
if command -v fuser >/dev/null 2>&1; then fuser -k "${PORT}/tcp" 2>/dev/null || true
else pkill -f 'launcher.*\.jar' 2>/dev/null || true
fi
sleep 2

echo "==> Subindo o reator (porta $PORT) com o JDK 21 embutido..."
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

# -------- Kong (opcional): recarrega a config declarativa --------
if [ "$KONG_RELOAD" = "true" ]; then
  echo "==> Recarregando Kong (modo: $KONG_MODE)..."
  case "$KONG_MODE" in
    deck)   command -v deck  >/dev/null 2>&1 && deck gateway sync "$APP/kong/kong.yml" || echo "    deck nao encontrado." ;;
    docker) command -v docker >/dev/null 2>&1 && (cd "$APP/kong" && docker compose up -d && docker compose restart kong) || echo "    docker nao encontrado." ;;
    *)      command -v kong  >/dev/null 2>&1 && (KONG_DECLARATIVE_CONFIG="$APP/kong/kong.yml" kong reload) || echo "    kong nao encontrado (use KONG_MODE=deck|docker)." ;;
  esac
else
  echo "==> Kong NAO recarregado (KONG_RELOAD=false). Config em $APP/kong/kong.yml"
fi

cat <<EOF

============================================================
 LAUNCHER HEXAGONAL  ->  http://localhost:$PORT   (Kong escuta na 8082)
 status: $([ "$ok" = 1 ] && echo NO_AR || echo VERIFICAR_LOG)
============================================================
 Testar:  bash $APP/smoke-test.sh $PORT
 Logs:    $APP/app.log   (JSON)
 Parar:   fuser -k $PORT/tcp
 Kong:    $APP/kong/kong.yml   (kong reload | deck gateway sync | docker compose)
============================================================
EOF
