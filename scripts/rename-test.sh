#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LIST_ARG=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      LIST_ARG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--list Name1,Name2,...] [--dry-run]"
      echo "       $(basename "$0") [--dry-run] Name1 Name2 Name3 ..."
      exit 0
      ;;
    *)
      break
      ;;
  esac
done

if [[ -n "$LIST_ARG" ]]; then
  IFS=',' read -r -a NAMES <<< "$LIST_ARG"
elif [[ $# -gt 0 ]]; then
  NAMES=("$@")
else
  NAMES=("SampleApp")
fi

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/nixoncpp-rename-test.XXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

tar \
  --exclude='./.git' \
  --exclude='./build' \
  --exclude='./docs' \
  --exclude='./.direnv' \
  --exclude='./.emscripten_cache' \
  --exclude='./result' \
  -C "$PROJECT_ROOT" -cf - . | tar -C "$TEST_ROOT" -xf -

echo "🔁 Rename test sequence: ${NAMES[*]}"

for name in "${NAMES[@]}"; do
  if [[ -z "$name" ]]; then
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $TEST_ROOT/scripts/rename.sh $name"
  else
    "$TEST_ROOT/scripts/rename.sh" "$name"

    grep -q "project('$name'" "$TEST_ROOT/meson.build"
    grep -q "packages.$name = projectPackage" "$TEST_ROOT/nix/flake.nix"
    grep -q "apps.$name =" "$TEST_ROOT/nix/flake.nix"
    grep -q "program = \"\${projectPackage}/bin/$name\"" "$TEST_ROOT/nix/flake.nix"

    if command -v nix >/dev/null 2>&1; then
      nix flake show "$TEST_ROOT/nix" >/dev/null
    fi
  fi
  echo "---"
  sleep 0.1
done

echo "✅ Rename test complete"
