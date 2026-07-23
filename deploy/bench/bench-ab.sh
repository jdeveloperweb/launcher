#!/usr/bin/env bash
# =====================================================================
#  bench-ab.sh -- A/B de latencia: legado /aejs (Pascal) x novo /aejs-l (Java)
#
#  METODO: mesma operacao nos dois caminhos, medida pela BORDA (Apache/Kong),
#  INTERCALADO (A,B,A,B...) para cancelar variacao de backend/DB/rede, com
#  WARMUP (descarta JIT/pool frios). Reporta p50/p90/p95/p99 por operacao.
#  Sem dependencia externa: so curl + awk. Ver README.md para a metodologia.
#
#  Uso:
#    AEJS_BASE=https://host/aejs AEJSL_BASE=https://host/aejs-l ./bench-ab.sh
# =====================================================================
set -uo pipefail

# ---- CONFIG (sobrescreva por variavel de ambiente) ------------------
AEJS_BASE="${AEJS_BASE:?defina AEJS_BASE, ex: https://host/aejs (legado Pascal)}"
AEJSL_BASE="${AEJSL_BASE:?defina AEJSL_BASE, ex: https://host/aejs-l (novo Java)}"
AMB="${AMB:-/u10/c6bank/suporte/scat112934}"   # ambiente de suporte/scat (nao-producao)
USER_SCCI="${USER_SCCI:-supervisor}"
PASS_SCCI="${PASS_SCCI:-Tempo+2024}"
CONTEXTO="${CONTEXTO:-CORP_WEB}"

N_WARM="${N_WARM:-30}"          # requests descartados por op/stack (aquece JIT/pools)
N_SAMPLES="${N_SAMPLES:-200}"   # amostras MEDIDAS por op/stack

# operacoes a medir (subconjunto de: login dispatch download upload)
OPS="${OPS:-login dispatch download upload}"

# ---- dispatch (ainda Pascal via pascal-executor): wmenu/menu (GET) ---
DP_PROG="${DP_PROG:-wmenu}"
DP_METODO="${DP_METODO:-menu}"
DP_EXTRA="${DP_EXTRA:-\"menu\":\"MENUPRINCIPAL\"}"   # params extra do programa (JSON, sem chaves)

# ---- download (GetDocumento -> Java): PRECISA de um doc REAL do scat --
DL_PROG="${DL_PROG:-wdoc}"
DL_METODO="${DL_METODO:-GetDocumento}"
DL_EXTRA="${DL_EXTRA:-}"        # ex: '"NU_SISTARQ":"12345"'  (identificador do doc real)

# ---- upload (multipart): arquivo de teste (gerado se faltar) ----------
UP_PROG="${UP_PROG:-wdoc}"
UP_METODO="${UP_METODO:-PostDocumento}"
UP_FILE="${UP_FILE:-/tmp/bench-upload.txt}"
UP_EXTRA_STR="${UP_EXTRA_STR:-}"   # campos -F extras do upload real, ex: UP_EXTRA_STR='-F NU_OPERACAO=000000105'

CURL_OPTS=(-s -k --max-time 60)     # -k: aceita TLS self-signed em dev
OUT="${OUT:-bench-$(hostname)}"
CSV="$OUT.csv"

# ---- helpers --------------------------------------------------------
base_de() { [ "$1" = aejs ] && printf '%s' "$AEJS_BASE" || printf '%s' "$AEJSL_BASE"; }

# login <stack> -> imprime sessionKey (vazio se falhar / resposta cifrada)
login() {
  curl "${CURL_OPTS[@]}" -X POST "$(base_de "$1")/w/login" \
    -H 'Content-Type: application/json' \
    -d "{\"userName\":\"$USER_SCCI\",\"password\":\"$PASS_SCCI\",\"ambienteOperacional\":\"$AMB\"}" \
    | grep -o '"sessionKey":"[^"]*"' | head -1 | sed 's/.*:"//;s/"$//'
}

