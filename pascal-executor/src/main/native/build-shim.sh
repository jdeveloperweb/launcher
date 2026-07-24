#!/usr/bin/env bash
# Compila o shim do transporte v2 (Alt4 UDS+shim). Roda na BOX Linux (desenv/prod).
# Saída: oserver-shim. Aponte executor.shim-path (ou EXECUTOR_SHIM) para o caminho instalado.
#
#   bash build-shim.sh [destino]     # destino default: /u/scci/binfpc/oserver-shim
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-/u/scci/binfpc/oserver-shim}"
CC="${CC:-cc}"

"$CC" -O2 -Wall -o "$DEST" "$DIR/shim.c"
echo "shim compilado: $DEST"
"$DEST" 2>/dev/null || true   # sem args imprime uso (rc!=0), só confirma que executa
echo "OK"
