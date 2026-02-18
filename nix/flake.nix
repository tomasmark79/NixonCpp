{
  description = "Project development shells (flake wrapper)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Pinned nixpkgs for the WASM shell – Emscripten 3.1.73 ships with an
    # LLVM whose llvm-dwarfdump still supports the -t flag required by
    # Emscripten's source-map generator.  Newer LLVM (≥21) removed -t,
    # which breaks -gsource-map at link time.
    nixpkgs-wasm.url = "github:NixOS/nixpkgs/1cb1c02a6b1b7cf67e3d7731cbbf327a53da9679";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-wasm,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        pkgsWasm = import nixpkgs-wasm { inherit system; };
        pkgsAarch64 = pkgs.pkgsCross.aarch64-multiplatform;

        nixonCpp = pkgs.stdenv.mkDerivation {
          pname = "NixonCpp";
          version = "1.0.0";

          src = pkgs.lib.cleanSource ../.;

          nativeBuildInputs = with pkgs; [
            meson
            ninja
            pkg-config
          ];

          buildInputs = with pkgs; [
            fmt
            nlohmann_json
            cxxopts
          ];

          mesonFlags = [
            "-Dbuild_tests=disabled"
          ];

          meta = with pkgs.lib; {
            description = "NixonCpp – C++ project template";
            license = licenses.mit;
            maintainers = [ maintainers.tomasmark79 ];
            platforms = platforms.linux;
          };
        };
      in
      {
        # ── Nix package ──────────────────────────────────────────────────────
        packages.NixonCpp = nixonCpp;
        packages.default = nixonCpp;

        # ── Dev shells ───────────────────────────────────────────────────────
        devShells.default = pkgs.mkShell {
          name = "project-dev";

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
            ccache
          ];

          shellHook = ''
            echo "🚀 Project Development Environment"
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
        devShells.wasm = import ./cross-shell-wasm.nix { pkgs = pkgsWasm; };
      }
    );
}
