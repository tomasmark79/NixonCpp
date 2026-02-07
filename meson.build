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

project_name = meson.project_name()
lib_name = project_name + 'Lib'

# Build/target flags
is_wasm = meson.get_external_property('system', host_machine.system()) == 'emscripten'
is_windows = host_machine.system() == 'windows'
is_linux = host_machine.system() == 'linux'
is_darwin = host_machine.system() == 'darwin'
is_cross = meson.is_cross_build()
is_native = not is_cross and not is_wasm and not is_windows
fmt_header_only = is_wasm or is_windows or is_cross
tests_opt = get_option('build_tests')
asan_opt = get_option('sanitize_address')
ubsan_opt = get_option('sanitize_undefined')
tsan_opt = get_option('sanitize_thread')
build_type = get_option('buildtype')
is_debug_build = build_type == 'debug' or build_type == 'debugoptimized'

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

# Platform-specific compilation flags
platform_args = []

if is_windows
  platform_args += ['-DWIN32', '-D_WIN32']
elif is_linux
  platform_args += ['-D__linux__']
elif is_darwin
  platform_args += ['-D__APPLE__']
endif

lib_cpp_args = platform_args
if fmt_header_only
  lib_cpp_args += ['-DFMT_HEADER_ONLY']
endif

# Emscripten debug: generate source maps so DevTools can show .cpp files
# NOTE: We intentionally avoid -fdebug-prefix-map here. The source-map
# generator (wasm-sourcemap.py) converts absolute DWARF paths to paths
# relative to the .wasm file, which then resolve correctly against the
# source-map-base URL.  Using -fdebug-prefix-map would mix relative
# styles and break resolution for some files.
if is_wasm and is_debug_build
  wasm_debug_cpp_args = [
    '-g3',
  ]
  lib_cpp_args += wasm_debug_cpp_args

  wasm_debug_link_args = [
    '-g3',
    '-gsource-map',
    '--source-map-base', 'http://localhost:6931/build/builddir-wasm-' + build_type + '/',
  ]
  add_project_link_arguments(wasm_debug_link_args, language: 'cpp')
endif

# Sanitizers (native only)
if is_native
  if ubsan_opt
    lib_cpp_args += ['-fsanitize=undefined']
    add_project_link_arguments('-fsanitize=undefined', language: 'cpp')
  endif
  if tsan_opt
    lib_cpp_args += ['-fsanitize=thread']
    add_project_link_arguments('-fsanitize=thread', language: 'cpp')
  endif
  if asan_opt
    lib_cpp_args += ['-fsanitize=address']
    add_project_link_arguments('-fsanitize=address', language: 'cpp')
  endif
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

if is_wasm or is_windows
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

# WebAssembly needs special handling - embed assets into the binary
app_deps = is_native or is_wasm ? [lib_dep, cxxopts_dep] : [lib_dep]

if is_wasm
  executable(project_name,
    app_sources,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: app_deps,
    name_suffix: 'html',
    link_args: [
      '--shell-file', meson.project_source_root() / 'assets' / 'ems-mini.html',
      '-sUSE_PTHREADS=0',
      '-sPTHREAD_POOL_SIZE=0',
      '--embed-file', meson.project_source_root() / ('assets@/share/' + project_name + '/assets'),
    ],
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

# Copy assets to build directory for development/testing.
# Skip only on native Windows builds where cp may not be available.
# This ensures assets are available when running the application from the build directory.
if not is_wasm and (not is_windows or meson.is_cross_build())
  run_command('cp', '-r', meson.project_source_root() / 'assets', meson.project_build_root(), check: false)
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
