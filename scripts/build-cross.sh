#!/usr/bin/env bash
# Deprecated wrapper for cross builds (use scripts/build.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

exec "$PROJECT_ROOT/scripts/build.sh" "$@"
