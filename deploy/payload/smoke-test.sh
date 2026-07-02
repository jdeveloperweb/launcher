#!/usr/bin/env bash
# Smoke-test do reator hexagonal (contrato W_COP nativo, JSON puro aceito em dev). Uso: ./smoke-test.sh [porta]
# Compara respostas (contrato W_COP): as respostas de /w/login, /w/password, /w devem BATER.
P="${1:-8083}"; H="http://localhost:$P"
AMB="${2:-/u10/c6bank/suporte/scat112934}"
echo "== health =="
curl -s "$H/actuator/health"; echo
echo "== /w/login (JSON puro; senha errada -> success:false + message) =="
curl -s -X POST "$H/w/login" -H 'Content-Type: application/json' \
  -d "{\"userName\":\"supervisor\",\"password\":\"__errada__\",\"ambienteOperacional\":\"$AMB\"}"; echo
echo "== /w  wmenu/GetMenu (executa binario real via JNA) =="
curl -s -X POST "$H/w" -H 'Content-Type: application/json' \
  -d "{\"programName\":\"wmenu\",\"methodName\":\"menu\",\"requestMethod\":\"GET\",\"ambienteOperacional\":\"$AMB\",\"userName\":\"supervisor\",\"menu\":\"MENUPRINCIPAL\",\"contexto\":\"CORP_WEB\"}" | head -c 400; echo
echo "== licencas / documentos (scaffold 501) =="
curl -s -o /dev/null -w "licencas=%{http_code} " "$H/licencas"
curl -s -o /dev/null -w "documentos=%{http_code}\n" "$H/documentos"
