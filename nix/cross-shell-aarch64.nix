# Nix cross-compilation shell for aarch64
# Usage: nix develop ./nix#aarch64

{
  pkgs ? import <nixpkgs> { },
  pkgsCross ? pkgs.pkgsCross.aarch64-multiplatform,
}:

let
  targetDeps = with pkgsCross; [
    fmt
    nlohmann_json
    cxxopts
    gtest

    # sdl3
    # sdl3-image
    # sdl3-ttf
    # imgui
  ];
in

pkgs.mkShell {
  name = "project-aarch64-cross";
  nativeBuildInputs = with pkgs.pkgsBuildHost; [
    meson
    ninja
    # The cross compiler wrapper also puts aarch64-unknown-linux-gnu-pkg-config
    # on PATH, which is what linux-to-aarch64.ini references.
    pkgsCross.stdenv.cc
  ];

  buildInputs = [
    # Cross compiler/toolchain
    pkgsCross.stdenv.cc
  ]
  ++ targetDeps;

  shellHook = ''
    app_name=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PWD/meson.build" 2>/dev/null | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
    if [ -z "$app_name" ]; then app_name="Project"; fi

    # Nix sets PKG_CONFIG=aarch64-unknown-linux-gnu-pkg-config but that binary is not
    # on PATH, causing meson to report "Found pkg-config: NO" for all host deps.
    # Unset it so meson falls back to the cross file's 'pkg-config = pkg-config' entry,
    # which IS on PATH. Our PKG_CONFIG_PATH below then points it to the aarch64 packages.
    unset PKG_CONFIG

    # The nix pkg-config wrapper uses PKG_CONFIG_PATH_FOR_TARGET (not PKG_CONFIG_PATH)
    # and defaults to host paths. Override it to point only to aarch64 cross packages.
    export PKG_CONFIG_FOR_TARGET="${pkgsCross.pkg-config}/bin/pkg-config"
    export PKG_CONFIG_PATH_FOR_TARGET=""
    for pkg in ${pkgsCross.fmt.dev} ${pkgsCross.nlohmann_json} ${pkgsCross.cxxopts} \
                ${pkgsCross.gtest.dev}; do
      for dir in "$pkg/lib/pkgconfig" "$pkg/share/pkgconfig"; do
        [ -d "$dir" ] && PKG_CONFIG_PATH_FOR_TARGET="$PKG_CONFIG_PATH_FOR_TARGET:$dir"
      done
    done
    export PKG_CONFIG_PATH_FOR_TARGET="''${PKG_CONFIG_PATH_FOR_TARGET#:}"
    # Also set PKG_CONFIG_PATH so the plain 'pkg-config' binary (used by meson)
    # resolves cross packages correctly.
    export PKG_CONFIG_PATH="$PKG_CONFIG_PATH_FOR_TARGET"

    echo "🔨 $app_name aarch64 Cross-Compilation Environment"
    echo "   Target: aarch64-unknown-linux-gnu"
    echo "   Meson version: $(${pkgs.pkgsBuildHost.meson}/bin/meson --version)"
    echo ""
    echo "Build command:"
    echo "  make cross-aarch64"
    echo ""
    echo "Run on host via QEMU:"
    echo "  nix develop ./nix#aarch64 --command bash -c 'qemu-aarch64 -L \"\$QEMU_LD_PREFIX\" ./build/builddir-aarch64-minsize/$app_name'"
    echo ""
  '';
}
