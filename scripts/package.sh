#!/usr/bin/env bash
# Universal packaging script for all platforms
# Usage: ./package.sh [arch] [prefix]

set -e

ARCH="${1:-native}"
BUILD_TYPE="${2:-release}"
INSTALL_PREFIX="${3:-/usr/local}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Resolve project and library names (overridable via env)
get_project_name() {
    local name
    name=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null \
        | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
    if [[ -z "${name}" ]]; then
        name="NixonCpp"
    fi
    echo "$name"
}

get_lib_name() {
    local name
    name=$(grep -m1 -E "(shared_library|static_library)\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null \
        | sed -E "s/.*\(['\"]([^'\"]+)['\"].*/\1/")
    if [[ -z "${name}" ]]; then
        name="${APP_NAME}Lib"
    fi
    echo "$name"
}

APP_NAME="${NIXONCPP_APP_NAME:-$(get_project_name)}"
LIB_NAME="${NIXONCPP_LIB_NAME:-$(get_lib_name)}"

replace_tokens_in_file() {
    local file="$1"
    local app_name="$2"
    local lib_name="$3"

    python3 - <<'PY' "$file" "$app_name" "$lib_name"
import sys
from pathlib import Path

path = Path(sys.argv[1])
app = sys.argv[2]
lib = sys.argv[3]

text = path.read_text(encoding="utf-8")
text = text.replace("__APP_NAME__", app)
text = text.replace("__LIB_NAME__", lib)
text = text.replace("__APP_SHARE__", app)
path.write_text(text, encoding="utf-8")
PY
}

# Determine build directory and package name based on architecture
case "$ARCH" in
    native|x86_64)
        BUILD_DIR="build/builddir-${BUILD_TYPE}"
        PACKAGE_NAME="${APP_NAME}-x86_64-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-x86_64-${BUILD_TYPE}"
        ARCH_DISPLAY="x86_64 (Native)"
        ;;
    aarch64|arm64)
        BUILD_DIR="build/builddir-aarch64-${BUILD_TYPE}"
        PACKAGE_NAME="${APP_NAME}-aarch64-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-aarch64-${BUILD_TYPE}"
        ARCH_DISPLAY="ARM64 (aarch64)"
        ;;
    windows|win64)
        BUILD_DIR="build/builddir-windows-${BUILD_TYPE}"
        PACKAGE_NAME="${APP_NAME}-windows-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-windows-${BUILD_TYPE}"
        ARCH_DISPLAY="Windows (x86_64)"
        ;;
    wasm|emscripten)
        BUILD_DIR="build/builddir-wasm-${BUILD_TYPE}"
        PACKAGE_NAME="${APP_NAME}-wasm-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-wasm-${BUILD_TYPE}"
        ARCH_DISPLAY="WebAssembly"
        ;;
    *)
        echo "❌ Unknown architecture: $ARCH"
        echo "Usage: $0 [native|aarch64|windows|wasm] [prefix]"
        exit 1
        ;;
esac

echo "📦 Creating $ARCH_DISPLAY deployment package..."
echo "   Build directory: $BUILD_DIR"
echo "   Install prefix: $INSTALL_PREFIX"
echo ""

# Check if build exists
if [ ! -f "$BUILD_DIR/${APP_NAME}" ] && [ ! -f "$BUILD_DIR/${APP_NAME}.exe" ] && [ ! -f "$BUILD_DIR/${APP_NAME}.js" ]; then
    echo "❌ Build not found for $ARCH. Please run: make cross-$ARCH"
    exit 1
fi

# Create package directory structure
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"/"bin" "$PACKAGE_DIR"/"lib" "$PACKAGE_DIR"/"share/${APP_NAME}" "$PACKAGE_DIR"/"include/${LIB_NAME}"

echo "📋 Copying files..."

