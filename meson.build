# NixonCpp Project
# MIT License Copyright (c) 2024-2026 Tomáš Mark

project('NixonCpp', 'cpp',
  version: '0.0.1',
  license: 'MIT',
  default_options: [
    'cpp_std=c++20',
    'warning_level=3',
    'buildtype=release',
  ]
)

project_name = meson.project_name()
lib_name = project_name + 'Lib'

# Build/target flags
is_wasm = meson.get_external_property('system', host_machine.system()) == 'emscripten'
is_windows = host_machine.system() == 'windows'
is_cross = meson.is_cross_build()
is_native = not is_cross and not is_wasm and not is_windows
fmt_header_only = is_wasm or is_windows or is_cross
tests_opt = get_option('build_tests')
build_type = get_option('buildtype')
is_debug_build = build_type == 'debug' or build_type == 'debugoptimized'
wasm_opt_level = get_option('wasm_opt_level')

# Native builds require package metadata. Cross, Windows and WASM builds use
# these libraries header-only, so validate the actual headers supplied by the
# toolchain without pulling in irrelevant pkg-config link dependencies.
cpp_compiler = meson.get_compiler('cpp')

if is_native
  fmt_dep = dependency('fmt', required: true)
  json_dep = dependency('nlohmann_json', required: true)
  cxxopts_dep = dependency('cxxopts', required: true)
  fmt_status = 'dependency'
  json_status = 'dependency'
  cxxopts_status = 'dependency'
else
  if not cpp_compiler.has_header('fmt/format.h')
    error('fmt headers not found in the cross toolchain')
  endif
  if not cpp_compiler.has_header('nlohmann/json.hpp')
    error('nlohmann_json headers not found in the cross toolchain')
  endif
  if not cpp_compiler.has_header('cxxopts.hpp')
    error('cxxopts headers not found in the cross toolchain')
  endif

  fmt_dep = declare_dependency()
  json_dep = declare_dependency()
  cxxopts_dep = declare_dependency()
  fmt_status = 'headers'
  json_status = 'headers'
  cxxopts_status = 'headers'
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
  'src/lib/' + lib_name + '.cpp',
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

lib_cpp_args = []
if fmt_header_only
  lib_cpp_args += ['-DFMT_HEADER_ONLY']
endif

# Emscripten debug: keep DWARF in compile objects and generate a source map
# at link time so DevTools can show project .cpp files over HTTP.
#
# Important: do NOT pass -g3 to the link step here. Linking with both -g3 and
# -gsource-map can leave both embedded DWARF and source-map metadata in the
# final .wasm, and the DWARF extension may then prefer EmbeddedDWARF.
#
# We intentionally avoid -fdebug-prefix-map so wasm-sourcemap.py can derive
# consistent relative paths from DWARF and resolve them against source-map-base.
if is_wasm and is_debug_build
  wasm_debug_cpp_args = [
    '-g3',
  ]
  lib_cpp_args += wasm_debug_cpp_args
  add_project_arguments(wasm_debug_cpp_args, language: 'cpp')

  wasm_debug_link_args = [
    '-gsource-map',
    '--source-map-base', './',
  ]
  add_project_link_arguments(wasm_debug_link_args, language: 'cpp')
endif

if is_wasm and wasm_opt_level != 'auto'
  wasm_opt_flag = '-' + wasm_opt_level
  lib_cpp_args += [wasm_opt_flag]
  add_project_link_arguments(wasm_opt_flag, language: 'cpp')
endif

common_inc = [inc_dirs, src_inc_dirs]

# Determine library dependencies based on platform
if is_native or is_wasm
  lib_deps = [threads_dep, fmt_dep, json_dep]
else
  # Cross-compilation (including Windows) - avoid linking fmt/json
  lib_deps = [threads_dep]
endif

# Build the library
# WebAssembly doesn't support shared libraries, use static only
if not is_wasm
  lib_shared = shared_library(lib_name,
    lib_sources,
    include_directories: common_inc,
    dependencies: lib_deps,
    cpp_args: lib_cpp_args,
    install: true,
  )
endif

lib_static = static_library(lib_name,
  lib_sources,
  include_directories: common_inc,
  dependencies: lib_deps,
  cpp_args: lib_cpp_args,
  install: true,
)

if is_wasm or is_windows or is_cross
  link_lib = lib_static
else
  link_lib = lib_shared
endif

lib_dep = declare_dependency(
  link_with: link_lib,
  include_directories: inc_dirs,
  dependencies: lib_deps,
  compile_args: fmt_header_only ? ['-DFMT_HEADER_ONLY'] : [],
)

# Install headers
install_subdir('include/' + lib_name,
  install_dir: get_option('includedir')
)

# Build application
app_sources = [
  'src/app/Application.cpp',
]

# Keep the development asset tree synchronized on every build. The helper only
# updates its stamp when the contents actually change, so dependent targets are
# not rebuilt unnecessarily. This also detects added and removed nested files.
asset_sync_script = meson.project_source_root() / 'scripts' / 'sync-assets.sh'
asset_sync = custom_target('sync-assets',
  output: 'assets-sync.stamp',
  command: [
    find_program('bash'),
    asset_sync_script,
    meson.project_source_root() / 'assets',
    meson.project_build_root() / 'assets',
    '@OUTPUT@',
  ],
  build_by_default: true,
  build_always_stale: true,
)

# WebAssembly needs special handling - embed assets into the binary
app_deps = is_native or is_wasm ? [lib_dep, cxxopts_dep] : [lib_dep]

if is_wasm
  executable(project_name,
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    name_suffix: 'html',
    link_args: [
      '--shell-file', meson.project_source_root() / 'assets' / 'index.html',
      '--embed-file', meson.project_source_root() / ('assets@/share/' + project_name + '/assets'),
      '--embed-file', meson.project_source_root() / ('README.md@/share/' + project_name + '/README.md'),
    ],
    link_depends: [asset_sync] + files('README.md'),
    install: true,
  )
elif is_windows
  # Windows with static linking
  # cxxopts is header-only, we don't need its pkg-config deps (which include ICU)
  executable(project_name,
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    link_args: ['-static', '-static-libgcc', '-static-libstdc++'],
    install: true,
  )
else
  # Native and cross (non-Windows) build
  executable(project_name,
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    install: true,
  )
endif

# Install assets for production deployment
install_subdir('assets',
  install_dir: get_option('datadir') / project_name
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
  'fmt': fmt_status,
  'nlohmann_json': json_status,
  'cxxopts': cxxopts_status,
  'gtest': gtest_dep.found(),
}, section: 'Dependencies')

summary({
  'C++ Standard': get_option('cpp_std'),
  'Build Type': get_option('buildtype'),
  'Warning Level': get_option('warning_level'),
  'WASM Opt Level': get_option('wasm_opt_level'),
}, section: 'Build Options')
