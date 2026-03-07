#!/usr/bin/env bash
# bundle-aarch64-deps.sh
#
# Copies all third-party runtime .so files from the Nix store into the aarch64
# package lib/ directory. Must be run inside the aarch64 Nix cross shell:
#
#   nix develop ./nix#aarch64 --command bash scripts/bundle-aarch64-deps.sh
#
# AARCH64_LIB_DIRS is exported by the nix shell hook and contains the lib/
# directories of every declared targetDep — no readelf guessing needed.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

BUILD_TYPE="${1:-release}"
PACKAGE_DIR="$PROJECT_ROOT/build/package-aarch64-${BUILD_TYPE}"
LIB_OUT="$PACKAGE_DIR/lib"

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

if [ -z "$AARCH64_LIB_DIRS" ]; then
    echo "❌  AARCH64_LIB_DIRS is not set."
    echo "    Run this script inside the aarch64 Nix shell:"
    echo "      nix develop ./nix#aarch64 --command bash scripts/bundle-aarch64-deps.sh"
    exit 1
fi

if [ ! -d "$PACKAGE_DIR" ]; then
    echo "❌  Package directory not found: $PACKAGE_DIR"
    echo "    Run 'make cross-aarch64' and 'make package-aarch64' first."
    exit 1
fi

mkdir -p "$LIB_OUT"

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
# Copy every .so.* from each targetDep lib dir
# ---------------------------------------------------------------------------

echo "📦  Bundling aarch64 third-party runtime libraries"
echo "    Package: $PACKAGE_DIR"
echo ""

IFS=: read -ra dirs <<< "$AARCH64_LIB_DIRS"
for dir in "${dirs[@]}"; do
    [ -d "$dir" ] || continue

    while IFS= read -r so; do
        name="$(basename "$so")"
        is_system_lib "$name" && continue
        { [ -f "$LIB_OUT/$name" ] || [ -L "$LIB_OUT/$name" ]; } && continue

        # Copy dereferencing symlinks so we get the real file.
        cp -Lf "$so" "$LIB_OUT/$name"

        # Patch RPATH so inter-lib references resolve inside lib/.
        if command -v patchelf &>/dev/null; then
            patchelf --set-rpath '$ORIGIN:/usr/local/lib:/usr/lib:/lib' \
                "$LIB_OUT/$name" 2>/dev/null || true
        fi

        echo "   ✓  $name"

        # Recreate shorter symlinks (e.g. libdpp.so → libdpp.so.10.1.4).
        base="${name%.so*}"
        while IFS= read -r related; do
            rel_name="$(basename "$related")"
            [ "$rel_name" = "$name" ] && continue
            [ -L "$related" ] || continue
            if [ ! -f "$LIB_OUT/$rel_name" ] && [ ! -L "$LIB_OUT/$rel_name" ]; then
                ln -sf "$name" "$LIB_OUT/$rel_name"
                echo "   ↳  $rel_name → $name"
            fi
        done < <(find "$dir" -maxdepth 1 -name "${base}.so*" 2>/dev/null)
    done < <(find "$dir" -maxdepth 1 -name "*.so.*" -not -type d 2>/dev/null)
done

echo ""
echo "✅  Done. Libraries in $LIB_OUT:"
ls -1 "$LIB_OUT"

# ---------------------------------------------------------------------------
# Recreate tarball so it includes the newly bundled libraries.
# ---------------------------------------------------------------------------
APP_NAME=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PROJECT_ROOT/meson.build" 2>/dev/null \
    | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
if [ -z "$APP_NAME" ]; then APP_NAME="DotNameBot"; fi

TARBALL="$PROJECT_ROOT/build/${APP_NAME}-aarch64-${BUILD_TYPE}.tar.gz"
PACKAGE_BASENAME="$(basename "$PACKAGE_DIR")"

echo ""
echo "📦  Recreating tarball: build/${APP_NAME}-aarch64-${BUILD_TYPE}.tar.gz"
tar -czf "$TARBALL" -C "$PROJECT_ROOT/build" "$PACKAGE_BASENAME"
echo "✅  Tarball ready: $TARBALL"
