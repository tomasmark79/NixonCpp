#pragma once

#include <Utils/UtilsFactory.hpp>

#include <memory>

#ifndef PROJECT_VERSION
#define PROJECT_VERSION "0.0.1"
#endif

namespace nixoncpp::v1 {
  class NixonCppLib {

  public:
    explicit NixonCppLib(const nixoncpp::utils::UtilsFactory::ApplicationContext &context);
    ~NixonCppLib();
    NixonCppLib(const NixonCppLib &other) = delete;
    NixonCppLib &operator=(const NixonCppLib &other) = delete;
    NixonCppLib(NixonCppLib &&other) = delete;
    NixonCppLib &operator=(NixonCppLib &&other) = delete;

    [[nodiscard]] bool isInitialized() const noexcept;
    [[nodiscard]]
    const std::shared_ptr<nixoncpp::assets::IAssetManager> &getAssetManager() const noexcept;
    void performLibraryTask();

  private:
    bool isInitialized_{false};
    static constexpr const char *libName_ = "NixonCppLib v" PROJECT_VERSION;

    std::shared_ptr<nixoncpp::logging::ILogger> logger_;
    std::shared_ptr<nixoncpp::assets::IAssetManager> assetManager_;
  };

} // namespace nixoncpp::v1
