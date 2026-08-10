#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-10000}"
DATABASE_PATH="${WINGMAN_DATABASE_PATH:-$ROOT/gateway/data/wingman.sqlite}"
LOCAL_HOST_NAME="$(scutil --get LocalHostName 2>/dev/null || hostname)"

cd "$ROOT/gateway"

if [[ ! -d node_modules ]]; then
  npm ci
fi

echo "Wingman profile gateway"
echo "Database: $DATABASE_PATH"
echo "Simulator URL: http://127.0.0.1:$PORT"
echo "Phone URL: http://$LOCAL_HOST_NAME.local:$PORT"
echo "Keep this process running while the phone syncs."

PORT="$PORT" WINGMAN_DATABASE_PATH="$DATABASE_PATH" npm run dev
