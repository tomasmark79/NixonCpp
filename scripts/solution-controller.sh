#!/usr/bin/env bash
# NixonCpp task controller (bash rewrite)
# MIT License Copyright (c) 2024-2026 Tomáš Mark

set -euo pipefail

CONTROLLER_VERSION="v20260205"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR_BASE="$PROJECT_ROOT/build"

resolve_project_name() {
    local name
    name=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null \
        | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
    if [[ -z "${name}" ]]; then
        name="NixonCpp"
    fi
    echo "$name"
}

BUILD_PRODUCT="${1:-both}"
TASK_NAME="${2:-}"
BUILD_ARCH="${3:-native}"
BUILD_TYPE_RAW="${4:-release}"
BUILD_COMPILER_RAW="${5:-${NIXONCPP_COMPILER:-}}"

if [[ -z "$TASK_NAME" ]]; then
    echo "Task name is missing. Exiting." >&2
    exit 1
fi

BUILD_TYPE="${BUILD_TYPE_RAW,,}"

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
LIGHTBLUE="\033[1;34m"
GREY="\033[1;30m"
NC="\033[0m"

log_header() {
    echo -e "${GREEN}NixonCpp Solution Controller - ${CONTROLLER_VERSION}${NC}"
    echo -e "${GREY}Task\t: ${TASK_NAME}${NC}"
    echo -e "${LIGHTBLUE}Arch\t: ${BUILD_ARCH}${NC}"
    echo -e "${LIGHTBLUE}Type\t: ${BUILD_TYPE}${NC}"
    if [[ -n "$BUILD_COMPILER_RAW" ]]; then
        echo -e "${LIGHTBLUE}Compiler: ${BUILD_COMPILER_RAW}${NC}"
    fi
    echo -e "${GREY}Root\t: ${PROJECT_ROOT}${NC}"
    echo ""
}

resolve_build_dir() {
    case "$BUILD_ARCH" in
        native|x86_64|default)
            if [[ "${BUILD_COMPILER_RAW,,}" == "clang" || "${BUILD_COMPILER_RAW,,}" == "llvm" ]]; then
                echo "$BUILD_DIR_BASE/builddir-${BUILD_TYPE}-clang"
            else
                echo "$BUILD_DIR_BASE/builddir-${BUILD_TYPE}"
            fi
            ;;
        aarch64|arm64)
            echo "$BUILD_DIR_BASE/builddir-aarch64-${BUILD_TYPE}"
            ;;
        windows|win64)
            echo "$BUILD_DIR_BASE/builddir-windows-${BUILD_TYPE}"
            ;;
        wasm|emscripten)
            echo "$BUILD_DIR_BASE/builddir-wasm-${BUILD_TYPE}"
            ;;
        *)
            echo "Unknown architecture: $BUILD_ARCH" >&2
            exit 1
            ;;
    esac
}

BUILD_DIR="$(resolve_build_dir)"

run_build() {
    if [[ -n "$BUILD_COMPILER_RAW" ]]; then
        "$PROJECT_ROOT/scripts/build.sh" "$BUILD_ARCH" "$BUILD_TYPE" "$BUILD_COMPILER_RAW"
    else
        "$PROJECT_ROOT/scripts/build.sh" "$BUILD_ARCH" "$BUILD_TYPE"
    fi
}

run_configure() {
    if [[ -n "$BUILD_COMPILER_RAW" ]]; then
        env NIXONCPP_CONFIGURE_ONLY=1 "$PROJECT_ROOT/scripts/build.sh" "$BUILD_ARCH" "$BUILD_TYPE" "$BUILD_COMPILER_RAW"
    else
        env NIXONCPP_CONFIGURE_ONLY=1 "$PROJECT_ROOT/scripts/build.sh" "$BUILD_ARCH" "$BUILD_TYPE"
    fi
}

