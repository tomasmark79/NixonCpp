# Build targets and packaging

Run commands from the repository root. These examples use the original `NixonCpp` name; after renaming the template, substitute your application name in output paths. See the [Quick start](../README.md#quick-start) for the initial setup.

Enter the native development shell first so packaging and utility commands have their required tools and environment:

```bash
nix develop ./nix
```

## Choose a target

The Nix environments support Linux hosts. Cross-build commands select the appropriate Nix shell automatically.

| Target | Release build | Main output |
| --- | --- | --- |
| Native Linux | `make build` | `build/builddir-release/NixonCpp` |
| Linux ARM64 | `make cross-aarch64` | `build/builddir-aarch64-release/NixonCpp` |
| Windows | `make cross-windows` | `build/builddir-windows-release/NixonCpp.exe` |
| WebAssembly | `make cross-wasm` | `build/builddir-wasm-release/NixonCpp.html` |

Run cross-compiled applications on their target platform. For WebAssembly, serve the HTML and its companion files over HTTP; see [Debugging](debugging.md). The project's unit tests run on native builds.

## Choose a build type

Use `make build-<arch>-<type>`, where `<arch>` is `native`, `aarch64`, `windows`, or `wasm`:

| Type | Intended use |
| --- | --- |
| `debug` | Development and source-level debugging |
| `release` | Optimized builds |
| `debugoptimized` | Optimized builds with debug information; stepping may be less direct |
| `minsize` | Builds optimized for size |

For example:

```bash
make build-wasm-debug
make build-windows-release
```

Cross-build directories follow `build/builddir-<arch>-<type>`. Native builds with the default GCC compiler use `build/builddir-<type>`.

## Package for another machine or a web server

Use the matching package target, which builds the application first:

```bash
make package-native-release
make package-wasm-debug
```

The WASM debug package is created in `build/package-wasm-debug/`. Deploy the entire directory: HTML, JavaScript, WASM, `.wasm.map`, and `debug-src/`. Serving only the HTML or WASM omits files needed by the application or debugger.

The GitHub Pages workflow renames the application's HTML file to `index.html` during staging. For your own hosting, you can use the original filename or rename just that HTML file; keep its companion filenames and relative paths intact.

For other package locations, use the path printed by the packaging command. Run `make help` for the complete target list. For repository publishing settings, see [Creating your own project](creating-your-own-project.md).
