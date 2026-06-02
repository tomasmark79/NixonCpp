#!/usr/bin/env bash
# Unified build script for native + cross

set -euo pipefail

ARCH="${1:-native}"
BUILD_TYPE="${2:-release}"
COMPILER_RAW="${3:-${PROJECT_COMPILER:-gcc}}"
COMPILER="${COMPILER_RAW,,}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
APP_NAME=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
if [[ -z "$APP_NAME" ]]; then APP_NAME="Project"; fi

# Determine which flake dev shell to use based on architecture
case "$ARCH" in
    aarch64|arm64)
        REQUIRED_SHELL="aarch64"
        ;;
    windows|win64)
        REQUIRED_SHELL="windows"
        ;;
    wasm|emscripten)
        REQUIRED_SHELL="wasm"
        ;;
    *)
        REQUIRED_SHELL="default"
        ;;
esac

# Check if we need to enter a different dev shell
if [ -z "${PROJECT_NIX_SHELL:-}" ] || [ "$PROJECT_NIX_SHELL" != "$REQUIRED_SHELL" ]; then
    if ! command -v nix >/dev/null 2>&1; then
        if [ "$REQUIRED_SHELL" != "default" ]; then
            echo "❌ Nix is required for cross builds ($REQUIRED_SHELL), but 'nix' was not found." >&2
            echo "   Options:" >&2
            echo "   - Install Nix (recommended), then re-run" >&2
            echo "   - Use GitHub Codespaces with the provided devcontainer" >&2
            exit 1
        fi
        echo "⚠️  Nix not found; continuing with system toolchain (native build only)."
        export PROJECT_NIX_SHELL="default"
    fi

    if [ -z "${PROJECT_NIX_SHELL:-}" ]; then
        echo "⚠️  Entering nix develop ($REQUIRED_SHELL)..."
    else
        echo "⚠️  Switching to nix develop ($REQUIRED_SHELL)..."
    fi
    if [ "$REQUIRED_SHELL" = "default" ]; then
        exec nix develop "$PROJECT_ROOT/nix" --command env PROJECT_NIX_SHELL=default "$0" "$@"
    else
        exec nix develop "$PROJECT_ROOT/nix#$REQUIRED_SHELL" --command env PROJECT_NIX_SHELL=$REQUIRED_SHELL "$0" "$@"
    fi
fi

case "$ARCH" in
    native|x86_64)
        case "$COMPILER" in
            ""|"gcc"|"gnu")
                COMPILER_LABEL="gcc"
                BUILD_DIR="build/builddir-${BUILD_TYPE}"
                CC_CMD="gcc"
                CXX_CMD="g++"
                ;;
            "clang"|"llvm")
                COMPILER_LABEL="clang"
                BUILD_DIR="build/builddir-${BUILD_TYPE}-clang"
                CC_CMD="clang"
                CXX_CMD="clang++"
                ;;
            *)
                echo "❌ Unknown compiler: $COMPILER_RAW" >&2
                echo "   Supported: gcc, clang" >&2
                exit 1
                ;;
        esac
        CROSS_FILE=""
        echo "🔨 Building for native x86_64..."
        echo "   Compiler: $COMPILER_LABEL"
        ;;
    aarch64|arm64)
        if [[ "$COMPILER" != "" && "$COMPILER" != "gcc" && "$COMPILER" != "gnu" ]]; then
            echo "⚠️  Compiler override ignored for cross builds (using toolchain from cross file)."
        fi
        BUILD_DIR="build/builddir-aarch64-${BUILD_TYPE}"
        CROSS_FILE="--cross-file nix/cross/linux-to-aarch64.ini"
        echo "🔨 Building for aarch64 (ARM64)..."
        ;;
    windows|win64)
        if [[ "$COMPILER" != "" && "$COMPILER" != "gcc" && "$COMPILER" != "gnu" ]]; then
            echo "⚠️  Compiler override ignored for cross builds (using toolchain from cross file)."
        fi
        BUILD_DIR="build/builddir-windows-${BUILD_TYPE}"
        CROSS_FILE="--cross-file nix/cross/linux-to-windows.ini"
        echo "🔨 Building for Windows (MinGW)..."
        ;;
    wasm|emscripten)
        if [[ "$COMPILER" != "" && "$COMPILER" != "gcc" && "$COMPILER" != "gnu" ]]; then
            echo "⚠️  Compiler override ignored for cross builds (using toolchain from cross file)."
        fi
        BUILD_DIR="build/builddir-wasm-${BUILD_TYPE}"
        CROSS_FILE="--cross-file nix/cross/linux-to-wasm.ini"
        echo "🔨 Building for WebAssembly..."
        ;;
    *)
        echo "❌ Unknown architecture: $ARCH"
        echo "Usage: $0 [native|aarch64|windows|wasm] [debug|release|minsize|debugoptimized] [gcc|clang]"
        exit 1
        ;;
esac

echo "   Build type: $BUILD_TYPE"
echo "   Build dir: $BUILD_DIR"
echo ""

