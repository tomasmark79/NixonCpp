# Makefile for NixonCpp
# Provides convenient shortcuts for common tasks

ARCHS := native aarch64 windows wasm
BUILD_TYPES := debug release debugoptimized minsize

.PHONY: help build debug build-clang debug-clang all everything test test-verbose clean clean-packages dev format check doxygen \
	cross-aarch64 cross-windows cross-wasm cross-all \
	install nix-build pin-shells package-native package-aarch64 package-windows package-wasm package-all packages \
	build-all-buildtypes build-all-arch-buildtypes package-all-buildtypes package-all-arch-buildtypes \
	quick rebuild $(addprefix build-,$(foreach a,$(ARCHS),$(addprefix $(a)-,$(BUILD_TYPES)))) \
	$(addprefix package-,$(foreach a,$(ARCHS),$(addprefix $(a)-,$(BUILD_TYPES))))

# Default target
help:
	@echo "NixonCpp - Available targets:"
	@echo ""
	@echo "  make build          - Build the project (release)"
	@echo "  make debug          - Build in debug mode"
	@echo "  make build-clang    - Build with clang (release)"
	@echo "  make debug-clang    - Build with clang (debug)"
	@echo "  make all            - Build for ALL platforms (native + cross)"
	@echo "  make everything     - Build all variants (native gcc/clang + cross)"
	@echo "  make test           - Run all tests"
	@echo "  make clean          - Clean build directories"
	@echo "  make clean-packages - Clean generated packages"
	@echo "  make format         - Format source code"
	@echo "  make check          - Run clang-tidy checks"
	@echo "  make doxygen        - Generate Doxygen documentation"
	@echo ""
	@echo "Cross-compilation:"
	@echo "  make cross-aarch64  - Build for ARM64"
	@echo "  make cross-windows  - Build for Windows"
	@echo "  make cross-wasm     - Build for WebAssembly"
	@echo "  make cross-all      - Build for all cross-compilation targets"
	@echo ""
	@echo "All buildtype combos:"
	@echo "  make build-all-buildtypes        - Build all arch x buildtype"
	@echo "  make package-all-buildtypes      - Package all arch x buildtype"
	@echo "  make build-<arch>-<type>         - Build specific combo"
	@echo "  make package-<arch>-<type>       - Package specific combo"
	@echo ""
	@echo "Development:"
	@echo "  make dev            - Enter development shell"
	@echo "  make nix-build      - Build Nix package (nix build ./nix#NixonCpp)"
	@echo "  make pin-shells     - Pin all Nix dev shells as GC roots (prevents re-download)"
	@echo "  make install        - Install to system"
	@echo "  make packages       - Build all packages"
	@echo ""

# Build targets
build:
	@./scripts/solution-controller.sh both "Build" native release

debug:
	@./scripts/solution-controller.sh both "Build" native debug

build-clang:
	@./scripts/solution-controller.sh both "Build" native release clang

debug-clang:
	@./scripts/solution-controller.sh both "Build" native debug clang

# Testing
test: debug
	@./scripts/solution-controller.sh both "Run Tests" native debug

test-verbose:
	@nix develop ./nix --command meson test -C build/builddir-debug -v

# Clean
clean:
	@rm -rf build/builddir* .cache
	@echo "✓ Cleaned build directories"

clean-packages:
	@rm -rf build/package-*
	@rm -f build/NixonCpp-*.tar.gz
	@echo "✓ Cleaned package directories and tarballs"

# Development
dev:
	@nix develop ./nix

nix-build:
	@nix build ./nix#NixonCpp
	@echo "✓ Nix package built → ./result"

