#!/usr/bin/env bash
# Sobe o Launcher HEXAGONAL (reator). Usa o JDK 21 EMBUTIDO (./jdk) se existir; senao o
# 'java' do sistema (17+). Le o application.yml desta pasta. Porta padrao 8083 (coexiste com o
# Kong na 8082). Uso:  ./run.sh [porta]
set -e
cd "$(dirname "$0")"

if [ ! -x "./jdk/bin/java" ] && [ -f "./jdk-runtime.tar.gz" ]; then
  echo "Preparando JDK 21 embutido (primeira vez)..."
  tar -xzf ./jdk-runtime.tar.gz
  d="$(tar -tzf ./jdk-runtime.tar.gz | head -1 | cut -d/ -f1)"
  if [ -d "$d" ] && [ ! -e ./jdk ]; then mv "$d" ./jdk; fi
fi

ulimit -v unlimited 2>/dev/null || true

if [ -f "./jdk/bin/java" ]; then
  chmod +x ./jdk/bin/* 2>/dev/null || true
  [ -f ./jdk/lib/jspawnhelper ] && chmod +x ./jdk/lib/jspawnhelper 2>/dev/null || true
  JAVA="$(pwd)/jdk/bin/java"
else
  JAVA="java"
fi

JAR="$(ls launcher*.jar | head -1)"
PORT="${1:-8083}"
[ -n "$JAR" ] || { echo "ERRO: jar nao encontrado nesta pasta."; exit 1; }

echo "Subindo $JAR (reator hexagonal) na porta $PORT"
echo "  Java: $JAVA"
"$JAVA" -version
exec "$JAVA" -jar "$JAR" --server.port="$PORT"
