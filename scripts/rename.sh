#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Usage: $(basename "$0") <NewName> [NewLibName] [NewNamespace]"
  echo "Options:"
  echo "  --old-name <name>   Override current project name (auto-detected by default)"
  echo "  --old-lib <name>    Override current library name (auto-detected by default)"
  echo "  --old-ns <name>     Override current namespace (auto-detected by default)"
  echo "Examples:"
  echo "  $(basename "$0") MyApp MyAppLib myapp"
}

get_current_project_name() {
  local name
  name=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null \
    | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
  if [[ -z "$name" ]]; then
    name="NixonCpp"
  fi
  echo "$name"
}

get_current_lib_name() {
  local name
  name="$(get_current_project_name)Lib"
  echo "$name"
}

get_current_namespace() {
  local name
  name="$(get_current_project_name | tr '[:upper:]' '[:lower:]')"
  echo "$name"
}

OLD_NAME_OVERRIDE=""
OLD_LIB_OVERRIDE=""
OLD_NS_OVERRIDE=""

parse_args() {
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --old-name)
        OLD_NAME_OVERRIDE="$2"
        shift 2
        ;;
      --old-lib)
        OLD_LIB_OVERRIDE="$2"
        shift 2
        ;;
      --old-ns)
        OLD_NS_OVERRIDE="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        args+=("$1")
        shift
        ;;
    esac
  done

  CHAIN_LIST=("${args[@]}")
}

FILES=(
  "meson.build"
  "meson_options.txt"
  "Makefile"
  "README.md"
  "Doxyfile"
  ".vscode/launch.json"
  ".vscode/launch-windows.json"
  "assets/ems-mini.html"
  "tests/meson.build"
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

rename_once() {
  local NEW_NAME="$1"
  local NEW_LIB="${2:-${NEW_NAME}Lib}"
  local NEW_NS="${3:-$(echo "$NEW_NAME" | tr '[:upper:]' '[:lower:]')}"

  local OLD_NAME
  local OLD_LIB
  local OLD_NS
  OLD_NAME="${OLD_NAME_OVERRIDE:-$(get_current_project_name)}"
  OLD_LIB="${OLD_LIB_OVERRIDE:-$(get_current_lib_name)}"
  OLD_NS="${OLD_NS_OVERRIDE:-$(get_current_namespace)}"

  local FILES_LOCAL=(
    "${FILES[@]}"
    "include/${OLD_LIB}/${OLD_LIB}.hpp"
    "src/lib/${OLD_LIB}.cpp"
  )

  pushd "$PROJECT_ROOT" >/dev/null

  for f in "${FILES_LOCAL[@]}"; do
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

}

parse_args "$@"

if [[ ${#CHAIN_LIST[@]} -eq 0 ]]; then
  usage
  exit 1
fi

rename_once "${CHAIN_LIST[0]}" "${CHAIN_LIST[1]:-}" "${CHAIN_LIST[2]:-}"
