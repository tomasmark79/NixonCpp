#include <Utils/Filesystem/FileReader.hpp>
#include <Utils/Filesystem/FileWriter.hpp>
#include <chrono>
#include <filesystem>
#include <gtest/gtest.h>
#include <string>
#include <vector>

using namespace nixoncpp::utils;
namespace fs = std::filesystem;

class FileWriterTest : public ::testing::Test {
protected:
  void SetUp() override {
    const auto *testInfo = ::testing::UnitTest::GetInstance()->current_test_info();
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    testDir_ = fs::temp_directory_path() /
               (std::string("FileWriterTest_") +
                (testInfo != nullptr ? testInfo->name() : "unknown") + "_" + std::to_string(stamp));
    fs::create_directories(testDir_);
  }

  void TearDown() override {
    std::error_code ec;
    fs::remove_all(testDir_, ec);
  }

  fs::path testDir_;
  FileWriter writer_;
  FileReader reader_;
};

TEST_F(FileWriterTest, WriteAndOverwriteTextFile) {
  const auto path = testDir_ / "hello.txt";
  ASSERT_TRUE(writer_.write(path, "First").hasValue());
  EXPECT_EQ(reader_.read(path).value(), "First");

  ASSERT_TRUE(writer_.write(path, "Second").hasValue());
  EXPECT_EQ(reader_.read(path).value(), "Second");
}

TEST_F(FileWriterTest, WriteAppendsWhenRequested) {
  const auto path = testDir_ / "append.txt";
  ASSERT_TRUE(writer_.write(path, "Hello").hasValue());
  ASSERT_TRUE(writer_.write(path, ", World!", true).hasValue());
  EXPECT_EQ(reader_.read(path).value(), "Hello, World!");
}

TEST_F(FileWriterTest, WriteCreatesMissingParentDirectories) {
  const auto path = testDir_ / "nested" / "deep" / "file.txt";
  ASSERT_TRUE(writer_.write(path, "nested content").hasValue());
  EXPECT_EQ(reader_.read(path).value(), "nested content");
}

TEST_F(FileWriterTest, WriteBytesRoundTrip) {
  const auto path = testDir_ / "data.bin";
  const std::vector<uint8_t> data = {0x00, 0x01, 0x7F, 0xFE, 0xFF};
  ASSERT_TRUE(writer_.writeBytes(path, data).hasValue());

  auto readBack = reader_.readBytes(path);
  ASSERT_TRUE(readBack.hasValue());
  EXPECT_EQ(readBack.value(), data);
}

TEST_F(FileWriterTest, WriteLinesRoundTrip) {
  const auto path = testDir_ / "lines.txt";
  const std::vector<std::string> lines = {"alpha", "beta", "gamma"};
  ASSERT_TRUE(writer_.writeLines(path, lines).hasValue());

  auto readBack = reader_.readLines(path);
  ASSERT_TRUE(readBack.hasValue());
  EXPECT_EQ(readBack.value(), lines);
}

TEST_F(FileWriterTest, TouchCreatesEmptyFile) {
  const auto path = testDir_ / "touched.txt";
  ASSERT_TRUE(writer_.touch(path).hasValue());
  EXPECT_TRUE(reader_.exists(path));
  EXPECT_EQ(reader_.getSize(path).value(), 0);
}

TEST_F(FileWriterTest, FailsForEmptyPathAndDirectory) {
  auto emptyRes = writer_.write(fs::path{}, "x");
  EXPECT_FALSE(emptyRes.hasValue());
  EXPECT_EQ(emptyRes.error().code, FileErrorCode::InvalidPath);

  auto dirRes = writer_.write(testDir_, "x");
  EXPECT_FALSE(dirRes.hasValue());
  EXPECT_EQ(dirRes.error().code, FileErrorCode::IsDirectory);
}
