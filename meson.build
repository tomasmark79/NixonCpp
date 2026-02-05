# NixonCpp Project
# MIT License Copyright (c) 2024-2026 Tomáš Mark

project('NixonCpp', 'cpp',
  version: '1.0.0',
  license: 'MIT',
  default_options: [
    'cpp_std=c++20',
    'warning_level=3',
    'buildtype=release',
  ]
)

# Use light optimization for debug to satisfy _FORTIFY_SOURCE requirements
# if get_option('buildtype') == 'debug'
#   add_project_arguments('-Og', language: 'c')
#   add_project_arguments('-Og', language: 'cpp')
# endif

# Check if we're cross-compiling or targeting specific platforms
is_wasm = meson.get_external_property('system', host_machine.system()) == 'emscripten'
is_windows = host_machine.system() == 'windows'
is_cross = meson.is_cross_build()
is_windows_cross = is_cross and is_windows
is_native = not is_cross and not is_wasm and not is_windows
fmt_header_only = is_wasm or is_windows or is_cross
tests_opt = get_option('build_tests')

# Required dependencies (optional for cross builds)
fmt_dep = dependency('fmt', required: false)
if not fmt_dep.found()
  fmt_dep = declare_dependency()  # Empty dependency, assuming headers are available
  warning('fmt not found, assuming headers are in system path')
endif

# nlohmann_json is header-only, should work
json_dep = dependency('nlohmann_json', required: false)
if not json_dep.found()
  json_dep = declare_dependency()
  warning('nlohmann_json not found, assuming headers are in system path')
endif

# cxxopts is header-only, should work
cxxopts_dep = dependency('cxxopts', required: false)
if not cxxopts_dep.found()
  cxxopts_dep = declare_dependency()
  warning('cxxopts not found, assuming headers are in system path')
endif

# Optional dependencies for tests
gtest_dep = dependency('gtest', required: false)
gtest_main_dep = dependency('gtest_main', required: false)

# Platform-specific dependencies
if is_wasm
  threads_dep = declare_dependency()
else
  threads_dep = dependency('threads')
endif

# Include directories
inc_dirs = include_directories('include')
src_inc_dirs = include_directories('src/lib')

# Collect all library sources
lib_sources = [
  'src/lib/NixonCppLib.cpp',
  'src/lib/Utils/UtilsFactory.cpp',
  'src/lib/Utils/Assets/AssetManager.cpp',
  'src/lib/Utils/Filesystem/DirectoryManager.cpp',
  'src/lib/Utils/Filesystem/FileReader.cpp',
  'src/lib/Utils/Filesystem/FileWriter.cpp',
  'src/lib/Utils/Filesystem/PathResolver.cpp',
  'src/lib/Utils/Json/CustomStringsLoader.cpp',
  'src/lib/Utils/Json/JsonSerializer.cpp',
  'src/lib/Utils/Logger/LoggerFactory.cpp',
  'src/lib/Utils/Platform/EmscriptenPlatformInfo.cpp',
  'src/lib/Utils/Platform/PlatformInfoFactory.cpp',
  'src/lib/Utils/Platform/UnixPlatformInfo.cpp',
  'src/lib/Utils/Platform/WindowsPlatformInfo.cpp',
  'src/lib/Utils/String/StringFormatter.cpp',
]

# Platform-specific compilation flags
platform_args = []

if is_windows
  platform_args += ['-DWIN32', '-D_WIN32']
elif host_machine.system() == 'linux'
  platform_args += ['-D__linux__']
elif host_machine.system() == 'darwin'
  platform_args += ['-D__APPLE__']
endif

lib_cpp_args = platform_args
if fmt_header_only
  lib_cpp_args += ['-DFMT_HEADER_ONLY']
endif

common_inc = [inc_dirs, src_inc_dirs]

if is_native or is_wasm
  lib_deps = [fmt_dep, json_dep, threads_dep]
else
  # Cross-compilation (including Windows) - avoid linking fmt/json
  lib_deps = [threads_dep]
endif

# Build the library
# WebAssembly doesn't support shared libraries, use static only
if not is_wasm
  nixoncpplib_shared = shared_library('NixonCppLib',
    lib_sources,
    include_directories: common_inc,
    dependencies: lib_deps,
    cpp_args: lib_cpp_args,
    install: true,
  )
endif

nixoncpplib_static = static_library('NixonCppLib',
  lib_sources,
  include_directories: common_inc,
  dependencies: lib_deps,
  cpp_args: lib_cpp_args,
  install: true,
)

if is_wasm or is_windows
  link_lib = nixoncpplib_static
else
  link_lib = nixoncpplib_shared
endif

nixoncpplib_dep = declare_dependency(
  link_with: link_lib,
  include_directories: inc_dirs,
  dependencies: lib_deps,
  compile_args: fmt_header_only ? ['-DFMT_HEADER_ONLY'] : [],
)

# Install headers
install_subdir('include/NixonCppLib',
  install_dir: get_option('includedir')
)

# Build application
app_sources = [
  'src/app/Application.cpp',
]

# WebAssembly needs special handling - embed assets into the binary
app_deps = [nixoncpplib_dep]
if is_native or is_wasm
  app_deps += [cxxopts_dep]
endif

if is_wasm
  executable('NixonCpp',
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    name_suffix: 'html',
    link_args: [
      '--shell-file', meson.project_source_root() / 'assets' / 'ems-mini.html',
      '-sUSE_PTHREADS=0',
      '-sPTHREAD_POOL_SIZE=0',
      '--embed-file', meson.project_source_root() / 'assets@/share/NixonCpp/assets',
    ],
    install: true,
  )
elif is_windows
  # Windows with static linking
  # cxxopts is header-only, we don't need its pkg-config deps (which include ICU)
  executable('NixonCpp',
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    link_args: ['-static', '-static-libgcc', '-static-libstdc++'],
    install: true,
  )
else
  # Native and cross (non-Windows) build
  executable('NixonCpp',
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    install: true,
  )
endif

# Copy assets to build directory for development/testing.
# Skip only on native Windows builds where cp may not be available.
# This ensures assets are available when running the application from the build directory.
if not is_wasm and (not is_windows or meson.is_cross_build())
  run_command('cp', '-r', meson.project_source_root() / 'assets', meson.project_build_root(), check: false)
endif

# Install assets for production deployment
install_subdir('assets',
  install_dir: get_option('datadir') / 'NixonCpp'
)

# Tests (native only)
# Cross-compiled tests can't run on the build machine anyway
if not tests_opt.disabled()
  if meson.is_cross_build()
    if tests_opt.enabled()
      error('Tests are only supported for native builds')
    endif
  elif gtest_dep.found() and gtest_main_dep.found()
    subdir('tests')
  elif tests_opt.enabled()
    error('Tests enabled, but gtest was not found')
  endif
endif

# Summary
summary({
  'prefix': get_option('prefix'),
  'bindir': get_option('bindir'),
  'libdir': get_option('libdir'),
  'datadir': get_option('datadir'),
  'includedir': get_option('includedir'),
}, section: 'Directories')

summary({
  'fmt': fmt_dep.found(),
  'nlohmann_json': json_dep.found(),
  'cxxopts': cxxopts_dep.found(),
  'gtest': gtest_dep.found(),
}, section: 'Dependencies')

summary({
  'C++ Standard': get_option('cpp_std'),
  'Build Type': get_option('buildtype'),
  'Warning Level': get_option('warning_level'),
}, section: 'Build Options')
