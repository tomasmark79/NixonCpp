#include <Utils/Filesystem/FileReader.hpp>
#include <Utils/Filesystem/FileWriter.hpp>
#include <Utils/Json/JsonSerializer.hpp>
#include <chrono>
#include <filesystem>
#include <gtest/gtest.h>
#include <memory>

using namespace nixoncpp::utils;
namespace fs = std::filesystem;

class JsonSerializerTest : public ::testing::Test {
protected:
  void SetUp() override {
    const auto *testInfo = ::testing::UnitTest::GetInstance()->current_test_info();
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    testDir_ = fs::temp_directory_path() /
               (std::string("JsonSerializerTest_") +
                (testInfo != nullptr ? testInfo->name() : "unknown") + "_" + std::to_string(stamp));
    fs::create_directories(testDir_);
    serializer_ = std::make_unique<JsonSerializer>(std::make_shared<FileReader>(),
                                                   std::make_shared<FileWriter>());
  }

  void TearDown() override {
    std::error_code ec;
    fs::remove_all(testDir_, ec);
  }

  fs::path testDir_;
  std::unique_ptr<JsonSerializer> serializer_;
};

TEST_F(JsonSerializerTest, ParseValidJson) {
  auto res = serializer_->parse(R"({"name":"NixonCpp","version":1})");
  ASSERT_TRUE(res.hasValue());
  EXPECT_EQ(res.value()["name"], "NixonCpp");
  EXPECT_EQ(res.value()["version"], 1);
}

TEST_F(JsonSerializerTest, ParseInvalidJsonReturnsParseError) {
  auto res = serializer_->parse("{invalid json");
  EXPECT_FALSE(res.hasValue());
  EXPECT_EQ(res.error().code, JsonErrorCode::ParseError);
}

TEST_F(JsonSerializerTest, SaveAndLoadRoundTrip) {
  const auto path = testDir_ / "sample.json";
  nlohmann::json input = {{"key", "value"}, {"items", {1, 2, 3}}};

  ASSERT_TRUE(serializer_->saveToFile(path, input).hasValue());
  auto loaded = serializer_->loadFromFile(path);
  ASSERT_TRUE(loaded.hasValue());
  EXPECT_EQ(loaded.value(), input);
}

TEST_F(JsonSerializerTest, LoadMissingFileReturnsFileNotFound) {
  auto res = serializer_->loadFromFile(testDir_ / "missing.json");
  EXPECT_FALSE(res.hasValue());
  EXPECT_EQ(res.error().code, JsonErrorCode::FileNotFound);
}

TEST_F(JsonSerializerTest, SaveToDirectoryReturnsWriteError) {
  nlohmann::json input = {{"ok", true}};
  auto res = serializer_->saveToFile(testDir_, input);
  EXPECT_FALSE(res.hasValue());
  EXPECT_EQ(res.error().code, JsonErrorCode::WriteError);
}