# Platform-specific packaging
case "$ARCH" in
    wasm|emscripten)
        # WebAssembly - just copy .js and .wasm files
        cp "$BUILD_DIR/${APP_NAME}.js" "$PACKAGE_DIR/"
        cp "$BUILD_DIR/${APP_NAME}.wasm" "$PACKAGE_DIR/"
        echo "   ✓ WebAssembly: ${APP_NAME}.js + .wasm"
        ;;
        
    windows|win64)
        # Windows - copy .exe and necessary DLLs
        cp "$BUILD_DIR/${APP_NAME}.exe" "$PACKAGE_DIR/bin/"
        chmod +x "$PACKAGE_DIR/bin/${APP_NAME}.exe"
        
        # Copy DLL files if they exist in build directory
        if ls "$BUILD_DIR"/*.dll 1> /dev/null 2>&1; then
            cp "$BUILD_DIR"/*.dll "$PACKAGE_DIR/bin/"
        fi
        
        echo "   ✓ Executable: ${APP_NAME}.exe"
        ;;
        
    *)
        # Unix-like systems (native, aarch64)
        cp "$BUILD_DIR/${APP_NAME}" "$PACKAGE_DIR/bin/"
        chmod +x "$PACKAGE_DIR/bin/${APP_NAME}"
        
        # Fix dynamic linker path for non-Nix systems
        if command -v patchelf &> /dev/null && [ "$ARCH" != "native" ]; then
            echo "   🔧 Patching interpreter path..."
            patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 "$PACKAGE_DIR/bin/${APP_NAME}" 2>/dev/null || \
            patchelf --set-interpreter /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 "$PACKAGE_DIR/bin/${APP_NAME}" 2>/dev/null || \
            echo "   ⚠️  Could not patch interpreter (may need manual fix on target system)"
        elif [ "$ARCH" != "native" ]; then
            echo "   ⚠️  patchelf not found; interpreter may still point to /nix/store"
        fi
        
        echo "   ✓ Executable: ${APP_NAME}"
        
        # Copy shared library
        if [ -f "$BUILD_DIR/lib${LIB_NAME}.so" ]; then
            cp "$BUILD_DIR/lib${LIB_NAME}.so" "$PACKAGE_DIR/lib/"
            
            # Fix RPATH to use standard system paths
            if command -v patchelf &> /dev/null; then
                patchelf --set-rpath '$ORIGIN/../lib:/usr/local/lib:/usr/lib:/lib' "$PACKAGE_DIR/bin/${APP_NAME}" 2>/dev/null || true
                patchelf --set-rpath '$ORIGIN:/usr/local/lib:/usr/lib:/lib' "$PACKAGE_DIR/lib/lib${LIB_NAME}.so" 2>/dev/null || true
            fi
            
            echo "   ✓ Library: lib${LIB_NAME}.so"
        fi
        
        # Copy static library (optional)
        if [ -f "$BUILD_DIR/lib${LIB_NAME}.a" ]; then
            cp "$BUILD_DIR/lib${LIB_NAME}.a" "$PACKAGE_DIR/lib/"
            echo "   ✓ Static library: lib${LIB_NAME}.a"
        fi
        ;;
esac

# Copy headers (optional, for development)
if [ "$ARCH" != "wasm" ] && [ "$ARCH" != "emscripten" ]; then
    if [ -d "$PROJECT_ROOT/include/${LIB_NAME}" ]; then
        mkdir -p "$PACKAGE_DIR/include/${LIB_NAME}"
        if compgen -G "$PROJECT_ROOT/include/${LIB_NAME}/*" > /dev/null; then
            cp -r "$PROJECT_ROOT/include/${LIB_NAME}/"* "$PACKAGE_DIR/include/${LIB_NAME}/"
            echo "   ✓ Headers: ${LIB_NAME}/*.hpp"
        else
            echo "   ⚠️  No headers found in: $PROJECT_ROOT/include/${LIB_NAME}"
        fi
    else
        echo "   ⚠️  Headers directory not found: $PROJECT_ROOT/include/${LIB_NAME}"
    fi
fi

# Copy assets (except for WebAssembly which has them embedded)
if [ "$ARCH" != "wasm" ] && [ "$ARCH" != "emscripten" ]; then
    if [ -d "$PROJECT_ROOT/assets" ]; then
        cp -r "$PROJECT_ROOT/assets" "$PACKAGE_DIR/share/${APP_NAME}/"
        echo "   ✓ Assets: customstrings.json, etc."
    else
        echo "   ⚠️  Assets directory not found: $PROJECT_ROOT/assets"
    fi
fi

# Create installation script for Unix-like systems
if [ "$ARCH" != "wasm" ] && [ "$ARCH" != "emscripten" ]; then
    cat > "$PACKAGE_DIR/install.sh" << 'EOF'
#!/usr/bin/env bash
# Installation Script

set -e

INSTALL_PREFIX="${1:-/usr/local}"

echo "🚀 Installing __APP_NAME__ to $INSTALL_PREFIX..."
echo ""

# Check if running as root for system-wide installation
if [ "$INSTALL_PREFIX" = "/usr/local" ] || [ "$INSTALL_PREFIX" = "/usr" ]; then
    if [ "$EUID" -ne 0 ]; then 
        echo "❌ Please run with sudo for system-wide installation:"
        echo "   sudo ./install.sh"
        exit 1
    fi
fi

# Create directories
mkdir -p "$INSTALL_PREFIX"/{bin,lib,share/__APP_SHARE__,include}

# Install files
echo "📋 Installing files..."
cp -v "bin/__APP_NAME__" "$INSTALL_PREFIX/bin/"
[ -f "lib/lib__LIB_NAME__.so" ] && cp -v "lib/lib__LIB_NAME__.so" "$INSTALL_PREFIX/lib/"
[ -f "lib/lib__LIB_NAME__.a" ] && cp -v "lib/lib__LIB_NAME__.a" "$INSTALL_PREFIX/lib/"
[ -d "include/__LIB_NAME__" ] && cp -rv "include/__LIB_NAME__" "$INSTALL_PREFIX/include/"
[ -d "share/__APP_SHARE__" ] && cp -rv "share/__APP_SHARE__" "$INSTALL_PREFIX/share/"

# Fix interpreter/RPATH if needed (e.g., when built in Nix)
if command -v patchelf &> /dev/null; then
    if [ -f "$INSTALL_PREFIX/bin/__APP_NAME__" ]; then
        patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 "$INSTALL_PREFIX/bin/__APP_NAME__" 2>/dev/null || \
        patchelf --set-interpreter /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 "$INSTALL_PREFIX/bin/__APP_NAME__" 2>/dev/null || true
        patchelf --set-rpath '$ORIGIN/../lib:/usr/local/lib:/usr/lib:/lib' "$INSTALL_PREFIX/bin/__APP_NAME__" 2>/dev/null || true
    fi
    if [ -f "$INSTALL_PREFIX/lib/lib__LIB_NAME__.so" ]; then
        patchelf --set-rpath '$ORIGIN:/usr/local/lib:/usr/lib:/lib' "$INSTALL_PREFIX/lib/lib__LIB_NAME__.so" 2>/dev/null || true
    fi
else
    if command -v readelf &> /dev/null && [ -f "$INSTALL_PREFIX/bin/__APP_NAME__" ]; then
        if readelf -l "$INSTALL_PREFIX/bin/__APP_NAME__" | grep -q "/nix/store/"; then
            echo ""
            echo "❌ patchelf not found and binary uses /nix/store interpreter."
            echo "   Install patchelf (e.g., sudo apt install patchelf) and rerun install.sh."
            exit 1
        fi
    fi
fi

# Update library cache
if command -v ldconfig &> /dev/null; then
    echo ""
    echo "📚 Updating library cache..."
    ldconfig
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Run the application:"
echo "   $INSTALL_PREFIX/bin/__APP_NAME__"
EOF

    chmod +x "$PACKAGE_DIR/install.sh"
    replace_tokens_in_file "$PACKAGE_DIR/install.sh" "$APP_NAME" "$LIB_NAME"

    # Create uninstall script
    cat > "$PACKAGE_DIR/uninstall.sh" << 'EOF'
#!/usr/bin/env bash
# Uninstallation Script

set -e

INSTALL_PREFIX="${1:-/usr/local}"

echo "🗑️  Uninstalling __APP_NAME__ from $INSTALL_PREFIX..."
echo ""

# Check if running as root for system-wide uninstallation
if [ "$INSTALL_PREFIX" = "/usr/local" ] || [ "$INSTALL_PREFIX" = "/usr" ]; then
    if [ "$EUID" -ne 0 ]; then 
        echo "❌ Please run with sudo for system-wide uninstallation:"
        echo "   sudo ./uninstall.sh"
        exit 1
    fi
fi

# Remove files
echo "📋 Removing files..."
rm -vf "$INSTALL_PREFIX/bin/__APP_NAME__"
rm -vf "$INSTALL_PREFIX/lib/lib__LIB_NAME__.so"
rm -vf "$INSTALL_PREFIX/lib/lib__LIB_NAME__.a"
rm -rvf "$INSTALL_PREFIX/include/__LIB_NAME__"
rm -rvf "$INSTALL_PREFIX/share/__APP_SHARE__"

# Update library cache
if command -v ldconfig &> /dev/null; then
    echo ""
    echo "📚 Updating library cache..."
    ldconfig
fi

echo ""
echo "✅ Uninstallation complete!"
EOF

    chmod +x "$PACKAGE_DIR/uninstall.sh"
    replace_tokens_in_file "$PACKAGE_DIR/uninstall.sh" "$APP_NAME" "$LIB_NAME"
fi

# Create README
cat > "$PACKAGE_DIR/README.txt" << EOF
${APP_NAME} $ARCH_DISPLAY Package
$(printf '=%.0s' {1..60})

EOF

case "$ARCH" in
    wasm|emscripten)
        cat >> "$PACKAGE_DIR/README.txt" << 'EOF'
Running WebAssembly:
--------------------

With Node.js:
    node __APP_NAME__.js

In a web browser:
    <script src="__APP_NAME__.js"></script>

Notes:
------
- Assets are embedded in the WebAssembly binary
- Requires JavaScript runtime (Node.js or browser)
EOF
        ;;
        
    windows|win64)
        cat >> "$PACKAGE_DIR/README.txt" << 'EOF'
Installation Instructions:
--------------------------

1. Copy the entire directory to your desired location
2. Run __APP_NAME__.exe

Dependencies:
-------------
All required DLL files should be included in the bin/ directory.
If any are missing, they can be obtained from the MinGW toolchain.

Running:
--------
    bin\__APP_NAME__.exe

Or add bin\ to your PATH to run from anywhere:
    __APP_NAME__
EOF
        ;;
        
    *)
        cat >> "$PACKAGE_DIR/README.txt" << 'EOF'
Installation Instructions:
--------------------------

1. System-wide installation (requires root):
   sudo ./install.sh

2. Custom location installation:
   ./install.sh /opt/myapp

3. Manual installation:
    - Copy bin/__APP_NAME__ to /usr/local/bin/
    - Copy lib/lib__LIB_NAME__.so to /usr/local/lib/
    - Copy share/__APP_SHARE__ to /usr/local/share/
   - Run: sudo ldconfig

File Structure:
---------------
bin/__APP_NAME__          - Main executable
lib/lib__LIB_NAME__.so            - Application shared library
lib/lib__LIB_NAME__.a             - Static library (optional)
include/__LIB_NAME__/             - Header files (optional)
share/__APP_SHARE__/assets/- Application assets

Dependencies:
-------------
Install required system libraries on the target device:

Debian/Ubuntu/Raspberry Pi OS:
  sudo apt update
  sudo apt install libicu76

Fedora/RHEL/Rocky:
  sudo dnf install icu

Arch Linux:
  sudo pacman -S icu

Note: libstdc++, libgcc_s, and glibc are pre-installed on all Linux systems.
Note: libfmt is compiled as header-only and included in the binary (no external dependency).

EOF

        if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
            cat >> "$PACKAGE_DIR/README.txt" << 'EOF'
Dynamic linker (interpreter):
- /lib/ld-linux-aarch64.so.1 (standard location)
- Or /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 (Debian/Ubuntu)

If you get "cannot execute: required file not found", create symlink:
  sudo ln -s /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1

EOF
        fi

        cat >> "$PACKAGE_DIR/README.txt" << 'EOF'
To check what dependencies are needed:
    ldd bin/__APP_NAME__

If libraries are missing (shown as "not found"), install them using your
package manager as described in the Dependencies section above.

Running:
--------
After installation:
    __APP_NAME__

Or directly from this directory:
    LD_LIBRARY_PATH=./lib ./bin/__APP_NAME__

Uninstallation:
---------------
  sudo ./uninstall.sh
EOF
        ;;
esac

replace_tokens_in_file "$PACKAGE_DIR/README.txt" "$APP_NAME" "$LIB_NAME"

# Create tarball
echo ""
echo "📦 Creating tarball..."
tar -czf "build/$PACKAGE_NAME.tar.gz" -C build "$(basename $PACKAGE_DIR)"

echo ""
echo "✅ Package created successfully!"
echo ""
echo "Package contents:"
echo "   Directory: $PACKAGE_DIR/"
echo "   Tarball: build/$PACKAGE_NAME.tar.gz"
echo ""

PACKAGE_BASENAME="$(basename $PACKAGE_DIR)"

case "$ARCH" in
    wasm|emscripten)
        echo "To use WebAssembly package:"
        echo "   node $PACKAGE_DIR/${APP_NAME}.js"
        ;;
    windows|win64)
        echo "To deploy on Windows:"
        echo "   1. Extract: tar -xzf build/$PACKAGE_NAME.tar.gz"
        echo "   2. Copy $PACKAGE_BASENAME to Windows machine"
        echo "   3. Run: $PACKAGE_BASENAME\\bin\\${APP_NAME}.exe"
        ;;
    *)
        echo "To deploy on $ARCH_DISPLAY device:"
        echo "   1. Transfer: scp build/$PACKAGE_NAME.tar.gz user@device:~/"
        echo "   2. Extract: tar -xzf $PACKAGE_NAME.tar.gz"
        echo "   3. Install: cd $PACKAGE_BASENAME && sudo ./install.sh"
        ;;
esac

echo ""
echo "Package structure:"
tree "$PACKAGE_DIR" 2>/dev/null || find "$PACKAGE_DIR" -print | sed -e "s;$PACKAGE_DIR;.;g;s;[^/]*\/;|____;g;s;____|; |;g"
