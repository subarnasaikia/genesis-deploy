#!/usr/bin/env bash
# One-command deployment: fetch sources -> build images -> start stack -> verify.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Create it first:" >&2
  echo "  cp config/.env.example .env   # then fill in the required values" >&2
  exit 1
fi

echo "==> [1/4] fetching sources"
./scripts/fetch-sources.sh

echo "==> [2/4] building images"
docker compose -f docker/docker-compose.yml --env-file .env build

echo "==> [3/4] starting stack"
docker compose -f docker/docker-compose.yml --env-file .env up -d

echo "==> [4/4] health check"
./scripts/healthcheck.sh

echo
echo "Deployment complete."
