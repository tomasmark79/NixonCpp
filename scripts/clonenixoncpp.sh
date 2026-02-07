#!/usr/bin/env bash
# Clone helper for NixonCpp-based projects.
#
# Usage (recommended):
#   source ./scripts/clonenixoncpp.sh
#   clonenixoncpp [FolderName] [NewName] [NewLibName] [NewNamespace]
#
# Tip (make it available in every terminal):
#   Add this to ~/.bashrc (or ~/.zshrc):
#     source /absolute/path/to/NixonCpp/scripts/clonenixoncpp.sh
#
# Example:
#   clonenixoncpp MyProject MyApp MyAppLib myapp

# Note:
# This file is meant to be sourced (often from ~/.bashrc). Do not enable
# shell-wide strict modes here (e.g. `set -euo pipefail`), because that would
# affect the user's interactive shell and can cause surprising exits/errors.

clonenixoncpp() {
	local PN="${1:-NixonCppClone}"
	shift || true
	local REPO="git@github.com:tomasmark79/NixonCpp.git"

	command -v git >/dev/null || { echo "git not found"; return 1; }
	git clone --depth=1 "$REPO" "$PN" || return 1
	rm -rf "$PN/.git"
	cd "$PN" || return 1
	if [[ $# -gt 0 ]]; then
		./scripts/rename.sh "$@" || return 1
	elif [[ "$PN" != "NixonCppClone" ]]; then
		./scripts/rename.sh "$PN" || return 1
	else
		echo "Tip: use rename like this: clonenixoncpp <FolderName> [NewName] [NewLibName] [NewNamespace]"
	fi

	if command -v direnv >/dev/null; then
		direnv allow .
	fi

	if command -v code >/dev/null; then
		code .
	fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	echo "This file is meant to be sourced." >&2
	echo "Run: source ./scripts/clonenixoncpp.sh" >&2
	echo "Then: clonenixoncpp [FolderName] [NewName] [NewLibName] [NewNamespace]" >&2
	exit 2
fi
