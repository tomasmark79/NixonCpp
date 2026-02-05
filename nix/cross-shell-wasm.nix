# Nix cross-compilation shell for WebAssembly (Emscripten)
# Usage: nix develop ./nix#wasm

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "nixoncpp-wasm-cross";
  
  buildInputs = with pkgs; [
    # Build tools
    meson
    ninja
    pkg-config
    
    # Emscripten SDK
    emscripten
    
    # Node.js for running WASM binaries
    nodejs
    
    # Dependencies
    # Note: We'll use system includes from Emscripten's ports system
    # or rely on header-only libraries
    fmt  # Will provide headers even if linking doesn't work
    nlohmann_json  # Header-only, works with Emscripten
    cxxopts  # Header-only
  ];
  
  shellHook = ''
    echo "🔨 NixonCpp WebAssembly (Emscripten) Cross-Compilation Environment"
    echo ""
    echo "   Target: wasm32"
    echo "   Emscripten version: $(emcc --version | head -1)"
    echo "   Node.js version: $(node --version)"
    echo ""
    
    # Add include paths for dependencies
    export CPLUS_INCLUDE_PATH="${pkgs.fmt.dev}/include:${pkgs.nlohmann_json}/include:${pkgs.cxxopts}/include:$CPLUS_INCLUDE_PATH"
    export C_INCLUDE_PATH="${pkgs.fmt.dev}/include:${pkgs.nlohmann_json}/include:${pkgs.cxxopts}/include:$C_INCLUDE_PATH"
    
    echo "Build command:"
    echo "   make cross-wasm"
    echo ""
    echo "Run WASM binary:"
    echo "   node ./build/builddir-wasm-release/NixonCpp.js"
    echo ""
  '';
}
