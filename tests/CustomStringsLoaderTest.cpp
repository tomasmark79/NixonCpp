#include "MockAssetManager.hpp"
#include <Utils/Filesystem/FileReader.hpp>
#include <Utils/Filesystem/FileWriter.hpp>
#include <Utils/Json/CustomStringsLoader.hpp>
#include <Utils/Json/JsonSerializer.hpp>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include <memory>

using namespace nixoncpp::utils;
namespace fs = std::filesystem;

class CustomStringsLoaderTest : public ::testing::Test {
protected:
  void SetUp() override {
    const auto *testInfo = ::testing::UnitTest::GetInstance()->current_test_info();
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    testDir_ = fs::temp_directory_path() /
               (std::string("CustomStringsLoaderTest_") +
                (testInfo != nullptr ? testInfo->name() : "unknown") + "_" + std::to_string(stamp));
    fs::create_directories(testDir_);

    std::ofstream(testDir_ / "customstrings.json") << R"({
      "strings": [
        {
          "id": "Greeting",
          "data": {
            "en": "Hello",
            "cs": "Ahoj",
            "path": "/assets/greeting.txt",
            "url": "https://example.com"
          }
        }
      ]
    })";

    assetManager_ = std::make_shared<MockAssetManager>(testDir_);
    serializer_ = std::make_shared<JsonSerializer>(std::make_shared<FileReader>(),
                                                   std::make_shared<FileWriter>());
    loader_ =
        std::make_unique<CustomStringsLoader>(assetManager_, serializer_, "customstrings.json");
  }

  void TearDown() override {
    std::error_code ec;
    fs::remove_all(testDir_, ec);
  }

  fs::path testDir_;
  std::shared_ptr<MockAssetManager> assetManager_;
  std::shared_ptr<JsonSerializer> serializer_;
  std::unique_ptr<CustomStringsLoader> loader_;
};

TEST_F(CustomStringsLoaderTest, LocalizedStringReturnsRequestedLocaleAndFallsBackToEnglish) {
  EXPECT_EQ(loader_->getLocalizedString("Greeting", "cs").value_or(""), "Ahoj");
  EXPECT_EQ(loader_->getLocalizedString("Greeting", "en").value_or(""), "Hello");
  EXPECT_EQ(loader_->getLocalizedString("Greeting", "de").value_or(""), "Hello");
  EXPECT_FALSE(loader_->getLocalizedString("Unknown", "en").has_value());
}

TEST_F(CustomStringsLoaderTest, GetPathAndCustomKey) {
  EXPECT_EQ(loader_->getPath("Greeting").value_or(""), "/assets/greeting.txt");
  EXPECT_EQ(loader_->getCustomKey("Greeting", "url").value_or(""), "https://example.com");
  EXPECT_FALSE(loader_->getCustomKey("Greeting", "missing").has_value());
}

TEST_F(CustomStringsLoaderTest, LoadFailsWhenAssetDoesNotExist) {
  assetManager_->setMockExists(false);
  auto res = loader_->load();
  EXPECT_FALSE(res.hasValue());
  EXPECT_EQ(res.error().code, JsonErrorCode::FileNotFound);
}
