#!/usr/bin/env bash
# ============================================================================
#  Instalador do Configurador SCCI (:8095) — sobe a ferramenta a partir de UM
#  arquivo (configurador.bundle.js). Idempotente: rodar de novo = atualizar.
#
#  Uso:
#     ./instalar-configurador.sh [dir-destino]     # default: $HOME/configurador
#     PORT=9000 ./instalar-configurador.sh         # outra porta
#
#  So precisa: node no PATH + o configurador.bundle.js ao lado deste script.
#  Estado (users.json, secret.key, overrides.json, audit.jsonl) fica no destino
#  e e PRESERVADO entre atualizacoes.
# ============================================================================
set -eu

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:-$HOME/configurador}"
PORT="${PORT:-8095}"
BUNDLE="configurador.bundle.js"

command -v node >/dev/null 2>&1 || { echo "ERRO: 'node' nao encontrado no PATH."; exit 1; }
[ -f "$SRC_DIR/$BUNDLE" ] || { echo "ERRO: $BUNDLE nao esta junto do instalador (rode 'node bundle.js' antes)."; exit 1; }

echo ">> destino: $DEST   porta: $PORT"
mkdir -p "$DEST"
cp "$SRC_DIR/$BUNDLE" "$DEST/configurador.js"

# libera a porta (mata SO quem estiver nela — server.js antigo ou bundle) — escopo seguro por PORTA
free_port() { p="$1"
  if command -v fuser >/dev/null 2>&1; then fuser -k "${p}/tcp" >/dev/null 2>&1 || true
  elif command -v lsof >/dev/null 2>&1; then q=$(lsof -ti "tcp:${p}" 2>/dev/null || true); [ -n "${q:-}" ] && kill $q 2>/dev/null || true; fi
}
echo ">> liberando :$PORT"; free_port "$PORT"; sleep 1

cd "$DEST"
PORT="$PORT" setsid node "$DEST/configurador.js" >> configurador.log 2>&1 < /dev/null &
sleep 2

if curl -fs -m4 "http://localhost:$PORT/" -o /dev/null 2>/dev/null; then
  ip=$(hostname -I 2>/dev/null | awk '{print $1}')
  echo ">> OK — no ar em  http://${ip:-localhost}:$PORT   (dir: $DEST)"
else
  echo ">> AVISO: nao respondeu em :$PORT ainda — confira $DEST/configurador.log"
fi

# credenciais admin so aparecem na 1a instalacao (users.json e preservado depois)
cred=$(grep -a "senha:" "$DEST/configurador.log" 2>/dev/null | tail -1 || true)
[ -n "${cred:-}" ] && echo ">> $cred" || echo ">> admin ja existia — users.json preservado"

# unit systemd de exemplo (NAO instala sozinho; precisa root)
cat > "$DEST/configurador.service.exemplo" <<EOF
[Unit]
Description=Configurador SCCI
After=network.target
[Service]
Type=simple
ExecStart=$(command -v node) $DEST/configurador.js
Environment=PORT=$PORT
WorkingDirectory=$DEST
Restart=on-failure
User=$(whoami)
[Install]
WantedBy=multi-user.target
EOF
echo ">> p/ virar servico (opcional, precisa root):"
echo "     sudo cp $DEST/configurador.service.exemplo /etc/systemd/system/configurador.service && sudo systemctl enable --now configurador"
