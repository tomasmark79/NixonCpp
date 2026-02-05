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

# Determine build directory and package name based on architecture
case "$ARCH" in
    native|x86_64)
        BUILD_DIR="build/builddir-${BUILD_TYPE}"
        PACKAGE_NAME="NixonCpp-x86_64-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-x86_64-${BUILD_TYPE}"
        ARCH_DISPLAY="x86_64 (Native)"
        ;;
    aarch64|arm64)
        BUILD_DIR="build/builddir-aarch64-${BUILD_TYPE}"
        PACKAGE_NAME="NixonCpp-aarch64-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-aarch64-${BUILD_TYPE}"
        ARCH_DISPLAY="ARM64 (aarch64)"
        ;;
    windows|win64)
        BUILD_DIR="build/builddir-windows-${BUILD_TYPE}"
        PACKAGE_NAME="NixonCpp-windows-${BUILD_TYPE}"
        PACKAGE_DIR="build/package-windows-${BUILD_TYPE}"
        ARCH_DISPLAY="Windows (x86_64)"
        ;;
    wasm|emscripten)
        BUILD_DIR="build/builddir-wasm-${BUILD_TYPE}"
        PACKAGE_NAME="NixonCpp-wasm-${BUILD_TYPE}"
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
if [ ! -f "$BUILD_DIR/NixonCpp" ] && [ ! -f "$BUILD_DIR/NixonCpp.exe" ] && [ ! -f "$BUILD_DIR/NixonCpp.js" ]; then
    echo "❌ Build not found for $ARCH. Please run: make cross-$ARCH"
    exit 1
fi

# Create package directory structure
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"/{bin,lib,share/NixonCpp,include/NixonCppLib}

echo "📋 Copying files..."

