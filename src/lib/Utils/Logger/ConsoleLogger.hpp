#pragma once

#include "ILogger.hpp"

#include <chrono>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <utility>

#ifdef _WIN32
#include <Utils/Platform/WindowsHeaders.hpp>
#include <io.h>
#define isatty _isatty
#define fileno _fileno
#else
#include <unistd.h>
#endif

namespace nixoncpp::logging {

  class ConsoleLogger : public ILogger {
  private:
    mutable std::mutex logMutex_;
    std::ofstream logFile_;
    bool addNewLine_ = true;
    std::string appPrefix_;

#ifdef DEBUG
    Level currentLevel_ = Level::LOG_DEBUG;
#else
    Level currentLevel_ = Level::LOG_INFO;
#endif

    bool colorEnabled_ = true;    // User can override
    bool autoDetectColor_ = true; // Auto-detect TTY support

    std::string headerName_ = "NixonCppLib";
    bool includeName_ = true;
    bool includeTime_ = true;
    bool includeCaller_ = true;
    bool includeLevel_ = true;

    ConsoleLogger(ConsoleLogger &&other, const std::lock_guard<std::mutex> & /*lock*/) noexcept
        : logFile_(std::move(other.logFile_)), addNewLine_(other.addNewLine_),
          appPrefix_(std::move(other.appPrefix_)), currentLevel_(other.currentLevel_),
          colorEnabled_(other.colorEnabled_), autoDetectColor_(other.autoDetectColor_),
          headerName_(std::move(other.headerName_)), includeName_(other.includeName_),
          includeTime_(other.includeTime_), includeCaller_(other.includeCaller_),
          includeLevel_(other.includeLevel_) {}

  public:
    ConsoleLogger() = default;
    ~ConsoleLogger() override {
      std::lock_guard<std::mutex> lock(logMutex_);
      if (logFile_.is_open()) {
        logFile_.close();
      }
    }

    ConsoleLogger(const ConsoleLogger &) = delete;
    ConsoleLogger &operator=(const ConsoleLogger &) = delete;

    ConsoleLogger(ConsoleLogger &&other) noexcept
        : ConsoleLogger(std::move(other), std::lock_guard<std::mutex>(other.logMutex_)) {}

    ConsoleLogger &operator=(ConsoleLogger &&other) noexcept {
      if (this != &other) {
        std::scoped_lock lock(logMutex_, other.logMutex_);

        logFile_ = std::move(other.logFile_);
        addNewLine_ = other.addNewLine_;
        appPrefix_ = std::move(other.appPrefix_);
        currentLevel_ = other.currentLevel_;
        colorEnabled_ = other.colorEnabled_;
        autoDetectColor_ = other.autoDetectColor_;
        headerName_ = std::move(other.headerName_);
        includeName_ = other.includeName_;
        includeTime_ = other.includeTime_;
        includeCaller_ = other.includeCaller_;
        includeLevel_ = other.includeLevel_;
      }
      return *this;
    }

    void debug(const std::string &message, const std::string &caller = "") override {
      log(Level::LOG_DEBUG, message, caller);
    }

    void info(const std::string &message, const std::string &caller = "") override {
      log(Level::LOG_INFO, message, caller);
    }

    void warning(const std::string &message, const std::string &caller = "") override {
      log(Level::LOG_WARNING, message, caller);
    }

    void error(const std::string &message, const std::string &caller = "") override {
      log(Level::LOG_ERROR, message, caller);
    }

    void critical(const std::string &message, const std::string &caller = "") override {
      log(Level::LOG_CRITICAL, message, caller);
    }

