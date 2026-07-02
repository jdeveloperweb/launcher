#!/usr/bin/env bash
# Watchdog opcional do reator hexagonal (porta 8083). NAO e servico, NAO vai no cron por padrao.
# Uso manual:  ./manter.sh 8083
APP="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-8083}"
cd "$APP" || exit 0

if curl -fs "http://localhost:$PORT/actuator/health" >/dev/null 2>&1; then
  exit 0
fi
ulimit -v unlimited 2>/dev/null || true
nohup bash run.sh "$PORT" >> app.log 2>&1 &
