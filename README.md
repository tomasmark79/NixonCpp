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

## C++20 applications and libraries

A project template built with **Meson** and reproducible **Nix** environments.

Native tests, static analysis, sanitizers, and packaging — with cross-compilation for **Linux ARM64**, **Windows**, and **WebAssembly**.

## Application and documentation

- [Run NixonCpp in your browser](https://tomasmark79.github.io/NixonCpp/) — WebAssembly debug build; C++ sources are available in DevTools under `debug-src/src`.
- [Browse the API documentation](https://tomasmark79.github.io/NixonCpp/html/index.html) — Doxygen reference for the C++ application and library.

The [Documentation workflow](.github/workflows/docs.yml) publishes both from `main`, including the debug source map and project sources. GitHub Pages uses **GitHub Actions** as its deployment source; generated files are not stored in the branch.

## Features

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

To create a project from the template:

```bash
./scripts/rename.sh MyApp MyAppLib myapp
```

For repeated use, source [scripts/clonenixoncpp.sh](scripts/clonenixoncpp.sh) and run:

```bash
clonenixoncpp MyProject MyApp MyAppLib myapp
```

## Common commands

| Command | Purpose |
| --- | --- |
| `make build` | Native release build |
| `make debug` | Native debug build |
| `make test` | Build and run native tests |
| `make format` | Format C and C++ sources |
| `make format-check` | Verify formatting without modifying files |
| `make check` | Run clang-tidy |
| `make test-sanitizers` | Run tests with ASan and UBSan |
| `make cross-all` | Build all cross-compilation targets |
| `make package-all` | Create native and cross-platform packages |
| `make nix-build` | Build the Nix package |
| `make doxygen` | Generate documentation locally |

Run `make help` for the complete target list.

## Development environment

- VS Code tasks: [.vscode/tasks.json](.vscode/tasks.json)
- Devcontainer: [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json)
- Meson options: [meson_options.txt](meson_options.txt)

Nix is recommended. Native builds may also use a local C++20 compiler, Meson, Ninja, and the required libraries; cross-builds require Nix.

## Support

If NixonCpp helps with your projects, you can support its development:

[![PayPal](https://img.shields.io/badge/PayPal-Donate-blue?logo=paypal)](https://paypal.me/TomasMark)

## License

[MIT](LICENSE)