# Pin all dev shells as GC roots so nix-collect-garbage never removes them
# Uses nix print-dev-env to realise each shell into the store and symlinks it
# as a GC root. Run once after cloning, and again after 'nix flake update'.
pin-shells:
	@echo "Pinning Nix dev shells as GC roots..."
	@mkdir -p build
	@for shell in default aarch64 windows wasm; do \
	    echo "  pinning: $$shell ..."; \
	    drv=$$(nix eval --raw ./nix#devShells.x86_64-linux.$$shell.drvPath 2>/dev/null \
	          || nix eval --raw ./nix#devShells.aarch64-linux.$$shell.drvPath 2>/dev/null); \
	    if [ -n "$$drv" ]; then \
	        nix-store --realise "$$drv" --add-root "$(CURDIR)/build/.gcroot-shell-$$shell" --indirect >/dev/null; \
	        echo "    ✓ $$shell pinned"; \
	    else \
	        echo "    ⚠️  could not resolve $$shell (skipped)"; \
	    fi; \
	done
	@echo "✓ Dev shells pinned → build/.gcroot-shell-*"
	@echo "  Run 'make pin-shells' again after updating flake inputs."

# Code formatting
format:
	@./scripts/solution-controller.sh both "Format Code" native debug

# Static analysis
check:
	@./scripts/solution-controller.sh both "clang-tidy linting" native debug

# Documentation
doxygen:
	@./scripts/solution-controller.sh both "Generate Documentation" native release

# Cross-compilation
cross-aarch64:
	@./scripts/solution-controller.sh both "Build" aarch64 release

cross-windows:
	@./scripts/solution-controller.sh both "Build" windows release

cross-wasm:
	@./scripts/solution-controller.sh both "Build" wasm release

cross-all: cross-aarch64 cross-windows cross-wasm
	@echo "✓ All cross-compilation targets built"

define MAKE_BUILD_RULE
build-$(1)-$(2):
	@./scripts/solution-controller.sh both "Build" $(1) $(2)
endef

$(foreach a,$(ARCHS),$(foreach b,$(BUILD_TYPES),$(eval $(call MAKE_BUILD_RULE,$(a),$(b)))))

build-all-buildtypes: $(addprefix build-,$(foreach a,$(ARCHS),$(addprefix $(a)-,$(BUILD_TYPES))))
	@echo "✓ All arch/buildtype combinations built"

build-all-arch-buildtypes: build-all-buildtypes

# Build everything (native + all cross-compilation targets)
all: build cross-all
	@echo ""
	@echo "✓ All platforms built successfully!"
	@echo "  Native:  ./build/builddir-release/NixonCpp"
	@echo "  ARM64:   ./build/builddir-aarch64-release/NixonCpp"
	@echo "  Windows: ./build/builddir-windows-release/NixonCpp.exe"
	@echo "  WASM:    ./build/builddir-wasm-release/NixonCpp.js"

# Build all variants (native gcc/clang + cross)
everything: build debug build-clang debug-clang cross-all
	@echo ""
	@echo "✓ All variants built successfully!"
	@echo "  Native GCC release: ./build/builddir-release/NixonCpp"
	@echo "  Native GCC debug:   ./build/builddir-debug/NixonCpp"
	@echo "  Native Clang release: ./build/builddir-release-clang/NixonCpp"
	@echo "  Native Clang debug:   ./build/builddir-debug-clang/NixonCpp"
	@echo "  ARM64:   ./build/builddir-aarch64-release/NixonCpp"
	@echo "  Windows: ./build/builddir-windows-release/NixonCpp.exe"
	@echo "  WASM:    ./build/builddir-wasm-release/NixonCpp.js"

# Installation
install:
	@./scripts/solution-controller.sh both "Install built components" native release

define MAKE_PACKAGE_RULE
package-$(1)-$(2):
	@./scripts/solution-controller.sh both "Create Package" $(1) $(2)
endef

$(foreach a,$(ARCHS),$(foreach b,$(BUILD_TYPES),$(eval $(call MAKE_PACKAGE_RULE,$(a),$(b)))))

package-native:
	@./scripts/solution-controller.sh both "Create Package" native release

package-aarch64:
	@./scripts/solution-controller.sh both "Create Package" aarch64 release

package-windows:
	@./scripts/solution-controller.sh both "Create Package" windows release

package-wasm:
	@./scripts/solution-controller.sh both "Create Package" wasm release

package-all: package-native package-aarch64 package-windows package-wasm
	@echo ""
	@echo "✓ All packages created!"

package-all-buildtypes: $(addprefix package-,$(foreach a,$(ARCHS),$(addprefix $(a)-,$(BUILD_TYPES))))
	@echo ""
	@echo "✓ All arch/buildtype packages created!"

package-all-arch-buildtypes: package-all-buildtypes

packages: package-all

# Quick development cycle
quick: build test
	@echo "✓ Build and test complete"

# Full rebuild
rebuild: clean build
	@echo "✓ Full rebuild complete"
