# Nix cross-compilation shell for aarch64
# Usage: nix develop ./nix#aarch64

{ pkgs ? import <nixpkgs> {
    crossSystem = {
      config = "aarch64-unknown-linux-gnu";
    };
  }
}:

pkgs.mkShell {
  name = "nixoncpp-aarch64-cross";
  QEMU_LD_PREFIX = "${pkgs.glibc}";
  
  nativeBuildInputs = with pkgs.pkgsBuildHost; [
    meson
    ninja
    pkg-config
    qemu
  ];
  
  buildInputs = with pkgs; [
    # These will be aarch64 versions
    fmt
    nlohmann_json
    cxxopts
    gtest
  ];
  
  shellHook = ''
    echo "🔨 NixonCpp aarch64 Cross-Compilation Environment"
    echo "   Target: aarch64-unknown-linux-gnu"
    echo "   Meson version: $(${pkgs.pkgsBuildHost.meson}/bin/meson --version)"
    echo ""
    echo "Build command:"
    echo "  make cross-aarch64"
    echo ""
    echo "Run (x86_64 via QEMU):"
    echo "  qemu-aarch64 -L $QEMU_LD_PREFIX ./build/builddir-aarch64-release/NixonCpp"
    echo ""
  '';
}
