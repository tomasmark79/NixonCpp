# Makefile for NixonCpp
# Provides convenient shortcuts for common tasks

.PHONY: help build debug build-clang debug-clang all everything test test-verbose clean clean-packages dev format check doxygen \
	cross-aarch64 cross-windows cross-wasm cross-all \
	install package-native package-aarch64 package-windows package-wasm package-all packages \
	quick rebuild

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
	@echo "Development:"
	@echo "  make dev            - Enter development shell"
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
test:
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

# Packaging targets
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

packages: package-all

# Quick development cycle
quick: build test
	@echo "✓ Build and test complete"

# Full rebuild
rebuild: clean build
	@echo "✓ Full rebuild complete"
