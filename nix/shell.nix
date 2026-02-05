# Legacy non-flake shell (deprecated)
# Use: nix develop ./nix

{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "nixoncpp-legacy-shell";

  buildInputs = [ ];

  shellHook = ''
    echo "⚠️  Deprecated: use 'nix develop ./nix' (flake) instead."
  '';
}
