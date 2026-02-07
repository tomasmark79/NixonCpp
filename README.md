NixonCpp
========
[![CI](https://github.com/tomasmark79/NixonCpp/actions/workflows/ci.yml/badge.svg)](https://github.com/tomasmark79/NixonCpp/actions/workflows/ci.yml)

<p align="center">
	<img src="assets/NixonCppLogo.svg" alt="NixonCpp Logo" width="40%">
</p>

Overview
--------
Project template for a C++ application and library, set up with Meson/Nix tooling, tests, documentation, and packaging.

Highlights:
- Modular layout (app + library)
- CI-ready
- Cross-build targets (aarch64, Windows, WASM)

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

Quick start (Nix)
-----------------
If you use `direnv`:
```bash
direnv allow
```

Build (native, release):
```bash
make build
```

Run tests (native, debug build first):
```bash
make test
```

Clone helper
------------
See: [scripts/clonenixoncpp.sh](scripts/clonenixoncpp.sh)


Template rename
---------------
```bash
# Usage: scripts/rename.sh <NewName> [NewLibName] [NewNamespace]
./scripts/rename.sh MyApp MyAppLib myapp
```

Build and test
--------------
```bash
make build        # Native release build
make debug        # Native debug build
make test         # Run tests
make format       # clang-format on sources
make check        # clang-tidy (native debug builddir)
```

Cross builds
------------
```bash
make cross-aarch64
make cross-windows
make cross-wasm
```

Packaging
---------
```bash
make package-native
make package-aarch64
make package-windows
make package-wasm
```

Documentation
-------------
- Online docs: https://tomasmark79.github.io/NixonCpp/html/index.html
- Generate locally:
```bash
make doxygen
```
Output: `docs/html/index.html`

VS Code tasks
-------------
Workspace tasks are defined in [.vscode/tasks.json](.vscode/tasks.json).

How to run:
- Use `Terminal: Run Task` (or `Tasks: Run Task`) and pick one of the tasks below.

Common tasks:
- `Direct Build (native debug)` (default build task)
- `Project Build Tasks` (interactive picker: Build/Configure/Test/Package + arch + buildtype)
- `clang-format`
- `clang-tidy`
- `Launch Application (native)` / `Launch Application (native release)`
- `Launch Emscripten Server` / `Launch Emscripten Server (release)`

Optional keybindings:
- A suggested keybinding setup is provided in [.vscode/keybindings.json](.vscode/keybindings.json).
- Copy it into your user keybindings file (Linux default: `~/.config/Code/User/keybindings.json`).

Configure Meson options
-----------------------
Example (debug builddir):
```bash
meson configure build/builddir-debug -Dbuild_tests=enabled
```

License
-------
MIT
