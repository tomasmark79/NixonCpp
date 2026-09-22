# Creating your own project

This guide takes you from a copy of NixonCpp to a project with your own name, repository, and metadata. For the initial build and a map of the source tree, see the [README](../README.md).

## Create your own repository

Create an empty repository in your own account, then clone the template into a new directory. Replace `YOUR_ACCOUNT` and `MyApp` with your account and repository name before setting the remote:

```bash
git clone https://github.com/tomasmark79/NixonCpp.git MyApp
cd MyApp
git remote set-url origin https://github.com/YOUR_ACCOUNT/MyApp.git
git remote -v
```

This approach retains the template's Git history. Confirm that `origin` points to your repository before publishing changes.

## Rename the application and library

The rename script requires Bash and Python 3. Run it from your new project directory:

```bash
./scripts/rename.sh MyApp MyAppLib myapp
git diff
git status --short
```

The arguments are the application name, library name, and C++ namespace. Use names suitable for C++ identifiers; the example uses the standard `<ApplicationName>Lib` naming convention.

The script updates project names in build configuration, C++ sources, public headers, tests, the HTML shell, and selected editor configuration. It also renames library files and the logo file. It does not change the Git remote or replace the original author's metadata everywhere.

## Update identity and attribution

Review these files before your first publication:

| File | What to review |
| --- | --- |
| [README.md](../README.md) | Project description, clone URL, workflow badges, application and API links, support link, and authorship statement |
| [assets/customstrings.json](../assets/customstrings.json) | Author name and repository URL printed by the application |
| [assets/](../assets/) | Logo artwork and the appearance of `index.html`; renaming an SVG does not change its artwork |
| [meson.build](../meson.build) and [Doxyfile](../Doxyfile) | Project version and documentation metadata |
| [nix/flake.nix](../nix/flake.nix) | Package description, maintainer list, and license metadata |
| [.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) | Development environment name and port labels |
| [LICENSE](../LICENSE) | Preserve the template's MIT license and copyright notice with the reused code; add attribution for your own contributions as appropriate |

The rename script replaces project names, but it does not replace the repository owner in URLs. Check badges and links for the original owner's account. Adapt the README's AI-assistance statement to describe your own development process, and review this guide's example names and links as well.

## Build and test the renamed project

After reviewing the changes, stage the renamed and new files so the Git-backed Nix flake can see them. Staging does not commit or push anything:

```bash
git add -A
nix develop ./nix
make debug
./build/builddir-debug/MyApp
make test
```

If you built the template before renaming it, run `make clean` before `make debug` to discard the previous build configuration. The sample application should initialize the renamed library and load `MyAppLogo.svg`.

## Configure CI and optional web publishing

Review [.github/workflows/](../.github/workflows/) for the checks and target platforms your project needs. Pushes and pull requests matching each workflow's path filters trigger its jobs; even README changes trigger some workflows. Batch related edits before pushing.

The [Documentation workflow](../.github/workflows/docs.yml) builds and publishes:

- A WebAssembly **debug** application at the site's root, with its source map and `debug-src/` project sources.
- Doxygen API documentation under `html/`.

If you want this website, select **GitHub Actions** as the source in your repository's **Settings → Pages**. The workflow currently publishes pushes to `main`; update its branch filter if you use a different default branch. Use the resulting Pages URL for the application link in your README and append `html/index.html` for the API reference.

If you do not want automatic publishing, disable the Documentation workflow in your repository or remove its deployment configuration before your first push.

Commit and push when you are ready. Check the resulting workflow runs and, if enabled, both published pages in your own repository.
