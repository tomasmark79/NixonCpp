# NixonCpp

[![Quality](https://github.com/tomasmark79/NixonCpp/actions/workflows/quality.yml/badge.svg?branch=main)](https://github.com/tomasmark79/NixonCpp/actions/workflows/quality.yml)
[![Native](https://github.com/tomasmark79/NixonCpp/actions/workflows/native.yml/badge.svg?branch=main)](https://github.com/tomasmark79/NixonCpp/actions/workflows/native.yml)
[![Static analysis](https://github.com/tomasmark79/NixonCpp/actions/workflows/static-analysis.yml/badge.svg?branch=main)](https://github.com/tomasmark79/NixonCpp/actions/workflows/static-analysis.yml)
[![Sanitizers](https://github.com/tomasmark79/NixonCpp/actions/workflows/sanitizers.yml/badge.svg?branch=main)](https://github.com/tomasmark79/NixonCpp/actions/workflows/sanitizers.yml)
[![Cross builds](https://github.com/tomasmark79/NixonCpp/actions/workflows/cross-builds.yml/badge.svg?branch=main)](https://github.com/tomasmark79/NixonCpp/actions/workflows/cross-builds.yml)
[![Documentation](https://github.com/tomasmark79/NixonCpp/actions/workflows/docs.yml/badge.svg?branch=main)](https://github.com/tomasmark79/NixonCpp/actions/workflows/docs.yml)

<p align="center">
  <img src="assets/NixonCppLogo.svg" alt="NixonCpp logo" width="40%">
</p>

## Create your C++ applications and libraries

A project template built with **Meson** and reproducible **Nix** environments.

Native tests, static analysis, sanitizers, and packaging — with cross-compilation for **Linux ARM64**, **Windows**, and **WebAssembly**.

## Application and documentation

- [Run NixonCpp in your browser](https://tomasmark79.github.io/NixonCpp/) — WebAssembly debug build; C++ sources are available in DevTools under `debug-src/src`.
- [Browse the API documentation](https://tomasmark79.github.io/NixonCpp/html/index.html) — Doxygen reference for the C++ application and library.

## Features

- C++20 by default
- Application, shared library, and static library targets
- Nix development environments and reproducible package builds
- GoogleTest, clang-format, clang-tidy, AddressSanitizer, and UBSan
- Cross-builds for aarch64-linux, Windows, and WebAssembly
- Doxygen documentation published through GitHub Pages
- Project renaming, packaging, VS Code, devcontainer, and Codespaces support

## Quick start

```bash
git clone https://github.com/tomasmark79/NixonCpp.git
cd NixonCpp
nix develop ./nix
make test
```

## Development environment

- VS Code tasks: [.vscode/tasks.json](.vscode/tasks.json)
- Devcontainer: [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)
- Meson options: [meson_options.txt](meson_options.txt)

Nix is recommended. Native builds may also use a local C++20 compiler, Meson, Ninja, and the required libraries; cross-builds require Nix.

## Support

If NixonCpp helps with your projects, you can support its development:

[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?logo=paypal)](https://paypal.me/TomasMark)

## Authorship and AI assistance

This template was designed and developed through human effort. AI was used as an assistant during later stages of development; it was not used to randomly assemble the project. The architecture, implementation decisions, and responsibility for the result remain with the author.

## License

[MIT](LICENSE)