    /**
     * @brief Logs a message with a specified level to the console and optionally to a file.
     *
     * Messages below the currently configured log level are ignored.
     *
     * @param level
     * @param message
     * @param caller
     */
    void log(Level level, const std::string &message, const std::string &caller) {
      std::lock_guard<std::mutex> lock(logMutex_);

      if (level < currentLevel_) {
        return;
      }

      // Get current time
      auto now = std::chrono::system_clock::now();
      std::time_t now_c = std::chrono::system_clock::to_time_t(now);
      std::tm now_tm{};

      // Windows and POSIX have different thread-safe localtime functions
#ifdef _WIN32
      localtime_s(&now_tm, &now_c);
#else
      localtime_r(&now_c, &now_tm);
#endif

      const std::string header = buildHeader(now_tm, caller, level);

      // Log to console
      if (shouldUseColors()) {
        setConsoleColor(level);
      }
      std::cout << header << message;
      if (addNewLine_) {
        std::cout << "\n";
      }

      if (shouldUseColors()) {
        resetConsoleColor();
      }

      // Log to file if enabled
      if (logFile_.is_open()) {
        logFile_ << header << message;
        if (addNewLine_) {
          logFile_ << "\n";
        }
        logFile_.flush();
      }
    }

    void setLevel(Level level) override {
      std::lock_guard<std::mutex> lock(logMutex_);
      currentLevel_ = level;
    }

    [[nodiscard]]
    Level getLevel() const override {
      std::lock_guard<std::mutex> lock(logMutex_);
      return currentLevel_;
    }

    void setAppPrefix(const std::string &prefix) override {
      std::lock_guard<std::mutex> lock(logMutex_);
      appPrefix_ = prefix;
    }

    [[nodiscard]]
    std::string getAppPrefix() const override {
      std::lock_guard<std::mutex> lock(logMutex_);
      return appPrefix_;
    }

    bool enableFileLogging(const std::string &filename) override {
      std::lock_guard<std::mutex> lock(logMutex_);
      try {
        if (logFile_.is_open()) {
          logFile_.close();
        }
        logFile_.open(filename, std::ios::out | std::ios::app);
        return logFile_.is_open();
      } catch (const std::ios_base::failure &e) {
        std::cerr << "Failed to open log file: " << filename << " - " << e.what() << "\n";
        return false;
      } catch (const std::exception &e) {
        std::cerr << "Failed to open log file: " << filename << " - " << e.what() << "\n";
        return false;
      } catch (...) {
        std::cerr << "Failed to open log file: " << filename << "\n";
        return false;
      }
    }

    void disableFileLogging() override {
      std::lock_guard<std::mutex> lock(logMutex_);
      if (logFile_.is_open()) {
        logFile_.close();
      }
    }

    /**
     * @brief Convert a logging level to its string representation
     *
     * @param level
     * @return std::string
     */
    static std::string levelToString(Level level) {
      switch (level) {
      case Level::LOG_DEBUG: return "DBG";
      case Level::LOG_INFO: return "INF";
      case Level::LOG_WARNING: return "WRN";
      case Level::LOG_ERROR: return "ERR";
      case Level::LOG_CRITICAL: return "CRI";
      default: return "INF";
      }
    }

    /**
     * @brief Reset the console color to default
     */
    static void resetConsoleColor() {
#ifdef _WIN32
      SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE),
                              FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_BLUE);
#elif defined(__EMSCRIPTEN__)
      // no colors, no reset
#else
      std::cout << "\033[0m";
#endif
    }

#ifdef _WIN32
    static void setConsoleColorWindows(Level level) {
      const std::map<Level, WORD> colorMap = {
          {Level::LOG_DEBUG, FOREGROUND_BLUE | FOREGROUND_GREEN | FOREGROUND_INTENSITY},
          {Level::LOG_INFO, FOREGROUND_GREEN | FOREGROUND_INTENSITY},
          {Level::LOG_WARNING, FOREGROUND_RED | FOREGROUND_GREEN | FOREGROUND_INTENSITY},
          {Level::LOG_ERROR, FOREGROUND_RED | FOREGROUND_INTENSITY},
          { Level::LOG_CRITICAL,
            FOREGROUND_RED | FOREGROUND_INTENSITY | FOREGROUND_BLUE }};
      auto it = colorMap.find(level);
      if (it != colorMap.end()) {
        SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), it->second);
      } else {
        resetConsoleColor();
      }
    }
