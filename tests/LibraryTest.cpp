#include "MockAssetManager.hpp"
#include <NixonCppLib/NixonCppLib.hpp>
#include <Utils/Logger/NullLogger.hpp>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <gtest/gtest.h>
#include <memory>

using namespace nixoncpp::v1;
using namespace nixoncpp::utils;
using namespace nixoncpp::logging;

class LibraryTest : public ::testing::Test {
protected:
  void SetUp() override {
    const auto *testInfo = ::testing::UnitTest::GetInstance()->current_test_info();
    const auto stamp = std::chrono::steady_clock::now().time_since_epoch().count();
    tempDir_ = std::filesystem::temp_directory_path() /
               (std::string("LibraryTest_") + (testInfo != nullptr ? testInfo->name() : "unknown") +
                "_" + std::to_string(stamp));
    std::filesystem::create_directories(tempDir_);
  }

  void TearDown() override {
    std::error_code ec;
    std::filesystem::remove_all(tempDir_, ec);
  }

  std::filesystem::path tempDir_;
};

TEST_F(LibraryTest, InitializesWithValidAssetManager) {
  auto mockAssets = std::make_shared<MockAssetManager>(tempDir_);
  UtilsFactory::ApplicationContext ctx{};
  ctx.logger = std::make_shared<NullLogger>();
  ctx.assetManager = mockAssets;

  NixonCppLib lib(ctx);
  EXPECT_TRUE(lib.isInitialized());
  EXPECT_EQ(lib.getAssetManager(), mockAssets);
}

TEST_F(LibraryTest, FallsBackToNullLoggerWhenLoggerMissing) {
  auto mockAssets = std::make_shared<MockAssetManager>(tempDir_);
  UtilsFactory::ApplicationContext ctx{};
  ctx.logger = nullptr;
  ctx.assetManager = mockAssets;

  NixonCppLib lib(ctx);
  EXPECT_TRUE(lib.isInitialized());
  EXPECT_NO_THROW(lib.performLibraryTask());
}

TEST_F(LibraryTest, FailsInitializationWhenAssetManagerNull) {
  UtilsFactory::ApplicationContext ctx{};
  ctx.logger = std::make_shared<NullLogger>();
  ctx.assetManager = nullptr;

  NixonCppLib lib(ctx);
  EXPECT_FALSE(lib.isInitialized());
  EXPECT_NO_THROW(lib.performLibraryTask());
}

TEST_F(LibraryTest, FailsInitializationWhenAssetManagerInvalid) {
  auto mockAssets = std::make_shared<MockAssetManager>(tempDir_);
  mockAssets->setMockValid(false);

  UtilsFactory::ApplicationContext ctx{};
  ctx.logger = std::make_shared<NullLogger>();
  ctx.assetManager = mockAssets;

  NixonCppLib lib(ctx);
  EXPECT_FALSE(lib.isInitialized());
}

TEST_F(LibraryTest, PerformLibraryTaskWithExistingLogoAsset) {
  std::ofstream(tempDir_ / "NixonCppLogo.svg") << "<svg></svg>";
  auto mockAssets = std::make_shared<MockAssetManager>(tempDir_);

  UtilsFactory::ApplicationContext ctx{};
  ctx.logger = std::make_shared<NullLogger>();
  ctx.assetManager = mockAssets;

  NixonCppLib lib(ctx);
  ASSERT_TRUE(lib.isInitialized());
  EXPECT_NO_THROW(lib.performLibraryTask());
}
