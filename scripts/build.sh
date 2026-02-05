#!/usr/bin/env bash
# Unified build script for native + cross

set -euo pipefail

ARCH="${1:-native}"
BUILD_TYPE="${2:-release}"
COMPILER_RAW="${3:-${NIXONCPP_COMPILER:-gcc}}"
COMPILER="${COMPILER_RAW,,}"

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
if [ -z "${NIXONCPP_NIX_SHELL:-}" ] || [ "$NIXONCPP_NIX_SHELL" != "$REQUIRED_SHELL" ]; then
    if [ -z "${NIXONCPP_NIX_SHELL:-}" ]; then
        echo "⚠️  Entering nix develop ($REQUIRED_SHELL)..."
    else
        echo "⚠️  Switching to nix develop ($REQUIRED_SHELL)..."
    fi
    if [ "$REQUIRED_SHELL" = "default" ]; then
        exec nix develop "$PROJECT_ROOT/nix" --command env NIXONCPP_NIX_SHELL=default "$0" "$@"
    else
        exec nix develop "$PROJECT_ROOT/nix#$REQUIRED_SHELL" --command env NIXONCPP_NIX_SHELL=$REQUIRED_SHELL "$0" "$@"
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
    echo "📋 Reconfiguring build..."
    if [[ "$ARCH" == "native" || "$ARCH" == "x86_64" ]]; then
        CC="$CC_CMD" CXX="$CXX_CMD" meson setup --reconfigure "$BUILD_DIR" --buildtype="$BUILD_TYPE" $CROSS_FILE
    else
        meson setup --reconfigure "$BUILD_DIR" --buildtype="$BUILD_TYPE" $CROSS_FILE
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
meson compile -C "$BUILD_DIR"

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
        echo "  nix develop ./nix#aarch64 --command qemu-aarch64 -L \$QEMU_LD_PREFIX ./$BUILD_DIR/NixonCpp"
        ;;
    windows|win64)
        echo ""
        echo "To run (requires Wine):"
        echo "  wine64 ./$BUILD_DIR/NixonCpp.exe"
        ;;
    wasm|emscripten)
        echo ""
        echo "To run:"
        echo "  node ./$BUILD_DIR/NixonCpp.js"
        ;;
esac
