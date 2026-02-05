# Nix cross-compilation shell for Windows (MinGW)
# Usage: nix develop ./nix#windows

{ pkgs ? import <nixpkgs> {} }:

let
  mingwPkgs = pkgs.pkgsCross.mingwW64;
in

pkgs.mkShell {
  name = "nixoncpp-windows-cross";
  
  buildInputs = with pkgs; [
    # Build tools (native)
    meson
    ninja
    pkg-config
    
    # MinGW cross-compiler
    pkgs.pkgsCross.mingwW64.stdenv.cc
    
    # MinGW pkg-config
    pkgs.pkgsCross.mingwW64.buildPackages.pkg-config
    
    # Cross-compiled Windows dependencies
    mingwPkgs.windows.pthreads
    
    # Wine for testing
    wine64
  ] ++ (with mingwPkgs; [
    # These will be cross-compiled for Windows
    fmt
    nlohmann_json
    cxxopts
  ]);
  
  shellHook = ''
    echo "🔨 NixonCpp Windows (MinGW) Cross-Compilation Environment"
    echo ""
    echo "   Target: x86_64-w64-mingw32"
    echo "   Compiler: x86_64-w64-mingw32-g++"
    echo ""
    echo "Available cross-compiled libraries:"
    echo "   fmt (Windows)"
    echo "   nlohmann_json (Windows)"
    echo ""
    echo "Build command:"
    echo "   make cross-windows"
    echo ""
    echo "Test Windows binary:"
    echo "   wine64 ./build/builddir-windows-release/NixonCpp.exe"
    echo ""
  '';
}
