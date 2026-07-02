#!/usr/bin/env bash
# =====================================================================
#  Sobe o Collector de telemetria (Docker) lendo o otel-collector-config.yaml
#  deste diretorio. OTLP em :4317 (grpc) / :4318 (http), Prometheus em :9464.
#  Rode NO SERVIDOR:  bash subir-collector.sh [imagem]
#
#  Imagem padrao: ADOT (AWS Distro). Alternativa (mesma capacidade OTTL):
#    otel/opentelemetry-collector-contrib:latest
# =====================================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
IMG="${1:-public.ecr.aws/aws-observability/aws-otel-collector:latest}"

echo "==> Collector: $IMG"
docker rm -f otel 2>/dev/null || true
docker run -d --name otel --network host --restart unless-stopped \
  -v "$HERE/otel-collector-config.yaml:/etc/otelcol/config.yaml:ro" \
  "$IMG" --config /etc/otelcol/config.yaml

sleep 5
echo "==> status:"; docker ps --filter name=otel --format '{{.Status}}'
echo "==> se não subir, veja: docker logs otel   (e tente a imagem contrib)"
echo "==> Prometheus (scrape/validação):  curl -s http://127.0.0.1:9464/metrics | head"
