#!/usr/bin/env bash
# =====================================================================
#  logs.sh -- tail AO VIVO dos 3 servicos (launcher/scci-core/pascal-executor)
#  num unico SSH, cada linha prefixada+colorida por servico. Ctrl-C encerra
#  e mata os tails remotos (trap kill 0).
#
#  Uso (Git Bash / WSL / Linux / macOS):
#     bash deploy/logs.sh
#     bash deploy/logs.sh launcher        # so um servico
#     bash deploy/logs.sh scci-core pascal-executor
#
#  Overrides por env var:
#     SCCI_HOST=jaime.vicente@10.3.98.108  SCCI_SSH_PORT=23  SCCI_KEY=~/.ssh/id_rsa
# =====================================================================
set -uo pipefail

HOST="${SCCI_HOST:-jaime.vicente@10.3.98.108}"
PORT="${SCCI_SSH_PORT:-23}"
KEY="${SCCI_KEY:-$HOME/.ssh/id_rsa}"

# servicos a seguir (default: os 3). Aceita nomes na linha de comando.
SVCS="${*:-launcher scci-core pascal-executor}"

ssh -t -p "$PORT" -i "$KEY" "$HOST" "
  L=\$(printf '\033[36m'); C=\$(printf '\033[32m'); P=\$(printf '\033[35m'); N=\$(printf '\033[0m')
  trap 'kill 0' EXIT INT TERM
  for s in $SVCS; do
    f=\"\$HOME/\$s/app/app.log\"
    case \"\$s\" in
      launcher)        pref=\"\${L}[LAUNCHER ]\${N}\";;
      scci-core)       pref=\"\${C}[SCCI-CORE]\${N}\";;
      pascal-executor) pref=\"\${P}[PASCAL   ]\${N}\";;
      *)               pref=\"[\$s]\";;
    esac
    tail -F \"\$f\" 2>/dev/null | sed -u \"s|^|\$pref |\" &
  done
  wait
"
