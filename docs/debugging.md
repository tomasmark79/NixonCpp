# Debugging

Use a `debug` build for the clearest correspondence between source lines and execution. Run the following commands from the repository root; replace `NixonCpp` in paths if you renamed the project.

## Native application with GDB

```bash
nix develop ./nix
make debug
gdb ./build/builddir-debug/NixonCpp
```

At the GDB prompt:

```text
break main
run
next
```

The application is a short console example, so set a breakpoint before running it. The repository also includes a VS Code launch configuration; see [Development tools](development-tools.md).

## WebAssembly in the browser

Build the debug application and start the included HTTP server in a terminal with Python 3 available:

```bash
make build-wasm-debug
python3 scripts/emscripten_server.py
```

Open `http://localhost:6931/build/builddir-wasm-debug/NixonCpp.html`. If the project's server is already running on that port, use it instead of starting another instance.

In browser DevTools, open **Sources**, find `debug-src/src/app/Application.cpp`, and set a breakpoint in `main()`. Reload the page to catch startup execution. The application may already have finished by the time you first open DevTools.

The debug build produces `NixonCpp.wasm.map` and stages project sources under `debug-src/`. This setup uses source maps for source locations and breakpoints; it does not provide the full variable inspection of a DWARF debugger.

Source-map entries may also refer to external library headers in the Nix store. Those files are not included in `debug-src/`; an HTTP 404 for a dependency header does not mean the project's C++ sources are unavailable. Use the project files under `debug-src/src` and `debug-src/include`.

## Rebuild after changes

The root `README.md` and assets are embedded at link time. After editing them, rebuild the application. For a hosted package, rebuild and upload the complete package as described in [Build targets and packaging](build-targets.md).

If a browser still shows old content after deployment, reload with its cache disabled. Also verify that you opened the debug build's URL and deployed the matching HTML, JavaScript, WASM, map, and sources together.
