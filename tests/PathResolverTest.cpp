#include <Utils/Filesystem/PathResolver.hpp>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include <string>

using namespace nixoncpp::utils;
namespace fs = std::filesystem;

class PathResolverTest : public ::testing::Test {
protected:
  void SetUp() override {
    const auto *testInfo = ::testing::UnitTest::GetInstance()->current_test_info();
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    testDir_ = fs::temp_directory_path() /
               (std::string("PathResolverTest_") +
                (testInfo != nullptr ? testInfo->name() : "unknown") + "_" + std::to_string(stamp));
    fs::create_directories(testDir_);
    testFile_ = testDir_ / "example.tar.gz";
    std::ofstream(testFile_) << "data";
  }

  void TearDown() override {
    std::error_code ec;
    fs::remove_all(testDir_, ec);
  }

  fs::path testDir_;
  fs::path testFile_;
  PathResolver resolver_;
};

TEST_F(PathResolverTest, AbsoluteAndCanonicalPaths) {
  auto absRes = resolver_.getAbsolutePath(fs::path("relative") / "file.txt");
  ASSERT_TRUE(absRes.hasValue());
  EXPECT_TRUE(resolver_.isAbsolute(absRes.value()));
  EXPECT_FALSE(resolver_.isRelative(absRes.value()));

  auto canonRes = resolver_.getCanonicalPath(testDir_ / "." / "example.tar.gz");
  ASSERT_TRUE(canonRes.hasValue());
  EXPECT_EQ(canonRes.value(), fs::canonical(testFile_));
}

TEST_F(PathResolverTest, CanonicalPathFailsForNonexistentPath) {
  auto res = resolver_.getCanonicalPath(testDir_ / "missing.txt");
  EXPECT_FALSE(res.hasValue());
}

TEST_F(PathResolverTest, RelativePathComputation) {
  auto relRes = resolver_.getRelativePath(testFile_, testDir_);
  ASSERT_TRUE(relRes.hasValue());
  EXPECT_EQ(relRes.value(), fs::path("example.tar.gz"));
  EXPECT_TRUE(resolver_.isRelative(relRes.value()));
}

TEST_F(PathResolverTest, PathComponentExtractionAndJoin) {
  EXPECT_EQ(resolver_.getParent(testFile_), testDir_);
  EXPECT_EQ(resolver_.getFilename(testFile_), "example.tar.gz");
  EXPECT_EQ(resolver_.getExtension(testFile_), ".gz");
  EXPECT_EQ(resolver_.getStem(testFile_), "example.tar");

  const auto joined = resolver_.join({"alpha", "beta", "gamma.txt"});
  EXPECT_EQ(joined, fs::path("alpha") / "beta" / "gamma.txt");
}