clean_build() {
    if [[ -d "$BUILD_DIR" ]]; then
        echo -e "${LIGHTBLUE}> Removing build directory: ${BUILD_DIR}${NC}"
        rm -rf "$BUILD_DIR"
    else
        echo -e "${YELLOW}Build directory not found: ${BUILD_DIR}${NC}"
    fi
}

run_tests() {
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "Build directory not found. Building first..."
        run_build
    fi
    meson test -C "$BUILD_DIR"
}

run_install() {
    if [[ ! -d "$BUILD_DIR" ]]; then
        echo "Build directory not found. Run build first." >&2
        exit 1
    fi
    meson install -C "$BUILD_DIR"
}

launch_application() {
    local app_name
    local exe_path

    app_name="$(resolve_project_name)"
    if [[ "$BUILD_ARCH" == "windows" || "$BUILD_ARCH" == "win64" ]]; then
        exe_path="$BUILD_DIR/${app_name}.exe"
    else
        exe_path="$BUILD_DIR/${app_name}"
    fi

    if [[ ! -f "$exe_path" ]]; then
        echo "Executable not found: $exe_path" >&2
        echo "Build first (or check build type/arch)." >&2
        exit 1
    fi

    (cd "$BUILD_DIR" && "$exe_path")
}

run_package() {
    "$PROJECT_ROOT/scripts/package.sh" "$BUILD_ARCH" "${BUILD_TYPE}"
}

source_dirs=("$PROJECT_ROOT/src" "$PROJECT_ROOT/include" "$PROJECT_ROOT/tests")

build_line_filter() {
    local regex
    regex="${PROJECT_ROOT}/(src|include|tests)/.*"
    echo "[{\"name\":\"${regex}\"}]"
}

clang_tidy() {
    if ! command -v clang-tidy >/dev/null 2>&1; then
        echo "clang-tidy not found." >&2
        exit 1
    fi
    if [[ ! -f "$BUILD_DIR/compile_commands.json" ]]; then
        echo "compile_commands.json not found in $BUILD_DIR. Build first." >&2
        exit 1
    fi

    echo -e "${LIGHTBLUE}Running clang-tidy...${NC}"
    local line_filter
    line_filter="$(build_line_filter)"

    find "${source_dirs[@]}" \
        -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) -print0 \
        | xargs -0 -n1 clang-tidy -p "$BUILD_DIR" -system-headers=0 \
            -header-filter="^${PROJECT_ROOT}/(src|include|tests)/" \
            -line-filter="$line_filter"
}

clang_format() {
    local fmt
    if command -v clang-format >/dev/null 2>&1; then
        fmt="clang-format"
    elif command -v clang-format-18 >/dev/null 2>&1; then
        fmt="clang-format-18"
    else
        echo "clang-format not found." >&2
        exit 1
    fi

    echo -e "${LIGHTBLUE}Running clang-format...${NC}"
    find "${source_dirs[@]}" \
        -type f \( -name "*.c" -o -name "*.cpp" -o -name "*.h" -o -name "*.hpp" \) -print0 \
        | while IFS= read -r -d '' file; do
            echo -e "${GREY}formatting: ${file}${NC}"
            "$fmt" -i -assume-filename=.cpp "$file"
        done
}

run_doxygen() {
    if ! command -v doxygen >/dev/null 2>&1; then
        echo "Doxygen is not installed. Please install it to generate documentation." >&2
        exit 1
    fi

    if ! command -v dot >/dev/null 2>&1; then
        echo "Graphviz 'dot' not found. Install graphviz to generate diagrams." >&2
    fi

    local doxygen_config="$PROJECT_ROOT/Doxyfile"
    if [[ ! -f "$doxygen_config" ]]; then
        echo "Doxygen configuration file '$doxygen_config' not found." >&2
        exit 1
    fi

    (cd "$PROJECT_ROOT" && doxygen "$doxygen_config")
    echo "Doxygen documentation generated."

    local index_file="$PROJECT_ROOT/docs/html/index.html"
    if [[ -f "$index_file" ]]; then
        local index_url="file://${index_file}"
        echo "Documentation: ${index_url}"
    else
        echo "Documentation index file not found at $index_file"
    fi
}

