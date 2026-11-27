#include <Utils/Filesystem/DirectoryManager.hpp>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include <string>

using namespace nixoncpp::utils;
namespace fs = std::filesystem;

class DirectoryManagerTest : public ::testing::Test {
protected:
  void SetUp() override {
    const auto *testInfo = ::testing::UnitTest::GetInstance()->current_test_info();
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    testDir_ = fs::temp_directory_path() /
               (std::string("DirectoryManagerTest_") +
                (testInfo != nullptr ? testInfo->name() : "unknown") + "_" + std::to_string(stamp));
    fs::create_directories(testDir_);
  }

  void TearDown() override {
    std::error_code ec;
    fs::remove_all(testDir_, ec);
  }

  fs::path testDir_;
  DirectoryManager dirManager_;
};

TEST_F(DirectoryManagerTest, CreateExistsAndIsEmpty) {
  const auto subDir = testDir_ / "nested" / "dir";
  EXPECT_FALSE(dirManager_.exists(subDir));

  ASSERT_TRUE(dirManager_.createDirectory(subDir).hasValue());
  EXPECT_TRUE(dirManager_.exists(subDir));

  auto emptyRes = dirManager_.isEmpty(subDir);
  ASSERT_TRUE(emptyRes.hasValue());
  EXPECT_TRUE(emptyRes.value());

  std::ofstream(subDir / "file.txt") << "hello";
  auto nonEmptyRes = dirManager_.isEmpty(subDir);
  ASSERT_TRUE(nonEmptyRes.hasValue());
  EXPECT_FALSE(nonEmptyRes.value());
}

TEST_F(DirectoryManagerTest, ListEntriesAndRecursive) {
  const auto sub = testDir_ / "sub";
  ASSERT_TRUE(dirManager_.createDirectory(sub).hasValue());
  std::ofstream(testDir_ / "top.txt") << "a";
  std::ofstream(sub / "deep.txt") << "b";

  auto topEntries = dirManager_.listEntries(testDir_);
  ASSERT_TRUE(topEntries.hasValue());
  EXPECT_EQ(topEntries.value().size(), 2);

  auto recursiveEntries = dirManager_.listEntriesRecursive(testDir_);
  ASSERT_TRUE(recursiveEntries.hasValue());
  EXPECT_EQ(recursiveEntries.value().size(), 3);
}

TEST_F(DirectoryManagerTest, RemoveEmptyAndRecursive) {
  const auto emptyDir = testDir_ / "empty";
  ASSERT_TRUE(dirManager_.createDirectory(emptyDir).hasValue());
  ASSERT_TRUE(dirManager_.removeDirectory(emptyDir).hasValue());
  EXPECT_FALSE(dirManager_.exists(emptyDir));

  const auto treeDir = testDir_ / "tree";
  ASSERT_TRUE(dirManager_.createDirectory(treeDir / "child").hasValue());
  std::ofstream(treeDir / "child" / "data.txt") << "x";

  auto removed = dirManager_.removeDirectoryRecursive(treeDir);
  ASSERT_TRUE(removed.hasValue());
  EXPECT_GE(removed.value(), 3U);
  EXPECT_FALSE(dirManager_.exists(treeDir));
}

TEST_F(DirectoryManagerTest, CurrentAndTempDirectoriesExist) {
  auto cwd = dirManager_.getCurrentDirectory();
  ASSERT_TRUE(cwd.hasValue());
  EXPECT_TRUE(dirManager_.exists(cwd.value()));

  auto tmp = dirManager_.getTempDirectory();
  ASSERT_TRUE(tmp.hasValue());
  EXPECT_TRUE(dirManager_.exists(tmp.value()));
}

TEST_F(DirectoryManagerTest, FailsOnMissingOrFilePath) {
  const auto missing = testDir_ / "does_not_exist";
  EXPECT_FALSE(dirManager_.isEmpty(missing).hasValue());
  EXPECT_FALSE(dirManager_.listEntries(missing).hasValue());

  const auto regularFile = testDir_ / "plain.txt";
  std::ofstream(regularFile) << "content";
  EXPECT_FALSE(dirManager_.exists(regularFile));
  EXPECT_FALSE(dirManager_.listEntries(regularFile).hasValue());
}