# hit <stack> <path> <curl-args...> -> imprime: <http_code> <total> <ttfb> <connect> <tls>  (segundos)
hit() {
  local stack="$1" path="$2"; shift 2
  curl "${CURL_OPTS[@]}" -o /dev/null \
    -w '%{http_code} %{time_total} %{time_starttransfer} %{time_connect} %{time_appconnect}' \
    "$@" "$(base_de "$stack")$path" 2>/dev/null || echo "000 0 0 0 0"
}

# --- uma execucao por operacao (stack, sessionKey) --------------------
op_login() {  # nao usa sessao: mede o round-trip completo de autenticacao
  hit "$1" "/w/login" -X POST -H 'Content-Type: application/json' \
    -d "{\"userName\":\"$USER_SCCI\",\"password\":\"$PASS_SCCI\",\"ambienteOperacional\":\"$AMB\"}"
}
op_dispatch() {
  local k="$2"
  hit "$1" "/w" -X POST -H 'Content-Type: application/json' \
    -d "{\"programName\":\"$DP_PROG\",\"methodName\":\"$DP_METODO\",\"requestMethod\":\"GET\",\"ambienteOperacional\":\"$AMB\",\"userName\":\"$USER_SCCI\",\"contexto\":\"$CONTEXTO\",\"sessionKey\":\"$k\"${DP_EXTRA:+,$DP_EXTRA}}"
}
op_download() {
  local k="$2"
  hit "$1" "/sccidoc" -X POST -H 'Content-Type: application/json' \
    -d "{\"programName\":\"$DL_PROG\",\"methodName\":\"$DL_METODO\",\"requestMethod\":\"GET\",\"ambienteOperacional\":\"$AMB\",\"userName\":\"$USER_SCCI\",\"contexto\":\"$CONTEXTO\",\"sessionKey\":\"$k\"${DL_EXTRA:+,$DL_EXTRA}}"
}
op_upload() {
  local k="$2"; local extra=()
  [ -n "$UP_EXTRA_STR" ] && read -ra extra <<< "$UP_EXTRA_STR"
  hit "$1" "/sccidoc" \
    -F "file=@$UP_FILE" \
    -F "programName=$UP_PROG" -F "methodName=$UP_METODO" -F "requestMethod=POST" \
    -F "ambienteOperacional=$AMB" -F "userName=$USER_SCCI" -F "sessionKey=$k" \
    ${extra[@]+"${extra[@]}"}
}

# ---- preflight ------------------------------------------------------
echo "== bench A/B  legado(aejs)=$AEJS_BASE  novo(aejsl)=$AEJSL_BASE"
echo "== ambiente=$AMB  usuario=$USER_SCCI  warmup=$N_WARM  amostras=$N_SAMPLES  ops=[$OPS]"
[ -f "$UP_FILE" ] || { head -c 8192 /dev/urandom | base64 > "$UP_FILE"; echo "== gerado arquivo de upload de teste: $UP_FILE"; }

declare -A KEY
for stack in aejs aejsl; do
  KEY[$stack]="$(login "$stack")"
  if [ -n "${KEY[$stack]}" ]; then
    echo "== login OK em $stack (sessionKey=${KEY[$stack]:0:8}...)"
  else
    echo "!! login FALHOU/cifrado em $stack -> ops com sessao (dispatch/download/upload) serao PULADAS nesse stack"
  fi
done

# ops que dependem de sessao
needs_key() { case "$1" in dispatch|download|upload) return 0;; *) return 1;; esac; }

echo "op,stack,http_code,total_s,ttfb_s,connect_s,tls_s" > "$CSV"

# ---- warmup (descartado) --------------------------------------------
echo "== warmup ($N_WARM x por op/stack)..."
for op in $OPS; do
  for stack in aejs aejsl; do
    needs_key "$op" && [ -z "${KEY[$stack]}" ] && continue
    for _ in $(seq 1 "$N_WARM"); do "op_$op" "$stack" "${KEY[$stack]}" >/dev/null; done
  done
