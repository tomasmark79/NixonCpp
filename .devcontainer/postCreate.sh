#!/usr/bin/env bash
set -euo pipefail

# Ensure flakes are enabled (Codespaces containers tend to have a minimal nix.conf).
SUDO=""
if command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

if command -v nix >/dev/null 2>&1; then
  $SUDO mkdir -p /etc/nix
  if [[ ! -f /etc/nix/nix.conf ]] || ! grep -q "experimental-features" /etc/nix/nix.conf; then
    echo "experimental-features = nix-command flakes" | $SUDO tee -a /etc/nix/nix.conf >/dev/null
  fi

  echo "Prefetching Nix dev shell dependencies (first run can take a while)..."
  nix develop ./nix --command bash -lc "meson --version && ninja --version && clangd --version" || true
else
  echo "WARNING: nix is not available in this container. Native build may still work if you install Meson/Ninja/toolchain manually."
fi