launch_emscripten_server() {
    local port="6931"
    local base_dir="$PROJECT_ROOT"
    local app_name="$(resolve_project_name)"
    local html_rel="build/builddir-wasm-${BUILD_TYPE}/${app_name}.html"
    local html_path="$PROJECT_ROOT/$html_rel"

    # Kill any existing emrun processes first
    if command -v pkill >/dev/null 2>&1; then
        pkill -f 'emrun.*' >/dev/null 2>&1 || true
        pkill -f 'python.*emscripten_server' >/dev/null 2>&1 || true
    fi
    if command -v lsof >/dev/null 2>&1; then
        pids=$(lsof -ti tcp:"$port" || true)
        if [[ -n "$pids" ]]; then
            kill -9 $pids >/dev/null 2>&1 || true
        fi
    elif command -v fuser >/dev/null 2>&1; then
        fuser -k "$port"/tcp >/dev/null 2>&1 || true
    fi

    if command -v python3 >/dev/null 2>&1; then
        echo -e "${GREEN}Starting COOP/COEP python server on port $port...${NC}"
        nohup env BASE_DIR="$base_dir" PORT="$port" python3 "$PROJECT_ROOT/scripts/emscripten_server.py" >/dev/null 2>&1 &
    elif command -v python >/dev/null 2>&1; then
        echo -e "${GREEN}Starting COOP/COEP python server on port $port...${NC}"
        nohup env BASE_DIR="$base_dir" PORT="$port" python "$PROJECT_ROOT/scripts/emscripten_server.py" >/dev/null 2>&1 &
    elif command -v node >/dev/null 2>&1; then
        echo -e "${GREEN}Starting COOP/COEP node server on port $port...${NC}"
        nohup env BASE_DIR="$base_dir" PORT="$port" node "$PROJECT_ROOT/scripts/emscripten_server.js" >/dev/null 2>&1 &
    elif command -v emrun >/dev/null 2>&1; then
        echo -e "${YELLOW}Starting emrun server on port $port (no COOP/COEP headers).${NC}"
        echo -e "${YELLOW}SharedArrayBuffer will fail without COOP/COEP. Install python or node to fix.${NC}"
        nohup emrun --port "$port" "$base_dir" >/dev/null 2>&1 &
    else
        echo "Neither python nor emrun is available to launch a server." >&2
        exit 1
    fi

    if [[ -f "$html_path" ]]; then
        local url="http://localhost:${port}/${html_rel}"
        echo -e "${LIGHTBLUE}Server running at: ${url}${NC}"
        if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$url" >/dev/null 2>&1 || true
        elif command -v open >/dev/null 2>&1; then
            open "$url" >/dev/null 2>&1 || true
        fi
    else
        echo -e "${YELLOW}HTML not found: ${html_path}${NC}"
        echo -e "${LIGHTBLUE}Server running at: http://localhost:${port}/${NC}"
    fi
}

zero_to_build() {
    clean_build
    run_build
}

zero_to_hero() {
    zero_to_build
    run_tests
    run_package
}

log_header

case "$TASK_NAME" in
    "Zero to Build")
        zero_to_build
        ;;
    "Zero to Hero")
        zero_to_hero
        ;;
    "Clean Build")
        clean_build
        ;;
    "Build")
        run_build
        ;;
    "Configure")
        run_configure
        ;;
    "Run Tests")
        run_tests
        ;;
    "Install built components")
        run_install
        ;;
    "Launch Application")
        launch_application
        ;;
    "Create Package")
        run_package
        ;;
    "clang-tidy linting")
        clang_tidy
        ;;
    "Format Code")
        clang_format
        ;;
    "Generate Documentation")
        run_doxygen
        ;;
    "Launch Emscripten Server")
        launch_emscripten_server
        ;;
    *)
        echo "Received unknown task: $TASK_NAME" >&2
        exit 1
        ;;
esac

