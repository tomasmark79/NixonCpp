#!/usr/bin/env bash
# bundle-deps.sh
#
# Copies all third-party runtime libraries from the Nix store into the
# platform-specific package directory. Must be run inside the appropriate
# Nix shell so BUNDLE_LIB_DIRS is set.
#
# Usage: bundle-deps.sh [arch] [build_type]
#   arch:       native|x86_64, aarch64|arm64, windows|win64
#   build_type: debug|release  (default: release)
#
# BUNDLE_LIB_DIRS is exported by the nix shell hook and contains
# colon-separated lib/ (Linux) or bin/ (Windows) directories of every
# declared runtime dependency — no readelf guessing needed.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ARCH="${1:-native}"
BUILD_TYPE="${2:-release}"

case "$ARCH" in
    native|x86_64)
        PACKAGE_DIR="$PROJECT_ROOT/build/package-x86_64-${BUILD_TYPE}"
        PLATFORM=linux
        TARBALL_ARCH="x86_64"
        ;;
    aarch64|arm64)
        PACKAGE_DIR="$PROJECT_ROOT/build/package-aarch64-${BUILD_TYPE}"
        PLATFORM=linux
        TARBALL_ARCH="aarch64"
        ;;
    windows|win64)
        PACKAGE_DIR="$PROJECT_ROOT/build/package-windows-${BUILD_TYPE}"
        PLATFORM=windows
        TARBALL_ARCH="windows"
        ;;
    *)
        echo "❌  Unknown arch: $ARCH"
        echo "    Usage: $0 [native|aarch64|windows] [debug|release]"
        exit 1
        ;;
esac

# Linux .so files go into lib/, Windows .dll files go into bin/
if [ "$PLATFORM" = "linux" ]; then
    OUT_DIR="$PACKAGE_DIR/lib"
else
    OUT_DIR="$PACKAGE_DIR/bin"
fi

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

if [ -z "$BUNDLE_LIB_DIRS" ]; then
    echo "⚠️   BUNDLE_LIB_DIRS is not set — nothing to bundle."
    echo "    Run this script inside the appropriate Nix shell."
    exit 0
fi

if [ ! -d "$PACKAGE_DIR" ]; then
    echo "❌  Package directory not found: $PACKAGE_DIR"
    echo "    Run the package step first."
    exit 1
fi

mkdir -p "$OUT_DIR"

# Libraries present on every standard Linux target — no need to bundle.
is_system_lib() {
    local lib="$1"
    local skip=("libc.so" "libm.so" "libpthread.so" "libstdc++.so" "libgcc_s.so"
                 "libdl.so" "librt.so" "libresolv.so" "ld-linux" "libutil.so"
                 "libnss" "libcrypt.so")
    for pat in "${skip[@]}"; do
        [[ "$lib" == ${pat}* ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Copy libraries from each BUNDLE_LIB_DIRS entry
# ---------------------------------------------------------------------------

echo "📦  Bundling $ARCH third-party runtime libraries"
echo "    Platform : $PLATFORM"
echo "    Package  : $PACKAGE_DIR"
echo "    Output   : $OUT_DIR"
echo ""

IFS=: read -ra dirs <<< "$BUNDLE_LIB_DIRS"
for dir in "${dirs[@]}"; do
    [ -d "$dir" ] || continue

    if [ "$PLATFORM" = "linux" ]; then
        # ── Linux: copy versioned .so files ─────────────────────────────────
        while IFS= read -r so; do
            name="$(basename "$so")"
            is_system_lib "$name" && continue
            { [ -f "$OUT_DIR/$name" ] || [ -L "$OUT_DIR/$name" ]; } && continue

            # Copy dereferencing symlinks so we get the real file.
            cp -Lf "$so" "$OUT_DIR/$name"

            # Patch RPATH so inter-lib references resolve inside lib/.
            if command -v patchelf &>/dev/null; then
                patchelf --set-rpath '$ORIGIN:/usr/local/lib:/usr/lib:/lib' \
                    "$OUT_DIR/$name" 2>/dev/null || true
            fi

            echo "   ✓  $name"

            # Recreate shorter symlinks (e.g. libfoo.so → libfoo.so.1.2.3).
            base="${name%.so*}"
            while IFS= read -r related; do
                rel_name="$(basename "$related")"
                [ "$rel_name" = "$name" ] && continue
                [ -L "$related" ] || continue
                if [ ! -f "$OUT_DIR/$rel_name" ] && [ ! -L "$OUT_DIR/$rel_name" ]; then
                    ln -sf "$name" "$OUT_DIR/$rel_name"
                    echo "   ↳  $rel_name → $name"
                fi
            done < <(find "$dir" -maxdepth 1 -name "${base}.so*" 2>/dev/null)
        done < <(find "$dir" -maxdepth 1 -name "*.so.*" -not -type d 2>/dev/null)

    else
        # ── Windows: copy .dll files into bin/ ──────────────────────────────
        while IFS= read -r dll; do
            name="$(basename "$dll")"
            { [ -f "$OUT_DIR/$name" ] || [ -L "$OUT_DIR/$name" ]; } && continue
            cp -Lf "$dll" "$OUT_DIR/$name"
            echo "   ✓  $name"
        done < <(find "$dir" -maxdepth 2 -name "*.dll" -not -type d 2>/dev/null)
    fi
done

echo ""
echo "✅  Done. Contents of $OUT_DIR:"
ls -1 "$OUT_DIR" 2>/dev/null || echo "   (empty – all dependencies statically linked)"

# ---------------------------------------------------------------------------
# Recreate tarball so it includes the newly bundled libraries.
# ---------------------------------------------------------------------------
APP_NAME=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" \
    2>/dev/null | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
if [ -z "$APP_NAME" ]; then APP_NAME="NixonCpp"; fi

TARBALL="$PROJECT_ROOT/build/${APP_NAME}-${TARBALL_ARCH}-${BUILD_TYPE}.tar.gz"
PACKAGE_BASENAME="$(basename "$PACKAGE_DIR")"

echo ""
echo "📦  Recreating tarball: build/${APP_NAME}-${TARBALL_ARCH}-${BUILD_TYPE}.tar.gz"
tar -czf "$TARBALL" -C "$PROJECT_ROOT/build" "$PACKAGE_BASENAME"
echo "✅  Tarball ready: $TARBALL"
