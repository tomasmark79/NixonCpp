#include <NixonCppLib/NixonCppLib.hpp>

namespace nixoncpp::v1 {

  /**
   * @brief Constructs a NixonCppLib instance from the given application context.
   *
   * Initializes the library by setting up the logger and asset manager from the
   * provided application context. If no logger is supplied in the context, a
   * NullLogger is used as a fallback. The constructor validates the asset manager
   * and sets the initialization flag accordingly.
   *
   * @param context The application context containing the logger and asset manager
   *                dependencies required for library initialization.
   *
   * @note If the asset manager is null or fails validation, an error is logged
   *       and the library remains uninitialized (isInitialized_ will be false).
   */

  NixonCppLib::NixonCppLib(const UtilsFactory::ApplicationContext &context)
      : logger_(context.logger ? context.logger
                               : std::make_shared<nixoncpp::logging::NullLogger>()),
        assetManager_(context.assetManager) {

    if (!assetManager_ || !assetManager_->validate()) {
      logger_->errorStream() << "Invalid or missing asset manager";
      return;
    }
    logger_->infoStream() << libName_ << " initialized ...";
    isInitialized_ = true;
  }

  NixonCppLib::~NixonCppLib() {
    if (isInitialized_) {
      logger_->infoStream() << libName_ << " ... destructed";
    } else {
      logger_->infoStream() << libName_ << " ... (not initialized) destructed";
    }
  }

  bool NixonCppLib::isInitialized() const noexcept { return isInitialized_; }

  const std::shared_ptr<nixoncpp::assets::IAssetManager> &
      NixonCppLib::getAssetManager() const noexcept {
    return assetManager_;
  }

  // Example method to demonstrate library functionality
  void NixonCppLib::performLibraryTask() {
    if (!isInitialized_) {
      logger_->errorStream() << "Cannot perform task: " << libName_ << " is not initialized";
      return;
    }
    logger_->infoStream() << "Performing a task in " << libName_ << " using the asset manager";

    // Example usage of the asset manager
    const char *assetName = "NixonCppLogo.svg";
    auto asset = assetManager_->getAssetsPath() / assetName;
    if (std::filesystem::exists(asset)) {
      logger_->infoStream() << "Successfully loaded asset: " << assetName;
    } else {
      logger_->errorStream() << "Failed to load asset: " << assetName;
    }
  }
} // namespace nixoncpp::v1