stage_wasm_debug_sources() {
    local map_file="$BUILD_DIR/$APP_NAME.wasm.map"
    local debug_src_dir="$BUILD_DIR/debug-src"

    if [[ "$ARCH" != "wasm" && "$ARCH" != "emscripten" ]]; then
        return 0
    fi

    case "$BUILD_TYPE" in
        debug|debugoptimized)
            ;;
        *)
            return 0
            ;;
    esac

    if [[ ! -f "$map_file" ]]; then
        return 0
    fi

    mkdir -p "$debug_src_dir"
    rm -rf "$debug_src_dir/src" "$debug_src_dir/include"
    cp -R "$PROJECT_ROOT/src" "$PROJECT_ROOT/include" "$debug_src_dir/"

    sed -i \
        -e 's#"\.\./\.\./src/#"debug-src/src/#g' \
        -e 's#"\.\./\.\./include/#"debug-src/include/#g' \
        "$map_file"

    echo ""
    echo "🧭 Staged standalone debug sources in: ./$BUILD_DIR/debug-src"
}

if [[ "$ARCH" == "native" || "$ARCH" == "x86_64" ]]; then
    if ! command -v "$CC_CMD" >/dev/null 2>&1; then
        echo "❌ Compiler not found: $CC_CMD" >&2
        exit 1
    fi
fi

# Configure
if [ ! -d "$BUILD_DIR" ]; then
    echo "📋 Configuring build..."
    if [[ "$ARCH" == "native" || "$ARCH" == "x86_64" ]]; then
        CC="$CC_CMD" CXX="$CXX_CMD" meson setup "$BUILD_DIR" --buildtype="$BUILD_TYPE" $CROSS_FILE
    else
        meson setup "$BUILD_DIR" --buildtype="$BUILD_TYPE" $CROSS_FILE
    fi
else
    needs_reconfigure=0
    coredata="$BUILD_DIR/meson-private/coredata.dat"

    if [[ "${NIXONCPP_RECONFIGURE:-}" == "1" ]]; then
        needs_reconfigure=1
    elif [[ ! -f "$coredata" ]]; then
        needs_reconfigure=1
    else
        # Reconfigure only when Meson build definition changes were detected.
        # This makes the check universal: any meson.build under the project (except build/)
        # will trigger reconfigure if it's newer than coredata.dat.
        while IFS= read -r f; do
            if [[ -f "$f" && "$f" -nt "$coredata" ]]; then
                needs_reconfigure=1
                break
            fi
        done < <(
            find "$PROJECT_ROOT" -path "$PROJECT_ROOT/build" -prune -o \
                -name meson.build -print
        )

        # meson_options.txt is not a meson.build, so check it explicitly.
        if [[ "$needs_reconfigure" == "0" ]]; then
            if [[ -f "$PROJECT_ROOT/meson_options.txt" && "$PROJECT_ROOT/meson_options.txt" -nt "$coredata" ]]; then
                needs_reconfigure=1
            fi
        fi

        if [[ -n "$CROSS_FILE" ]]; then
            cross_path="${CROSS_FILE#--cross-file }"
            if [[ -f "$PROJECT_ROOT/$cross_path" && "$PROJECT_ROOT/$cross_path" -nt "$coredata" ]]; then
                needs_reconfigure=1
            fi
        fi

        if [[ -d "$PROJECT_ROOT/subprojects" ]]; then
            for f in "$PROJECT_ROOT"/subprojects/*.wrap; do
                if [[ -f "$f" && "$f" -nt "$coredata" ]]; then
                    needs_reconfigure=1
                fi
            done
        fi
    fi

    if [[ "$needs_reconfigure" == "1" ]]; then
        echo "📋 Reconfiguring build..."
        if [[ "$ARCH" == "native" || "$ARCH" == "x86_64" ]]; then
            CC="$CC_CMD" CXX="$CXX_CMD" meson setup --reconfigure "$BUILD_DIR" --buildtype="$BUILD_TYPE" $CROSS_FILE
        else
            meson setup --reconfigure "$BUILD_DIR" --buildtype="$BUILD_TYPE" $CROSS_FILE
        fi
    else
        echo "📋 Skipping reconfigure (no build config changes detected)"
    fi
fi

echo ""
if [[ "${NIXONCPP_CONFIGURE_ONLY:-}" == "1" ]]; then
    echo "✅ Configure complete!"
    echo ""
    echo "Output directory: ./$BUILD_DIR"
    exit 0
fi

echo "🔧 Compiling..."

# Patch build.ninja: replace relative ../../ paths with absolute paths so that
# GCC diagnostics (file:line:col) produce clickable links in VS Code terminal.
# Idempotent — already-patched paths are unaffected.
if [[ -f "$BUILD_DIR/build.ninja" ]]; then
    sed -i "s|\.\./\.\./|$PROJECT_ROOT/|g" "$BUILD_DIR/build.ninja"
fi

meson compile -C "$BUILD_DIR"

stage_wasm_debug_sources

# Link compile_commands.json to project root for tooling
if [ -f "$BUILD_DIR/compile_commands.json" ]; then
    ln -sf "$BUILD_DIR/compile_commands.json" "$PROJECT_ROOT/compile_commands.json"
fi

echo ""
echo "✅ Build complete!"
echo ""
echo "Output directory: ./$BUILD_DIR"

# Architecture-specific instructions
case "$ARCH" in
    aarch64|arm64)
        echo ""
        echo "To run on x86_64 (via QEMU):"
        echo "  nix develop ./nix#aarch64 --command bash -c 'qemu-aarch64 -L \"\$QEMU_LD_PREFIX\" ./$BUILD_DIR/$APP_NAME'"
        ;;
    windows|win64)
        echo ""
        echo "To run (requires Wine):"
        echo "  wine64 ./$BUILD_DIR/$APP_NAME.exe"
        ;;
    wasm|emscripten)
        echo ""
        echo "To run:"
        echo "  node ./$BUILD_DIR/$APP_NAME.js"
        ;;
esac
