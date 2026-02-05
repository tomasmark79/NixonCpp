#pragma once

#include <Utils/UtilsFactory.hpp>

#include <memory>

namespace nixoncpp::v1 {
  using namespace nixoncpp::utils;
  class NixonCppLib {

  public:
    NixonCppLib(const UtilsFactory::ApplicationContext &context);
    ~NixonCppLib();
    NixonCppLib(const NixonCppLib &other) = delete;
    NixonCppLib &operator=(const NixonCppLib &other) = delete;
    NixonCppLib(NixonCppLib &&other) = delete;
    NixonCppLib &operator=(NixonCppLib &&other) = delete;

    [[nodiscard]] bool isInitialized() const noexcept;
    [[nodiscard]]
    const std::shared_ptr<nixoncpp::assets::IAssetManager> &getAssetManager() const noexcept;

  private:
    bool isInitialized_{false};
    static constexpr const char *libName_ = "NixonCppLib v1.0.0";

    std::shared_ptr<nixoncpp::logging::ILogger> logger_;
    std::shared_ptr<nixoncpp::assets::IAssetManager> assetManager_;
  };

} // namespace nixoncpp::v1
