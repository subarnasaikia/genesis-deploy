#!/usr/bin/env bash
# Verify the running stack: backend actuator reports UP, frontend serves HTML.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

BACKEND_URL="http://localhost:${BACKEND_PORT:-8080}"
FRONTEND_URL="http://localhost:${FRONTEND_PORT:-3000}"

# The backend builds 14 Maven modules and runs DB migrations on first boot —
# allow up to 5 minutes before declaring failure.
echo -n "waiting for backend at $BACKEND_URL/actuator/health "
for _ in $(seq 1 60); do
  if curl -fsS "$BACKEND_URL/actuator/health" 2>/dev/null | grep -q '"status":"UP"'; then
    echo "— UP"
    backend_ok=1
    break
  fi
  echo -n "."
  sleep 5
done
if [ -z "${backend_ok:-}" ]; then
  echo " FAILED" >&2
  echo "Backend never became healthy. Recent logs:" >&2
  docker compose -f docker/docker-compose.yml --env-file .env logs --tail 50 backend >&2 || true
  exit 1
fi

echo -n "waiting for frontend at $FRONTEND_URL "
for _ in $(seq 1 24); do
  if curl -fsS -o /dev/null "$FRONTEND_URL" 2>/dev/null; then
    echo "— UP"
    frontend_ok=1
    break
  fi
  echo -n "."
  sleep 5
done
if [ -z "${frontend_ok:-}" ]; then
  echo " FAILED" >&2
  echo "Frontend never became reachable. Recent logs:" >&2
  docker compose -f docker/docker-compose.yml --env-file .env logs --tail 50 frontend >&2 || true
  exit 1
fi

echo "stack healthy: backend $BACKEND_URL, frontend $FRONTEND_URL"