# Platform-specific packaging
case "$ARCH" in
    wasm|emscripten)
        # WebAssembly - just copy .js and .wasm files
        cp "$BUILD_DIR/NixonCpp.js" "$PACKAGE_DIR/"
        cp "$BUILD_DIR/NixonCpp.wasm" "$PACKAGE_DIR/"
        echo "   ✓ WebAssembly: NixonCpp.js + .wasm"
        ;;
        
    windows|win64)
        # Windows - copy .exe and necessary DLLs
        cp "$BUILD_DIR/NixonCpp.exe" "$PACKAGE_DIR/bin/"
        chmod +x "$PACKAGE_DIR/bin/NixonCpp.exe"
        
        # Copy DLL files if they exist in build directory
        if ls "$BUILD_DIR"/*.dll 1> /dev/null 2>&1; then
            cp "$BUILD_DIR"/*.dll "$PACKAGE_DIR/bin/"
        fi
        
        echo "   ✓ Executable: NixonCpp.exe"
        ;;
        
    *)
        # Unix-like systems (native, aarch64)
        cp "$BUILD_DIR/NixonCpp" "$PACKAGE_DIR/bin/"
        chmod +x "$PACKAGE_DIR/bin/NixonCpp"
        
        # Fix dynamic linker path for non-Nix systems
        if command -v patchelf &> /dev/null && [ "$ARCH" != "native" ]; then
            echo "   🔧 Patching interpreter path..."
            patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 "$PACKAGE_DIR/bin/NixonCpp" 2>/dev/null || \
            patchelf --set-interpreter /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 "$PACKAGE_DIR/bin/NixonCpp" 2>/dev/null || \
            echo "   ⚠️  Could not patch interpreter (may need manual fix on target system)"
        elif [ "$ARCH" != "native" ]; then
            echo "   ⚠️  patchelf not found; interpreter may still point to /nix/store"
        fi
        
        echo "   ✓ Executable: NixonCpp"
        
        # Copy shared library
        if [ -f "$BUILD_DIR/libNixonCppLib.so" ]; then
            cp "$BUILD_DIR/libNixonCppLib.so" "$PACKAGE_DIR/lib/"
            
            # Fix RPATH to use standard system paths
            if command -v patchelf &> /dev/null; then
                patchelf --set-rpath '$ORIGIN/../lib:/usr/local/lib:/usr/lib:/lib' "$PACKAGE_DIR/bin/NixonCpp" 2>/dev/null || true
                patchelf --set-rpath '$ORIGIN:/usr/local/lib:/usr/lib:/lib' "$PACKAGE_DIR/lib/libNixonCppLib.so" 2>/dev/null || true
            fi
            
            echo "   ✓ Library: libNixonCppLib.so"
        fi
        
        # Copy static library (optional)
        if [ -f "$BUILD_DIR/libNixonCppLib.a" ]; then
            cp "$BUILD_DIR/libNixonCppLib.a" "$PACKAGE_DIR/lib/"
            echo "   ✓ Static library: libNixonCppLib.a"
        fi
        ;;
esac

# Copy headers (optional, for development)
if [ "$ARCH" != "wasm" ] && [ "$ARCH" != "emscripten" ]; then
    cp -r Lib/include/NixonCppLib/* "$PACKAGE_DIR/include/NixonCppLib/"
    echo "   ✓ Headers: NixonCppLib/*.hpp"
fi

# Copy assets (except for WebAssembly which has them embedded)
if [ "$ARCH" != "wasm" ] && [ "$ARCH" != "emscripten" ]; then
    cp -r assets "$PACKAGE_DIR/share/NixonCpp/"
    echo "   ✓ Assets: customstrings.json, etc."
fi

# Create installation script for Unix-like systems
if [ "$ARCH" != "wasm" ] && [ "$ARCH" != "emscripten" ]; then
    cat > "$PACKAGE_DIR/install.sh" << 'EOF'
#!/usr/bin/env bash
# Installation Script

set -e

INSTALL_PREFIX="${1:-/usr/local}"

echo "🚀 Installing NixonCpp to $INSTALL_PREFIX..."
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
mkdir -p "$INSTALL_PREFIX"/{bin,lib,share/NixonCpp,include}

# Install files
echo "📋 Installing files..."
cp -v bin/NixonCpp "$INSTALL_PREFIX/bin/"
[ -f lib/libNixonCppLib.so ] && cp -v lib/libNixonCppLib.so "$INSTALL_PREFIX/lib/"
[ -f lib/libNixonCppLib.a ] && cp -v lib/libNixonCppLib.a "$INSTALL_PREFIX/lib/"
[ -d include/NixonCppLib ] && cp -rv include/NixonCppLib "$INSTALL_PREFIX/include/"
[ -d share/NixonCpp ] && cp -rv share/NixonCpp "$INSTALL_PREFIX/share/"

# Fix interpreter/RPATH if needed (e.g., when built in Nix)
if command -v patchelf &> /dev/null; then
    if [ -f "$INSTALL_PREFIX/bin/NixonCpp" ]; then
        patchelf --set-interpreter /lib/ld-linux-aarch64.so.1 "$INSTALL_PREFIX/bin/NixonCpp" 2>/dev/null || \
        patchelf --set-interpreter /lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 "$INSTALL_PREFIX/bin/NixonCpp" 2>/dev/null || true
        patchelf --set-rpath '$ORIGIN/../lib:/usr/local/lib:/usr/lib:/lib' "$INSTALL_PREFIX/bin/NixonCpp" 2>/dev/null || true
    fi
    if [ -f "$INSTALL_PREFIX/lib/libNixonCppLib.so" ]; then
        patchelf --set-rpath '$ORIGIN:/usr/local/lib:/usr/lib:/lib' "$INSTALL_PREFIX/lib/libNixonCppLib.so" 2>/dev/null || true
    fi
else
    if command -v readelf &> /dev/null && [ -f "$INSTALL_PREFIX/bin/NixonCpp" ]; then
        if readelf -l "$INSTALL_PREFIX/bin/NixonCpp" | grep -q "/nix/store/"; then
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
echo "   $INSTALL_PREFIX/bin/NixonCpp"
EOF

    chmod +x "$PACKAGE_DIR/install.sh"

    # Create uninstall script
    cat > "$PACKAGE_DIR/uninstall.sh" << 'EOF'
#!/usr/bin/env bash
# Uninstallation Script

set -e

INSTALL_PREFIX="${1:-/usr/local}"

echo "🗑️  Uninstalling NixonCpp from $INSTALL_PREFIX..."
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
rm -vf "$INSTALL_PREFIX/bin/NixonCpp"
rm -vf "$INSTALL_PREFIX/lib/libNixonCppLib.so"
rm -vf "$INSTALL_PREFIX/lib/libNixonCppLib.a"
rm -rvf "$INSTALL_PREFIX/include/NixonCppLib"
rm -rvf "$INSTALL_PREFIX/share/NixonCpp"

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
fi

# Create README
cat > "$PACKAGE_DIR/README.txt" << EOF
NixonCpp $ARCH_DISPLAY Package
$(printf '=%.0s' {1..60})

EOF

case "$ARCH" in
    wasm|emscripten)
        cat >> "$PACKAGE_DIR/README.txt" << 'EOF'
Running WebAssembly:
--------------------

With Node.js:
    node NixonCpp.js

In a web browser:
    <script src="NixonCpp.js"></script>

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
2. Run NixonCpp.exe

Dependencies:
-------------
All required DLL files should be included in the bin/ directory.
If any are missing, they can be obtained from the MinGW toolchain.

Running:
--------
    bin\NixonCpp.exe

Or add bin\ to your PATH to run from anywhere:
    NixonCpp
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
    - Copy bin/NixonCpp to /usr/local/bin/
    - Copy lib/libNixonCppLib.so to /usr/local/lib/
    - Copy share/NixonCpp to /usr/local/share/
   - Run: sudo ldconfig

File Structure:
---------------
bin/NixonCpp          - Main executable
lib/libNixonCppLib.so            - Application shared library
lib/libNixonCppLib.a             - Static library (optional)
include/NixonCppLib/             - Header files (optional)
share/NixonCpp/assets/- Application assets

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
    ldd bin/NixonCpp

If libraries are missing (shown as "not found"), install them using your
package manager as described in the Dependencies section above.

Running:
--------
After installation:
    NixonCpp

Or directly from this directory:
    LD_LIBRARY_PATH=./lib ./bin/NixonCpp

Uninstallation:
---------------
  sudo ./uninstall.sh
EOF
        ;;
esac

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
        echo "   node $PACKAGE_DIR/NixonCpp.js"
        ;;
    windows|win64)
        echo "To deploy on Windows:"
        echo "   1. Extract: tar -xzf build/$PACKAGE_NAME.tar.gz"
        echo "   2. Copy $PACKAGE_BASENAME to Windows machine"
        echo "   3. Run: $PACKAGE_BASENAME\\bin\\NixonCpp.exe"
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
