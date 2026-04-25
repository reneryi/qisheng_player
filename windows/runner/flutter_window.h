#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <shobjidl.h>

#include <memory>
#include <string>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  enum class TransportIconType {
    Previous,
    Play,
    Pause,
    Next,
  };

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
 LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  static constexpr UINT kTrayIconId = 1;
  static constexpr UINT kTrayCallbackMessage = WM_APP + 101;
  static constexpr UINT kRefreshThumbButtonsMessage = WM_APP + 102;

  static constexpr UINT kCommandRestore = 20001;
  static constexpr UINT kCommandExit = 20002;
  static constexpr UINT kCommandPrevious = 20003;
  static constexpr UINT kCommandPlayPause = 20004;
  static constexpr UINT kCommandNext = 20005;

  static constexpr UINT kThumbButtonPrevious = 20101;
  static constexpr UINT kThumbButtonPlayPause = 20102;
  static constexpr UINT kThumbButtonNext = 20103;

  void AddTrayIcon();
  void RemoveTrayIcon();
  void MinimizeToTray();
  void RestoreFromTray();
  void ExitApplication();
  void ShowTrayMenu();
  void TerminateDesktopLyricProcesses() const;
  HWND FindDesktopLyricWindowByPid(DWORD pid) const;
  HWND FindDesktopLyricWindowFromArgs(
      const flutter::EncodableValue* arguments) const;
  static int GetIntArg(const flutter::EncodableMap* map, const char* key,
                       int default_value);
  static std::string GetStringArg(const flutter::EncodableMap* map,
                                  const char* key,
                                  const std::string& default_value);
  std::string SetWindowBackdropMode(const std::string& requested_mode);
  void SetupTaskbarButtons();
  HICON CreateTransportIcon(TransportIconType type) const;
  bool HandlePlaybackCommand(UINT command_id);
  void InvokePlaybackAction(const std::string& method_name) const;
  void SendMediaKey(WORD vk) const;

  // The project to run.
  flutter::DartProject project_;
  UINT taskbar_button_created_message_ = 0;
  UINT activate_window_message_ = 0;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      media_control_channel_;

  bool tray_icon_added_ = false;
  bool allow_close_ = false;
  bool is_playing_ = false;
  bool thumb_buttons_added_ = false;
  bool was_maximized_before_tray_ = false;
  NOTIFYICONDATA tray_icon_data_ = {};
  ITaskbarList3* taskbar_list_ = nullptr;
  HICON icon_prev_ = nullptr;
  HICON icon_play_ = nullptr;
  HICON icon_pause_ = nullptr;
  HICON icon_next_ = nullptr;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
