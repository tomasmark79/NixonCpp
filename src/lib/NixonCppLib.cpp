#include <NixonCppLib/NixonCppLib.hpp>

namespace nixoncpp::v1 {

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

} // namespace nixoncpp::v1
