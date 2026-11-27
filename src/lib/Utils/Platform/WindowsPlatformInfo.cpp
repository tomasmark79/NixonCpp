#include "WindowsPlatformInfo.hpp"

#ifdef _WIN32
#include <Utils/Platform/WindowsHeaders.hpp>
#include <vector>
#endif

namespace nixoncpp::utils {

  Platform WindowsPlatformInfo::getPlatform() const { return Platform::Windows; }

  std::string WindowsPlatformInfo::getPlatformName() const { return "Windows"; }

  Result<std::filesystem::path, FileError> WindowsPlatformInfo::getExecutablePath() const {
#ifdef _WIN32
    constexpr DWORD kInitialBufferSize = MAX_PATH;
    constexpr DWORD kMaxBufferSize = 32768;
    std::vector<wchar_t> buffer(kInitialBufferSize);

    while (true) {
      DWORD len = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
      if (len == 0) {
        return FileError{
            .code = FileErrorCode::ReadError,
            .message = "Failed to get executable path on Windows",
            .path = "",
        };
      }
      if (len < buffer.size()) {
        return std::filesystem::path(std::wstring(buffer.data(), len));
      }
      if (buffer.size() >= kMaxBufferSize) {
        return FileError{
            .code = FileErrorCode::ReadError,
            .message = "Executable path exceeds maximum supported length on Windows",
            .path = "",
        };
      }
      buffer.resize(buffer.size() * 2);
    }
#else
    return FileError{
        .code = FileErrorCode::Unknown,
        .message = "WindowsPlatformInfo used on non-Windows platform",
        .path = "",
    };
#endif
  }

  Result<std::filesystem::path, FileError> WindowsPlatformInfo::getExecutableDirectory() const {
    auto exePathResult = getExecutablePath();
    if (!exePathResult) {
      return exePathResult.error();
    }

    return exePathResult.value().parent_path();
  }

  bool WindowsPlatformInfo::isWindows() const { return true; }

  bool WindowsPlatformInfo::isLinux() const { return false; }

  bool WindowsPlatformInfo::isMacOS() const { return false; }

  bool WindowsPlatformInfo::isEmscripten() const { return false; }

} // namespace nixoncpp::utils