#else
    static void setConsoleColorUnix(Level level) {
      static const std::map<Level, const char *> colorMap = {{Level::LOG_DEBUG, "\033[34m"},
                                                             {Level::LOG_INFO, "\033[32m"},
                                                             {Level::LOG_WARNING, "\033[33m"},
                                                             {Level::LOG_ERROR, "\033[31m"},
                                                             {Level::LOG_CRITICAL, "\033[95m"}};
      auto it = colorMap.find(level);
      if (it != colorMap.end()) {
        std::cout << it->second;
      } else {
        resetConsoleColor();
      }
    }
#endif

    static void setConsoleColor(Level level) {
#ifdef _WIN32
      setConsoleColorWindows(level);
#elif defined(__EMSCRIPTEN__)
      (void)level; // no colors
#else
      setConsoleColorUnix(level);
#endif
    }

    void setHeaderName(const std::string &headerName) {
      std::lock_guard<std::mutex> lock(logMutex_);
      headerName_ = headerName;
    }

    void showHeaderName(bool includeName) {
      std::lock_guard<std::mutex> lock(logMutex_);
      includeName_ = includeName;
    }

    void showHeaderTime(bool includeTime) {
      std::lock_guard<std::mutex> lock(logMutex_);
      includeTime_ = includeTime;
    }

    void showHeaderCaller(bool includeCaller) {
      std::lock_guard<std::mutex> lock(logMutex_);
      includeCaller_ = includeCaller;
    }

    void showHeaderLevel(bool includeLevel) {
      std::lock_guard<std::mutex> lock(logMutex_);
      includeLevel_ = includeLevel;
    }

    void noHeader(bool noHeader) {
      std::lock_guard<std::mutex> lock(logMutex_);
      const bool visible = !noHeader;
      includeName_ = visible;
      includeTime_ = visible;
      includeCaller_ = visible;
      includeLevel_ = visible;
    }

    void visibleHeaders(bool incName, bool incTime, bool incCaller, bool incLevel) {
      std::lock_guard<std::mutex> lock(logMutex_);
      includeName_ = incName;
      includeTime_ = incTime;
      includeCaller_ = incCaller;
      includeLevel_ = incLevel;
    }

    void setColorEnabled(bool enabled) {
      std::lock_guard<std::mutex> lock(logMutex_);
      colorEnabled_ = enabled;
      autoDetectColor_ = false; // Manual override disables auto-detection
    }

    void setAutoDetectColor(bool autoDetect) {
      std::lock_guard<std::mutex> lock(logMutex_);
      autoDetectColor_ = autoDetect;
    }

    [[nodiscard]]
    bool isColorEnabled() const {
      std::lock_guard<std::mutex> lock(logMutex_);
      return shouldUseColors();
    }

  private:
    [[nodiscard]]
    std::string buildHeader(const std::tm &now_tm, const std::string &caller, Level level) const {
      std::ostringstream header;
      if (includeName_) {
        const std::string &prefix = !appPrefix_.empty() ? appPrefix_ : headerName_;
        if (!prefix.empty()) {
          header << "[" << prefix << "]";
        }
      }
      if (includeTime_) {
        header << "[" << std::put_time(&now_tm, "%Y-%m-%d %H:%M:%S") << "]";
      }
      if (includeLevel_) {
        header << "[" << levelToString(level) << "]";
      }
      if (includeCaller_ && !caller.empty()) {
        header << "[" << caller << "]";
      }
      if (header.tellp() > 0) {
        header << " ";
      }
      return header.str();
    }

    [[nodiscard]]
    bool shouldUseColors() const {
      if (!autoDetectColor_) {
        return colorEnabled_;
      }
#ifdef __EMSCRIPTEN__
      return false; // No color support in Emscripten
#else
      return colorEnabled_ && (isatty(fileno(stdout)) != 0);
#endif
    }
  };

} // namespace nixoncpp::logging
