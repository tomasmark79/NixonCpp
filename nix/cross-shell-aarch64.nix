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
    pkg-config
  ];

  buildInputs = [
    # Cross compiler/toolchain
    pkgsCross.stdenv.cc
  ]
  ++ targetDeps;

  shellHook = ''
    app_name=$(grep -m1 -E "project\(['\"][^'\"]+['\"]" "$PWD/meson.build" 2>/dev/null | sed -E "s/.*project\(['\"]([^'\"]+)['\"].*/\1/")
    if [ -z "$app_name" ]; then app_name="Project"; fi

    echo "🔨 $app_name aarch64 Cross-Compilation Environment"
    echo "   Target: aarch64-unknown-linux-gnu"
    echo "   Meson version: $(${pkgs.pkgsBuildHost.meson}/bin/meson --version)"
    echo ""
    echo "Build command:"
    echo "  make cross-aarch64"
    echo ""
    echo "Run on host via QEMU:"
    echo "  nix develop ./nix#aarch64 --command bash -c 'qemu-aarch64 -L \"$QEMU_LD_PREFIX\" ./build/builddir-aarch64-minsize/$app_name'"
    echo ""
  '';
}
