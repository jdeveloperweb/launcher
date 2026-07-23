#!/usr/bin/env bash
# =====================================================================
#  Sobe o Collector de telemetria (Docker) lendo o otel-collector-config.yaml
#  deste diretorio. OTLP em :4317 (grpc) / :4318 (http), Prometheus em :9464.
#  Rode NO SERVIDOR:  bash subir-collector.sh [imagem]
#
#  Imagem padrao: contrib (tem o processor `transform`/OTTL que a config usa E os exporters
#  awsemf/awsxray). A ADOT curada NAO tem o `transform`, entao nao serve para esta config.
#
#  Para o envio AWS (CloudWatch/X-Ray) as credenciais vem de um env-file (fora do `ps`/git):
#    ~/.otel-aws.env  (chmod 600) com  AWS_REGION=sa-east-1 / AWS_ACCESS_KEY_ID=... / AWS_SECRET_ACCESS_KEY=...
#  (sem esse arquivo o Collector sobe, mas os exporters awsemf/awsxray falham na credencial.)
#
#  IMPORTANTE: a imagem contrib le a config em /etc/otelcol-contrib/config.yaml — o mount TEM que
#  ser nesse caminho (montar em /etc/otelcol/config.yaml faz o collector rodar a config DEFAULT e
#  ignorar a nossa: sem OTTL, sem :9464, sem AWS).
# =====================================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="${1:-otel/opentelemetry-collector-contrib:latest}"
AWS_ENV_FILE="${AWS_ENV_FILE:-$HOME/.otel-aws.env}"

ENVOPT=""
if [ -f "$AWS_ENV_FILE" ]; then
  ENVOPT="--env-file $AWS_ENV_FILE"
  echo "==> AWS: credenciais via $AWS_ENV_FILE"
else
  echo "==> AVISO: $AWS_ENV_FILE nao existe — awsemf/awsxray vao falhar sem credencial."
fi

echo "==> Collector: $IMG"
docker rm -f otel 2>/dev/null || true
docker run -d --name otel --network host --restart unless-stopped \
  $ENVOPT \
  -v "$HERE/otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml:ro" \
  "$IMG" --config /etc/otelcol-contrib/config.yaml

sleep 5
echo "==> status:"; docker ps --filter name=otel --format '{{.Status}}'
echo "==> se não subir, veja: docker logs otel   (e tente a imagem contrib)"
echo "==> Prometheus (scrape/validação):  curl -s http://127.0.0.1:9464/metrics | head"
