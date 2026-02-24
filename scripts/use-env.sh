#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: ./scripts/use-env.sh [dev|prod]"
  exit 1
fi

TARGET="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$TARGET" in
  dev)
    SRC="$ROOT_DIR/.env.dev"
    ;;
  prod)
    SRC="$ROOT_DIR/.env.prod"
    ;;
  *)
    echo "Invalid target: $TARGET"
    echo "Usage: ./scripts/use-env.sh [dev|prod]"
    exit 1
    ;;
esac

if [[ ! -f "$SRC" ]]; then
  echo "Missing env file: $SRC"
  exit 1
fi

cp "$SRC" "$ROOT_DIR/.env"
echo "Active env switched to: $TARGET"
echo "Using file: $SRC"
