#!/usr/bin/env bash
# Sobe o scci-core (monolito modular, dominios em Java). Usa o JDK 21 EMBUTIDO (./jdk) se existir;
# senao o 'java' do sistema (21+). Le o application.yml desta pasta. Porta padrao 8090 (interno; o
# launcher chama por REST). Uso:  ./run.sh [porta]
#
# Config por ENV (opcional):
#   SCCI_DOCUMENTOS_JASPER_DIR=/caminho/dos/relatorios   (templates .jrxml + subreports .jasper + imagens)
# O banco de cada ambiente vem do launcherenv.ini (mesmos paths do launcher) -> este processo precisa
# enxergar os mesmos diretorios de ambiente e alcancar o(s) banco(s).
set -e
cd "$(dirname "$0")"

if [ ! -x "./jdk/bin/java" ] && [ -f "./jdk-runtime.tar.gz" ]; then
  echo "Preparando JDK 21 embutido (primeira vez)..."
  tar -xzf ./jdk-runtime.tar.gz
  d="$(tar -tzf ./jdk-runtime.tar.gz | head -1 | cut -d/ -f1)"
  if [ -d "$d" ] && [ ! -e ./jdk ]; then mv "$d" ./jdk; fi
fi

if [ -f "./jdk/bin/java" ]; then
  chmod +x ./jdk/bin/* 2>/dev/null || true
  [ -f ./jdk/lib/jspawnhelper ] && chmod +x ./jdk/lib/jspawnhelper 2>/dev/null || true
  JAVA="$(pwd)/jdk/bin/java"
else
  JAVA="java"
fi

JAR="$(ls scci-core*.jar | head -1)"
PORT="${1:-8090}"
[ -n "$JAR" ] || { echo "ERRO: jar nao encontrado nesta pasta."; exit 1; }

echo "Subindo $JAR (scci-core) na porta $PORT"
echo "  Java: $JAVA"
"$JAVA" -version
exec "$JAVA" -jar "$JAR" --server.port="$PORT"
