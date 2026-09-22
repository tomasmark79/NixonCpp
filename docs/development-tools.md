# Development tools

Run these commands from the repository root inside the native development shell:

```bash
nix develop ./nix
```

## Tests and code checks

| Command | Purpose |
| --- | --- |
| `make test` | Build the native debug configuration and run unit tests |
| `make test-verbose` | Run tests from the existing debug build with verbose output |
| `make format-check` | Check C/C++ formatting without editing files |
| `make format` | Apply clang-format to C/C++ sources |
| `make check` | Build the native debug configuration and run clang-tidy |
| `make test-sanitizers` | Build and run native tests with AddressSanitizer and UBSan |

Tests live in [tests/](../tests/), with their source list in [tests/meson.build](../tests/meson.build). Formatting settings are in [.clang-format](../.clang-format); the clang-tidy invocation is defined in [scripts/solution-controller.sh](../scripts/solution-controller.sh). Review the diff after applying formatting.

The sanitizer target uses a separate build directory, `build/builddir-sanitize-address-undefined`, so it does not replace the regular debug build.

## VS Code

[.vscode/tasks.json](../.vscode/tasks.json) defines **Project Build Tasks**, which prompts for an operation, architecture, and build type. It also provides direct build and application launch tasks, plus a **Launch Emscripten Server** task.

The **Debug Application (Meson)** configuration in [.vscode/launch.json](../.vscode/launch.json) starts GDB after the native debug build. It uses the `cppdbg` adapter, so the Microsoft C/C++ extension and GDB must be available to the editor.

Build scripts update the root `compile_commands.json` link to the most recent build. If code navigation shows flags for the wrong target, rebuild the target you are working on.

## Devcontainer and Codespaces

The configuration in [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) supplies an Ubuntu environment with Nix and forwards port `6931` for the WASM server. Its setup script prepares flakes and prefetches the native shell. Use the same commands from the [Quick start](../README.md#quick-start) in the container terminal.

## Build options and API documentation

[meson_options.txt](../meson_options.txt) defines `build_tests` and `wasm_opt_level`. For example, after configuring a WASM debug build, explicitly disable optimization with:

```bash
nix develop ./nix#wasm
meson configure build/builddir-wasm-debug -Dwasm_opt_level=O0
make build-wasm-debug
```

Leave the WASM shell with `exit` when finished. To regenerate the API reference, run `make doxygen` in the native Nix shell. The generated entry point is `docs/html/index.html`. The API reference describes the C++ interfaces; the guides in this directory describe how to build, debug, and adapt the project.
