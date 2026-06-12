#!/usr/bin/env bash
# Clone or update both application repos at the deployment branch.
# Reads BACKEND_REPO_URL, FRONTEND_REPO_URL, DEPLOY_BRANCH from the
# environment or from the repo-root .env file.
set -euo pipefail

cd "$(dirname "$0")/.."

# Load .env if present — but variables already set in the environment
# (e.g. by CI) take precedence over .env values.
if [ -f .env ]; then
  _backend="${BACKEND_REPO_URL:-}"
  _frontend="${FRONTEND_REPO_URL:-}"
  _branch="${DEPLOY_BRANCH:-}"
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  [ -n "$_backend" ]  && BACKEND_REPO_URL="$_backend"
  [ -n "$_frontend" ] && FRONTEND_REPO_URL="$_frontend"
  [ -n "$_branch" ]   && DEPLOY_BRANCH="$_branch"
fi

: "${BACKEND_REPO_URL:?BACKEND_REPO_URL must be set (in .env or the environment)}"
: "${FRONTEND_REPO_URL:?FRONTEND_REPO_URL must be set (in .env or the environment)}"
BRANCH="${DEPLOY_BRANCH:-uni-prod}"

mkdir -p sources

fetch() { # fetch <dir> <git-url>
  local dir="sources/$1" url="$2"
  if [ -d "$dir/.git" ]; then
    echo "==> updating $1 @ $BRANCH"
    git -C "$dir" fetch --depth 1 origin "$BRANCH"
    git -C "$dir" checkout "$BRANCH" 2>/dev/null || git -C "$dir" checkout -b "$BRANCH" "origin/$BRANCH"
    git -C "$dir" reset --hard "origin/$BRANCH"
  else
    echo "==> cloning $1 @ $BRANCH"
    git clone --branch "$BRANCH" --depth 1 "$url" "$dir"
  fi
  echo "    $1 at commit $(git -C "$dir" rev-parse --short HEAD)"
}

fetch genesis-backend  "$BACKEND_REPO_URL"
fetch genesis-frontend "$FRONTEND_REPO_URL"
