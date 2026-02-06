#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OLD_NAME="NixonCpp"
OLD_LIB="NixonCppLib"
OLD_NS="nixoncpp"

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <NewName> [NewLibName] [NewNamespace]"
  echo "Example: $(basename "$0") MyApp MyAppLib myapp"
  exit 1
fi

NEW_NAME="$1"
NEW_LIB="${2:-${NEW_NAME}Lib}"
NEW_NS="${3:-$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')}"

FILES=(
  "meson.build"
  "meson_options.txt"
  "Makefile"
  "README.md"
  "Doxyfile"
  "scripts/build.sh"
  "scripts/solution-controller.sh"
  "scripts/package.sh"
  ".vscode/tasks.json"
  ".vscode/launch.json"
  ".vscode/launch-windows.json"
  ".vscode/settings.json"
  "nix/flake.nix"
  "nix/shell.nix"
  "nix/cross-shell-wasm.nix"
  "nix/cross-shell-aarch64.nix"
  "nix/cross-shell-windows.nix"
  "assets/ems-mini.html"
  "tests/meson.build"
  "include/${OLD_LIB}/${OLD_LIB}.hpp"
  "src/lib/${OLD_LIB}.cpp"
)

replace_in_file() {
  local file="$1"
  local search="$2"
  local replace="$3"

  if [[ ! -f "$file" ]]; then
    return 0
  fi

  python3 - <<'PY' "$file" "$search" "$replace"
import io
import sys
from pathlib import Path

path = Path(sys.argv[1])
search = sys.argv[2]
replace = sys.argv[3]

text = path.read_text(encoding="utf-8")
new_text = text.replace(search, replace)
if new_text != text:
    path.write_text(new_text, encoding="utf-8")
PY
}

move_if_exists() {
  local src="$1"
  local dst="$2"

  if [[ -e "$src" && ! -e "$dst" ]]; then
    mkdir -p "$(dirname "$dst")"
    mv "$src" "$dst"
  fi
}

pushd "$PROJECT_ROOT" >/dev/null

for f in "${FILES[@]}"; do
  replace_in_file "$f" "$OLD_NAME" "$NEW_NAME"
  replace_in_file "$f" "$OLD_LIB" "$NEW_LIB"
  replace_in_file "$f" "$OLD_NS" "$NEW_NS"
done

# Optional tests directory rename in content
shopt -s nullglob
for f in tests/*.cpp tests/*.hpp; do
  [[ -f "$f" ]] || continue
  replace_in_file "$f" "$OLD_NAME" "$NEW_NAME"
  replace_in_file "$f" "$OLD_LIB" "$NEW_LIB"
  replace_in_file "$f" "$OLD_NS" "$NEW_NS"
done
shopt -u nullglob

# Update namespaces in source/include trees
while IFS= read -r -d '' f; do
  replace_in_file "$f" "$OLD_NAME" "$NEW_NAME"
  replace_in_file "$f" "$OLD_LIB" "$NEW_LIB"
  replace_in_file "$f" "$OLD_NS" "$NEW_NS"
done < <(find include src tests -type f \( -name "*.hpp" -o -name "*.h" -o -name "*.cpp" \) -print0)

# Rename assets file if present
if [[ -f "assets/${OLD_NAME}Logo.svg" ]]; then
  mv "assets/${OLD_NAME}Logo.svg" "assets/${NEW_NAME}Logo.svg"
fi

# Rename include directory if present
if [[ -d "include/${OLD_LIB}" ]]; then
  mv "include/${OLD_LIB}" "include/${NEW_LIB}"
fi

# Rename library files if present
move_if_exists "include/${OLD_LIB}/${OLD_LIB}.hpp" "include/${NEW_LIB}/${NEW_LIB}.hpp"
move_if_exists "include/${NEW_LIB}/${OLD_LIB}.hpp" "include/${NEW_LIB}/${NEW_LIB}.hpp"
move_if_exists "src/lib/${OLD_LIB}.cpp" "src/lib/${NEW_LIB}.cpp"

popd >/dev/null

echo "✓ Renamed template to:"
echo "  Project:   $NEW_NAME"
echo "  Library:   $NEW_LIB"
echo "  Namespace: $NEW_NS"
