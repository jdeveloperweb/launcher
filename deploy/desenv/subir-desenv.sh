#!/usr/bin/env bash
# ==========================================================================
#  Sobe TODOS os serviços SCCI na desenv com 1 comando (Linux/Mac).
#  Uso:  ./subir-desenv.sh        (chmod +x uma vez)
#  Edite HOST/USUARIO/PORTA/KEY abaixo se mudar de ambiente.
# ==========================================================================
set -u
HOST=10.3.98.108
USUARIO=jaime.vicente
PORTA=23
KEY="$HOME/.ssh/id_rsa"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "=== Subindo os serviços SCCI na desenv ($HOST) ==="
echo "-> enviando o script para ~/subir-desenv.sh ..."
scp -P "$PORTA" -i "$KEY" "$DIR/subir-remoto.sh" "$USUARIO@$HOST:subir-desenv.sh" || { echo "FALHOU no scp (rede/VPN/chave?)"; exit 1; }

echo "-> executando na box ..."
ssh -p "$PORTA" -i "$KEY" "$USUARIO@$HOST" "sed -i 's/\r//g' subir-desenv.sh; bash subir-desenv.sh" || { echo "FALHOU no ssh"; exit 1; }

echo ""
echo "Pronto. Abra:  http://$HOST:8095"
