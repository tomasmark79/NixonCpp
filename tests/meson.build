# Tests for NixonCpp Application

test_sources = [
  'AssetManagerTest.cpp',
  'ConsoleLoggerTest.cpp',
  'FileReaderTest.cpp',
]

foreach test_source : test_sources
  test_name = test_source.split('.')[0]
  
  test_exe = executable(test_name,
    test_source,
    include_directories: [inc_dirs, src_inc_dirs],
    dependencies: [lib_dep, gtest_dep, gtest_main_dep],
  )
  
  test(test_name, test_exe)
endforeach