done

# ---- medicao INTERCALADA (A,B por iteracao) -------------------------
echo "== medindo ($N_SAMPLES amostras, intercalado)..."
for i in $(seq 1 "$N_SAMPLES"); do
  for op in $OPS; do
    for stack in aejs aejsl; do
      needs_key "$op" && [ -z "${KEY[$stack]}" ] && continue
      line="$("op_$op" "$stack" "${KEY[$stack]}")"
      echo "$op,$stack,$(echo "$line" | tr ' ' ',')" >> "$CSV"
    done
  done
  [ $((i % 25)) -eq 0 ] && echo "   ...$i/$N_SAMPLES"
done

# ---- relatorio: percentis por (op, stack) ---------------------------
echo
echo "===================== RESULTADO (ms) ====================="
printf "%-9s %-6s %6s %5s %8s %8s %8s %8s %8s\n" op stack n err mean p50 p90 p95 p99
awk -F, 'NR>1{print $1","$2}' "$CSV" | sort -u | while IFS=, read -r op stack; do
  err=$(awk -F, -v o="$op" -v s="$stack" 'NR>1&&$1==o&&$2==s&&$3!="200"{c++}END{print c+0}' "$CSV")
  awk -F, -v o="$op" -v s="$stack" 'NR>1&&$1==o&&$2==s{printf "%.3f\n",$4*1000}' "$CSV" | sort -n | \
  awk -v o="$op" -v s="$stack" -v err="$err" '
    function pct(p,   i){ i=int(p/100.0*(NR-1))+1; if(i<1)i=1; if(i>NR)i=NR; return a[i] }
    {a[NR]=$1; sum+=$1}
    END{ if(NR>0) printf "%-9s %-6s %6d %5d %8.1f %8.1f %8.1f %8.1f %8.1f\n",
         o,s,NR,err,sum/NR,pct(50),pct(90),pct(95),pct(99) }'
done

echo
echo "===================== DELTA aejsl - aejs (p50 / p95, ms) ====================="
awk -F, 'NR>1{print $1}' "$CSV" | sort -u | while read -r op; do
  for stack in aejs aejsl; do
    v=$(awk -F, -v o="$op" -v s="$stack" 'NR>1&&$1==o&&$2==s{printf "%.3f\n",$4*1000}' "$CSV" | sort -n)
    n=$(printf '%s\n' "$v" | grep -c . || true)
    [ "$n" -gt 0 ] || { eval "P50_$stack=NA; P95_$stack=NA"; continue; }
    read -r p50 p95 < <(printf '%s\n' "$v" | awk 'function pct(p,i){i=int(p/100.0*(NR-1))+1;if(i<1)i=1;if(i>NR)i=NR;return a[i]}{a[NR]=$1}END{printf "%.1f %.1f",pct(50),pct(95)}')
    eval "P50_$stack=$p50; P95_$stack=$p95"
  done
  if [ "${P50_aejs:-NA}" != NA ] && [ "${P50_aejsl:-NA}" != NA ]; then
    d50=$(awk -v a="$P50_aejs" -v b="$P50_aejsl" 'BEGIN{printf "%+.1f",b-a}')
    d95=$(awk -v a="$P95_aejs" -v b="$P95_aejsl" 'BEGIN{printf "%+.1f",b-a}')
    printf "%-9s  aejs p50=%-7s p95=%-7s | aejsl p50=%-7s p95=%-7s | delta p50=%s p95=%s\n" \
      "$op" "$P50_aejs" "$P95_aejs" "$P50_aejsl" "$P95_aejsl" "$d50" "$d95"
  else
    printf "%-9s  (sem par comparavel: aejs=%s aejsl=%s)\n" "$op" "${P50_aejs:-NA}" "${P50_aejsl:-NA}"
  fi
done

echo
echo "CSV bruto: $CSV  (op,stack,http_code,total_s,ttfb_s,connect_s,tls_s)"
