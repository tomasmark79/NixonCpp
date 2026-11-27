#include <Utils/Platform/PlatformInfoFactory.hpp>
#include <Utils/UtilsFactory.hpp>
#include <filesystem>
#include <gtest/gtest.h>

using namespace nixoncpp::utils;
using namespace nixoncpp::logging;

TEST(PlatformAndFactoryTest, CurrentPlatformDetectionAndExecutablePath) {
  auto platform = PlatformInfoFactory::createForCurrentPlatform();
  ASSERT_NE(platform, nullptr);
  EXPECT_FALSE(platform->getPlatformName().empty());

#ifdef __linux__
  EXPECT_EQ(platform->getPlatform(), Platform::Linux);
  EXPECT_TRUE(platform->isLinux());
  EXPECT_FALSE(platform->isWindows());
  EXPECT_FALSE(platform->isMacOS());
  EXPECT_FALSE(platform->isEmscripten());
#endif

  auto exePath = platform->getExecutablePath();
  ASSERT_TRUE(exePath.hasValue());
  EXPECT_TRUE(std::filesystem::exists(exePath.value()));

  auto exeDir = platform->getExecutableDirectory();
  ASSERT_TRUE(exeDir.hasValue());
  EXPECT_EQ(exeDir.value(), exePath.value().parent_path());
}

TEST(PlatformAndFactoryTest, ExplicitPlatformCreation) {
  auto win = PlatformInfoFactory::create(Platform::Windows);
  ASSERT_NE(win, nullptr);
  EXPECT_EQ(win->getPlatform(), Platform::Windows);
  EXPECT_TRUE(win->isWindows());

  auto ems = PlatformInfoFactory::create(Platform::Emscripten);
  ASSERT_NE(ems, nullptr);
  EXPECT_EQ(ems->getPlatform(), Platform::Emscripten);
  EXPECT_TRUE(ems->isEmscripten());
}

TEST(PlatformAndFactoryTest, UtilsFactoryCreatesContexts) {
  auto basic = UtilsFactory::createBasicContext();
  EXPECT_NE(basic.logger, nullptr);
  EXPECT_NE(basic.platformInfo, nullptr);
  EXPECT_NE(basic.fileReader, nullptr);
  EXPECT_NE(basic.fileWriter, nullptr);
  EXPECT_NE(basic.pathResolver, nullptr);
  EXPECT_NE(basic.directoryManager, nullptr);
  EXPECT_NE(basic.jsonSerializer, nullptr);
  EXPECT_NE(basic.stringFormatter, nullptr);
  EXPECT_EQ(basic.assetManager, nullptr);
  EXPECT_EQ(basic.customStringsLoader, nullptr);

  LoggerConfig cfg{.level = Level::LOG_WARNING,
                   .enableFileLogging = false,
                   .logFilePath = "",
                   .colorOutput = false,
                   .appPrefix = "TestApp"};
  auto core = UtilsFactory::createCoreContext(cfg);
  ASSERT_NE(core.logger, nullptr);
  EXPECT_EQ(core.logger->getLevel(), Level::LOG_WARNING);
  EXPECT_EQ(core.logger->getAppPrefix(), "TestApp");

  auto full = UtilsFactory::createFullContext("NixonCpp", cfg);
  EXPECT_NE(full.assetManager, nullptr);
  EXPECT_NE(full.customStringsLoader, nullptr);
}
