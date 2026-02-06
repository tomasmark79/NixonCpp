#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

get_project_name() {
  local name
  name=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null \
    | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
  if [[ -z "$name" ]]; then
    name="NixonCpp"
  fi
  echo "$name"
}

KEEP_FINAL=0
LIST_ARG=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)
      KEEP_FINAL=1
      shift
      ;;
    --list)
      LIST_ARG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--list Name1,Name2,...] [--keep] [--dry-run]"
      echo "       $(basename "$0") [--dry-run] Name1 Name2 Name3 ..."
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

ORIGINAL_NAME="$(get_project_name)"

if [[ -n "$LIST_ARG" ]]; then
  IFS=',' read -r -a NAMES <<< "$LIST_ARG"
elif [[ $# -gt 0 ]]; then
  NAMES=("$@")
else
  NAMES=("AlphaApp" "BetaTool" "GammaSuite")
fi

if [[ "$KEEP_FINAL" -eq 0 ]]; then
  NAMES+=("$ORIGINAL_NAME")
fi

echo "🔁 Rename test sequence: ${NAMES[*]}"

for name in "${NAMES[@]}"; do
  if [[ -z "$name" ]]; then
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $PROJECT_ROOT/scripts/rename.sh $name"
  else
    "$PROJECT_ROOT/scripts/rename.sh" "$name"
  fi
  echo "---"
  sleep 0.1
done

echo "✅ Rename test complete"
