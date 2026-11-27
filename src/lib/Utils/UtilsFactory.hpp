#pragma once

#include "Assets/IAssetManager.hpp"
#include "Filesystem/IDirectoryManager.hpp"
#include "Filesystem/IFileReader.hpp"
#include "Filesystem/IFileWriter.hpp"
#include "Filesystem/IPathResolver.hpp"
#include "Logger/ILogger.hpp"
#include "Logger/LoggerFactory.hpp"
#include "Logger/NullLogger.hpp"
#include "Platform/IPlatformInfo.hpp"
#include "String/IStringFormatter.hpp"
#include "Json/ICustomStringsLoader.hpp"
#include "Json/IJsonSerializer.hpp"
#include <filesystem>
#include <memory>

namespace nixoncpp::utils {

  // Import types from other namespaces
  using nixoncpp::assets::IAssetManager;
  using nixoncpp::logging::ILogger;
  using nixoncpp::logging::LoggerConfig;
  using nixoncpp::logging::LoggerType;

  class UtilsFactory {
  public:
    [[nodiscard]]
    static std::shared_ptr<IFileReader> createFileReader();
    [[nodiscard]]
    static std::shared_ptr<IFileWriter> createFileWriter();
    [[nodiscard]]
    static std::shared_ptr<IPathResolver> createPathResolver();
    [[nodiscard]]
    static std::shared_ptr<IDirectoryManager> createDirectoryManager();
    [[nodiscard]]
    static std::unique_ptr<IPlatformInfo> createPlatformInfo();
    [[nodiscard]]
    static std::unique_ptr<IPlatformInfo> createPlatformInfo(Platform platform);
    [[nodiscard]]
    static std::shared_ptr<IAssetManager>
        createAssetManager(const std::filesystem::path &executablePath, const std::string &appName);
    [[nodiscard]]
    static std::shared_ptr<IJsonSerializer> createJsonSerializer();
    [[nodiscard]]
    static std::shared_ptr<ICustomStringsLoader>
        createCustomStringsLoader(const std::filesystem::path &executablePath,
                                  const std::string &appName);
    [[nodiscard]]
    static std::shared_ptr<IStringFormatter> createStringFormatter();
    [[nodiscard]]
    static std::shared_ptr<ILogger> createLogger(LoggerType type, const LoggerConfig &config);
    [[nodiscard]]
    static std::shared_ptr<ILogger> createDefaultLogger();

    // Unified application context
    struct ApplicationContext {

      // System components
      std::shared_ptr<ILogger> logger;
      std::unique_ptr<IPlatformInfo> platformInfo;

      // File system utilities
      std::shared_ptr<IFileReader> fileReader;
      std::shared_ptr<IFileWriter> fileWriter;
      std::shared_ptr<IPathResolver> pathResolver;
      std::shared_ptr<IDirectoryManager> directoryManager;

      // Serialization & formatting
      std::shared_ptr<IJsonSerializer> jsonSerializer;
      std::shared_ptr<IStringFormatter> stringFormatter;

      // Application-specific (nullable for flexibility)
      std::shared_ptr<IAssetManager> assetManager;
      std::shared_ptr<ICustomStringsLoader> customStringsLoader;
    };

    /**
     * @brief Create full application context with all components
     * @param appName Application name for asset resolution
     * @param loggerConfig Logger configuration
     * @return Complete ApplicationContext with all utilities initialized
     */
    [[nodiscard]]
    static ApplicationContext createFullContext(const std::string &appName,
                                                const LoggerConfig &loggerConfig);

    /**
     * @brief Create minimal context without app-specific components
     * @param loggerConfig Logger configuration
     * @return ApplicationContext with core utilities only (no assetManager/customStringsLoader)
     */
    [[nodiscard]]
    static ApplicationContext createCoreContext(const LoggerConfig &loggerConfig);

    /**
     * @brief Create basic utilities context with default logger
     * @return ApplicationContext with basic utilities and default logger
     */
    [[nodiscard]]
    static ApplicationContext createBasicContext();
  };

} // namespace nixoncpp::utils
