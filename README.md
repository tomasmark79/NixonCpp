NixonCpp
========
[![CI](https://github.com/tomasmark79/NixonCpp/actions/workflows/ci.yml/badge.svg)](https://github.com/tomasmark79/NixonCpp/actions/workflows/ci.yml)

<p align="center">
	<img src="assets/NixonCppLogo.svg" alt="NixonCpp Logo" width="40%">
</p>

<p align="center">
	<video src="docs/HelloNewcomer.webm" controls muted playsinline width="80%">
		Your browser does not support the video tag.
	</video>
</p>

Overview
--------
Project template for a C++ application and library, set up with Meson/Nix tooling, tests, documentation, and packaging. (modular layout, CI-ready, cross-build targets).

Repository layout
-----------------
- include/                Public library headers
- src/app/                Application sources
- src/lib/                Library implementation
- tests/                  Unit tests
- assets/                 Runtime assets
- scripts/                Build and tooling scripts

Requirements
------------
- Nix (recommended) or a C++20 toolchain + Meson + Ninja
- Optional: doxygen + graphviz for docs

Clone helper (bash)
-------------------
```bash
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
```
Usage:
- clonenixoncpp
- clonenixoncpp MyProject
- clonenixoncpp MyProject NewName NewLibName NewNamespace

Quick start (Nix)
-----------------
direnv allow
make build

Template rename
---------------
```bash
- Usage: scripts/rename.sh <NewName> [NewLibName] [NewNamespace]  
Example: rename.sh MyApp MyAppLib myapp
```

Build and test
--------------
- make build              Native release build
- make debug              Native debug build
- make test               Run tests
- make format             clang-format
- make check              clang-tidy

Cross builds
------------
- make cross-aarch64
- make cross-windows
- make cross-wasm

Packaging
---------
- make package-native
- make package-aarch64
- make package-windows
- make package-wasm

[Documentation C++](https://tomasmark79.github.io/NixonCpp/html/index.html)
-------------
make doxygen
Output: docs/html/index.html

VS Code tasks
-------------
Key workflow entry point for day-to-day work:
- F7: fast build (native debug)
- Shift+F7: task picker

Configure Meson options
-----------------------
meson configure build/builddir-debug -Dbuild_tests=enabled

License
-------
MIT
