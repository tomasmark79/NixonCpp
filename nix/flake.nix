{
  description = "NixonCpp development shells (flake wrapper)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgsAarch64 = import nixpkgs {
          inherit system;
          crossSystem = { config = "aarch64-unknown-linux-gnu"; };
        };
      in {
        devShells.default = pkgs.mkShell {
          name = "nixoncpp-dev";

          buildInputs = with pkgs; [
            meson
            cmake
            ninja
            pkg-config

            gcc
            gdb
            clang-tools

            doxygen
            graphviz
            

            fmt
            nlohmann_json
            cxxopts

            gtest
            qemu
            ccache
          ];

          shellHook = ''
            echo "🚀 NixonCpp Development Environment"
            echo "   Meson version: $(meson --version)"
            echo "   GCC version: $(gcc --version | head -n1)"
            echo ""
            echo "Quick commands:"
            echo "   make build           - Build the project (release)"
            echo "   make debug           - Build in debug mode"
            echo "   make test            - Run tests"
            echo ""
            echo "Cross-compilation:"
            echo "   make cross-aarch64   - Build for ARM64"
            echo "   make cross-windows   - Build for Windows"
            echo "   make cross-wasm      - Build for WebAssembly"
            echo ""
            echo "Flake tips:"
            echo "   First run is slower (downloads + lock)."
            echo "   For faster iterations: nix develop --impure ./nix"
            echo "   Ensure binary caches are enabled in your Nix config."
            echo ""
          '';
        };
        devShells.aarch64 = import ./cross-shell-aarch64.nix { pkgs = pkgsAarch64; };
        devShells.windows = import ./cross-shell-windows.nix { inherit pkgs; };
        devShells.wasm = import ./cross-shell-wasm.nix { inherit pkgs; };
      });
}
