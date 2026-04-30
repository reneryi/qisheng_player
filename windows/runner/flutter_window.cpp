#include "flutter_window.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdint>
#include <cwchar>
#include <cwctype>
#include <sstream>
#include <commctrl.h>
#include <dwmapi.h>
#include <tlhelp32.h>
#include <optional>

#include "../flutter/generated_plugin_registrant.h"
#include "resource.h"

#ifndef NIN_SELECT
#define NIN_SELECT (WM_USER + 0)
#endif

namespace {
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMSBT_AUTO
#define DWMSBT_AUTO 0
#define DWMSBT_NONE 1
#define DWMSBT_MAINWINDOW 2
#define DWMSBT_TRANSIENTWINDOW 3
#define DWMSBT_TABBEDWINDOW 4
#endif

#ifndef DWMWCP_DEFAULT
#define DWMWCP_DEFAULT 0
#define DWMWCP_DONOTROUND 1
#define DWMWCP_ROUND 2
#define DWMWCP_ROUNDSMALL 3
#endif

struct WindowSearchData {
  DWORD process_id = 0;
  HWND preferred_hwnd = nullptr;
  HWND fallback_hwnd = nullptr;
};

bool IsValidDesktopLyricTopWindow(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }

  if (GetWindow(hwnd, GW_OWNER) != nullptr) {
    return false;
  }
  if (!IsWindowVisible(hwnd)) {
    return false;
  }
  if (IsIconic(hwnd)) {
    return false;
  }
  return true;
}

bool HasDesktopLyricTitle(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }

  wchar_t title[256] = {};
  const int length = GetWindowTextW(hwnd, title, std::size(title));
  if (length <= 0) {
    return false;
  }
  return wcscmp(title, L"desktop_lyric") == 0;
}

std::wstring Utf8ToWide(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }

  const int size =
      MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr, 0);
  if (size <= 1) {
    return std::wstring();
  }

  std::wstring wide(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, wide.data(), size);
  wide.resize(static_cast<size_t>(size - 1));
  return wide;
}

std::wstring NormalizeWindowsPath(std::wstring value) {
  std::replace(value.begin(), value.end(), L'/', L'\\');
  std::transform(value.begin(), value.end(), value.begin(), [](wchar_t ch) {
    return static_cast<wchar_t>(std::towlower(ch));
  });
  return value;
}

std::optional<std::wstring> GetProcessImagePath(HANDLE process) {
  if (process == nullptr) {
    return std::nullopt;
  }

  std::wstring buffer(MAX_PATH, L'\0');
  DWORD size = static_cast<DWORD>(buffer.size());
  while (!QueryFullProcessImageNameW(process, 0, buffer.data(), &size)) {
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      return std::nullopt;
    }
    buffer.resize(buffer.size() * 2, L'\0');
    size = static_cast<DWORD>(buffer.size());
  }

  buffer.resize(size);
  return buffer;
}

bool WasWindowMaximized(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }

  WINDOWPLACEMENT placement = {};
  placement.length = sizeof(WINDOWPLACEMENT);
  if (GetWindowPlacement(hwnd, &placement) != FALSE) {
    if (placement.showCmd == SW_SHOWMAXIMIZED) {
      return true;
    }
  }
  return IsZoomed(hwnd) != FALSE;
}

bool CanNativeResize(HWND hwnd) {
  if (hwnd == nullptr || IsZoomed(hwnd) != FALSE || IsIconic(hwnd) != FALSE) {
    return false;
  }
  const auto style = GetWindowLongPtr(hwnd, GWL_STYLE);
  return (style & WS_THICKFRAME) != 0;
}

int NativeResizeBorderThickness(HWND hwnd) {
  UINT dpi = USER_DEFAULT_SCREEN_DPI;
  if (hwnd != nullptr) {
    dpi = GetDpiForWindow(hwnd);
    if (dpi == 0) {
      dpi = USER_DEFAULT_SCREEN_DPI;
    }
  }
  return std::max(1, MulDiv(8, static_cast<int>(dpi), USER_DEFAULT_SCREEN_DPI));
}

LRESULT NativeWindowHitTest(HWND hwnd, LPARAM lparam) {
  if (!CanNativeResize(hwnd)) {
    return HTCLIENT;
  }

  RECT rect = {};
  if (GetWindowRect(hwnd, &rect) == FALSE) {
    return HTCLIENT;
  }

  const POINT cursor = {
      static_cast<LONG>(static_cast<short>(LOWORD(lparam))),
      static_cast<LONG>(static_cast<short>(HIWORD(lparam))),
  };
  const int border = NativeResizeBorderThickness(hwnd);
  const bool on_left = cursor.x >= rect.left && cursor.x < rect.left + border;
  const bool on_right = cursor.x < rect.right && cursor.x >= rect.right - border;
  const bool on_top = cursor.y >= rect.top && cursor.y < rect.top + border;
  const bool on_bottom = cursor.y < rect.bottom && cursor.y >= rect.bottom - border;

  if (on_top && on_left) {
    return HTTOPLEFT;
  }
  if (on_top && on_right) {
    return HTTOPRIGHT;
  }
  if (on_bottom && on_left) {
    return HTBOTTOMLEFT;
  }
  if (on_bottom && on_right) {
    return HTBOTTOMRIGHT;
  }
  if (on_left) {
    return HTLEFT;
  }
  if (on_right) {
    return HTRIGHT;
  }
  if (on_top) {
    return HTTOP;
  }
  if (on_bottom) {
    return HTBOTTOM;
  }
  return HTCLIENT;
}

LPCTSTR CursorForHitTest(WORD hit_test) {
  switch (hit_test) {
    case HTLEFT:
    case HTRIGHT:
      return IDC_SIZEWE;
    case HTTOP:
    case HTBOTTOM:
      return IDC_SIZENS;
    case HTTOPLEFT:
    case HTBOTTOMRIGHT:
      return IDC_SIZENWSE;
    case HTTOPRIGHT:
    case HTBOTTOMLEFT:
      return IDC_SIZENESW;
    default:
      return IDC_ARROW;
  }
}

bool IsResizeHitTest(WORD hit_test) {
  switch (hit_test) {
    case HTLEFT:
    case HTRIGHT:
    case HTTOP:
    case HTBOTTOM:
    case HTTOPLEFT:
    case HTTOPRIGHT:
    case HTBOTTOMLEFT:
    case HTBOTTOMRIGHT:
      return true;
    default:
      return false;
  }
}

bool IsEffectivelyFullscreen(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }

  RECT window_rect = {};
  if (GetWindowRect(hwnd, &window_rect) == FALSE) {
    return false;
  }

  MONITORINFO monitor_info = {};
  monitor_info.cbSize = sizeof(MONITORINFO);
  const HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  if (monitor == nullptr ||
      GetMonitorInfo(monitor, &monitor_info) == FALSE) {
    return false;
  }

  const RECT monitor_rect = monitor_info.rcMonitor;
  return std::abs(window_rect.left - monitor_rect.left) <= 1 &&
         std::abs(window_rect.top - monitor_rect.top) <= 1 &&
         std::abs(window_rect.right - monitor_rect.right) <= 1 &&
         std::abs(window_rect.bottom - monitor_rect.bottom) <= 1;
}

bool ShouldRoundMainWindow(HWND hwnd) {
  return hwnd != nullptr &&
         IsIconic(hwnd) == FALSE &&
         IsZoomed(hwnd) == FALSE &&
         !IsEffectivelyFullscreen(hwnd);
}

int WindowCornerRadiusPx(HWND hwnd) {
  UINT dpi = USER_DEFAULT_SCREEN_DPI;
  if (hwnd != nullptr) {
    dpi = GetDpiForWindow(hwnd);
    if (dpi == 0) {
      dpi = USER_DEFAULT_SCREEN_DPI;
    }
  }
  return std::max(12, MulDiv(18, static_cast<int>(dpi), USER_DEFAULT_SCREEN_DPI));
}

bool HandleNativeSetCursor(HWND hwnd, WPARAM wparam, LPARAM lparam) {
  const auto target = reinterpret_cast<HWND>(wparam);
  if (target != hwnd) {
    return false;
  }

  const WORD hit_test = LOWORD(lparam);
  if (IsResizeHitTest(hit_test) || hit_test == HTCLIENT ||
      hit_test == HTERROR || hit_test == HTNOWHERE) {
    SetCursor(LoadCursor(nullptr, CursorForHitTest(hit_test)));
    return true;
  }
  return false;
}

bool StartCaptionDragWithoutSystemFeedback(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }

  if ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) == 0) {
    return false;
  }

  POINT cursor = {};
  if (GetCursorPos(&cursor) == FALSE) {
    return false;
  }

  ReleaseCapture();
  return PostMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION,
                     MAKELPARAM(cursor.x, cursor.y)) != FALSE;
}

std::optional<LONG> ResizeEdgeHitTestFromName(const std::string& resize_edge) {
  if (resize_edge == "top") {
    return HTTOP;
  }
  if (resize_edge == "bottom") {
    return HTBOTTOM;
  }
  if (resize_edge == "left") {
    return HTLEFT;
  }
  if (resize_edge == "right") {
    return HTRIGHT;
  }
  if (resize_edge == "topLeft") {
    return HTTOPLEFT;
  }
  if (resize_edge == "topRight") {
    return HTTOPRIGHT;
  }
  if (resize_edge == "bottomLeft") {
    return HTBOTTOMLEFT;
  }
  if (resize_edge == "bottomRight") {
    return HTBOTTOMRIGHT;
  }
  return std::nullopt;
}

bool StartResizeWithoutSystemFeedback(HWND hwnd, const std::string& resize_edge) {
  if (hwnd == nullptr) {
    return false;
  }

  const auto hit_test = ResizeEdgeHitTestFromName(resize_edge);
  if (!hit_test.has_value()) {
    return false;
  }

  if ((GetAsyncKeyState(VK_LBUTTON) & 0x8000) == 0) {
    return false;
  }

  POINT cursor = {};
  if (GetCursorPos(&cursor) == FALSE) {
    return false;
  }

  ReleaseCapture();
  return PostMessage(hwnd, WM_NCLBUTTONDOWN, *hit_test,
                     MAKELPARAM(cursor.x, cursor.y)) != FALSE;
}

bool IsAltKeyMessage(WPARAM wparam) {
  return wparam == VK_MENU || wparam == VK_LMENU || wparam == VK_RMENU;
}

BOOL CALLBACK EnumDesktopLyricWindowByPidProc(HWND hwnd, LPARAM lparam) {
  auto* data = reinterpret_cast<WindowSearchData*>(lparam);
  if (data == nullptr || data->process_id == 0) {
    return FALSE;
  }

  DWORD window_process_id = 0;
  GetWindowThreadProcessId(hwnd, &window_process_id);
  if (window_process_id != data->process_id) {
    return TRUE;
  }

  if (!IsValidDesktopLyricTopWindow(hwnd)) {
    return TRUE;
  }

  if (HasDesktopLyricTitle(hwnd)) {
    data->preferred_hwnd = hwnd;
    return FALSE;
  }

  if (data->fallback_hwnd == nullptr) {
    data->fallback_hwnd = hwnd;
  }
  return TRUE;
}

struct TitleSearchData {
  HWND hwnd = nullptr;
};

struct BackdropSupportInfo {
  bool native_supported = false;
  bool mica_supported = false;
  bool acrylic_supported = false;
  std::string auto_mode = "none";
  std::string fallback_reason = "unsupported_platform";
};

struct BackdropResolution {
  std::string requested_mode = "auto";
  std::string applied_mode = "none";
  bool native_backdrop_supported = false;
  bool native_apply_succeeded = false;
  std::string fallback_reason = "";
  int backdrop_type = DWMSBT_NONE;
};

BOOL CALLBACK EnumDesktopLyricWindowByTitleProc(HWND hwnd, LPARAM lparam) {
  auto* data = reinterpret_cast<TitleSearchData*>(lparam);
  if (data == nullptr) {
    return FALSE;
  }
  if (!IsValidDesktopLyricTopWindow(hwnd)) {
    return TRUE;
  }
  if (!HasDesktopLyricTitle(hwnd)) {
    return TRUE;
  }
  data->hwnd = hwnd;
  return FALSE;
}

HWND FindDesktopLyricWindowByTitle() {
  TitleSearchData data = {};
  EnumWindows(EnumDesktopLyricWindowByTitleProc, reinterpret_cast<LPARAM>(&data));
  return data.hwnd;
}

std::string ToLowerAscii(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char ch) {
                   return static_cast<char>(std::tolower(ch));
                 });
  return value;
}

std::string NormalizeBackdropMode(const std::string& value) {
  const std::string normalized = ToLowerAscii(value);
  if (normalized == "auto" || normalized == "mica" ||
      normalized == "acrylic" || normalized == "none") {
    return normalized;
  }
  return "auto";
}

int BackdropTypeFromMode(const std::string& mode) {
  if (mode == "mica") {
    return DWMSBT_MAINWINDOW;
  }
  if (mode == "acrylic") {
    return DWMSBT_TRANSIENTWINDOW;
  }
  if (mode == "none") {
    return DWMSBT_NONE;
  }
  return DWMSBT_AUTO;
}

std::optional<DWORD> GetWindowsBuildNumber() {
  using RtlGetVersionFn = LONG(WINAPI*)(PRTL_OSVERSIONINFOW);
  const HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
  if (ntdll == nullptr) {
    return std::nullopt;
  }
  const auto rtl_get_version = reinterpret_cast<RtlGetVersionFn>(
      GetProcAddress(ntdll, "RtlGetVersion"));
  if (rtl_get_version == nullptr) {
    return std::nullopt;
  }

  RTL_OSVERSIONINFOW version_info = {};
  version_info.dwOSVersionInfoSize = sizeof(version_info);
  if (rtl_get_version(&version_info) != 0) {
    return std::nullopt;
  }
  return version_info.dwBuildNumber;
}

BackdropSupportInfo ResolveBackdropSupportInfo() {
  const auto build_number = GetWindowsBuildNumber();
  if (!build_number.has_value()) {
    return {};
  }
  if (*build_number >= 22621) {
    return {
        true,
        true,
        true,
        "mica",
        "",
    };
  }
  if (*build_number >= 22000) {
    return {
        true,
        true,
        false,
        "mica",
        "acrylic_requires_windows_11_22h2",
    };
  }
  return {
      false,
      false,
      false,
      "none",
      "system_backdrop_requires_windows_11",
  };
}

BackdropResolution ResolveBackdropRequest(const std::string& requested_mode) {
  BackdropResolution resolution = {};
  resolution.requested_mode = NormalizeBackdropMode(requested_mode);

  const BackdropSupportInfo support = ResolveBackdropSupportInfo();
  resolution.native_backdrop_supported = support.native_supported;

  std::string target_mode = resolution.requested_mode;
  if (resolution.requested_mode == "auto") {
    target_mode = support.auto_mode;
  }

  if (target_mode == "mica" && !support.mica_supported) {
    resolution.applied_mode = "none";
    resolution.fallback_reason = support.fallback_reason.empty()
                                     ? "mica_not_supported"
                                     : support.fallback_reason;
    return resolution;
  }

  if (target_mode == "acrylic" && !support.acrylic_supported) {
    resolution.applied_mode = support.mica_supported ? "mica" : "none";
    resolution.fallback_reason = support.fallback_reason.empty()
                                     ? "acrylic_not_supported"
                                     : support.fallback_reason;
    resolution.backdrop_type = BackdropTypeFromMode(resolution.applied_mode);
    return resolution;
  }

  resolution.applied_mode = target_mode;
  resolution.backdrop_type = BackdropTypeFromMode(target_mode);
  if (!support.native_supported) {
    resolution.fallback_reason = support.fallback_reason;
  }
  return resolution;
}

flutter::EncodableMap EncodeBackdropResolution(
    const BackdropResolution& resolution) {
  flutter::EncodableMap map;
  map[flutter::EncodableValue("requestedMode")] =
      flutter::EncodableValue(resolution.requested_mode);
  map[flutter::EncodableValue("appliedMode")] =
      flutter::EncodableValue(resolution.applied_mode);
  map[flutter::EncodableValue("nativeBackdropSupported")] =
      flutter::EncodableValue(resolution.native_backdrop_supported);
  map[flutter::EncodableValue("nativeApplySucceeded")] =
      flutter::EncodableValue(resolution.native_apply_succeeded);
  map[flutter::EncodableValue("fallbackReason")] =
      flutter::EncodableValue(resolution.fallback_reason);
  return map;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {
  taskbar_button_created_message_ =
      RegisterWindowMessage(L"TaskbarButtonCreated");
  activate_window_message_ =
      RegisterWindowMessage(L"QishengPlayerActivateMainWindow");
}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  AddTrayIcon();
  media_control_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "qisheng_player/window_controls",
          &flutter::StandardMethodCodec::GetInstance());
  media_control_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& method_call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (method_call.method_name() == "set_playing") {
          bool is_playing = false;

          if (method_call.arguments() != nullptr) {
            const auto& arguments = *method_call.arguments();
            if (const auto* map =
                    std::get_if<flutter::EncodableMap>(&arguments)) {
              const auto it = map->find(flutter::EncodableValue("playing"));
              if (it != map->end()) {
                if (const auto* playing_value =
                        std::get_if<bool>(&it->second)) {
                  is_playing = *playing_value;
                }
              }
            } else if (const auto* playing_value =
                           std::get_if<bool>(&arguments)) {
              is_playing = *playing_value;
            }
          }

          is_playing_ = is_playing;
          SetupTaskbarButtons();
          result->Success();
          return;
        }

        if (method_call.method_name() == "start_dragging") {
          result->Success(flutter::EncodableValue(
              StartCaptionDragWithoutSystemFeedback(GetHandle())));
          return;
        }

        if (method_call.method_name() == "set_desktop_lyric_process") {
          const auto* map = method_call.arguments() == nullptr
                                ? nullptr
                                : std::get_if<flutter::EncodableMap>(
                                      method_call.arguments());
          const int pid = GetIntArg(map, "pid", 0);
          const auto executable_path =
              Utf8ToWide(GetStringArg(map, "executablePath", std::string()));
          SetRegisteredDesktopLyricProcess(static_cast<DWORD>(pid),
                                           executable_path);
          result->Success();
          return;
        }

        if (method_call.method_name() == "start_resizing") {
          const auto* map = method_call.arguments() == nullptr
                                ? nullptr
                                : std::get_if<flutter::EncodableMap>(
                                      method_call.arguments());
          const auto resize_edge =
              GetStringArg(map, "resizeEdge", std::string());
          result->Success(flutter::EncodableValue(
              StartResizeWithoutSystemFeedback(GetHandle(), resize_edge)));
          return;
        }

        if (method_call.method_name() == "get_desktop_lyric_rect") {
          HWND lyric_hwnd = FindDesktopLyricWindowFromArgs(method_call.arguments());
          if (lyric_hwnd == nullptr) {
            result->Success(flutter::EncodableValue());
            return;
          }

          RECT rect = {};
          if (!GetWindowRect(lyric_hwnd, &rect)) {
            result->Success(flutter::EncodableValue());
            return;
          }

          flutter::EncodableMap rect_map;
          rect_map[flutter::EncodableValue("left")] =
              flutter::EncodableValue(rect.left);
          rect_map[flutter::EncodableValue("top")] =
              flutter::EncodableValue(rect.top);
          rect_map[flutter::EncodableValue("width")] =
              flutter::EncodableValue(rect.right - rect.left);
          rect_map[flutter::EncodableValue("height")] =
              flutter::EncodableValue(rect.bottom - rect.top);
          result->Success(flutter::EncodableValue(rect_map));
          return;
        }

        if (method_call.method_name() == "set_desktop_lyric_position") {
          const auto* map = method_call.arguments() == nullptr
                                ? nullptr
                                : std::get_if<flutter::EncodableMap>(
                                      method_call.arguments());
          if (map == nullptr) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          HWND lyric_hwnd = FindDesktopLyricWindowFromArgs(method_call.arguments());
          if (lyric_hwnd == nullptr) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          RECT rect = {};
          if (!GetWindowRect(lyric_hwnd, &rect)) {
            result->Success(flutter::EncodableValue(false));
            return;
          }

          const int left = GetIntArg(map, "left", rect.left);
          const int top = GetIntArg(map, "top", rect.top);
          const int width = rect.right - rect.left;
          const int height = rect.bottom - rect.top;
          const BOOL moved = SetWindowPos(
              lyric_hwnd, HWND_TOPMOST, left, top, width, height, SWP_NOACTIVATE);
          result->Success(flutter::EncodableValue(moved != FALSE));
          return;
        }

        if (method_call.method_name() == "set_window_backdrop_mode") {
          const auto* map = method_call.arguments() == nullptr
                                ? nullptr
                                : std::get_if<flutter::EncodableMap>(
                                      method_call.arguments());
          const auto requested_mode =
              GetStringArg(map, "mode", std::string("auto"));
          const auto applied_mode = SetWindowBackdropMode(requested_mode);
          result->Success(flutter::EncodableValue(applied_mode));
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();
  ApplyRoundedWindowAppearance();

  return true;
}

void FlutterWindow::OnDestroy() {
  TerminateDesktopLyricProcesses();
  RemoveTrayIcon();
  if (taskbar_list_ != nullptr) {
    taskbar_list_->Release();
    taskbar_list_ = nullptr;
  }

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  if (media_control_channel_) {
    media_control_channel_.reset();
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (activate_window_message_ != 0 && message == activate_window_message_) {
    allow_close_ = false;
    if (!IsWindowVisible(GetHandle())) {
      RestoreFromTray();
      return 0;
    }

    if (IsIconic(GetHandle())) {
      ShowWindow(GetHandle(), SW_RESTORE);
    } else {
      ShowWindow(GetHandle(), SW_SHOW);
    }
    SetForegroundWindow(GetHandle());
    was_maximized_before_tray_ = WasWindowMaximized(GetHandle());
    return 0;
  }

  if (taskbar_button_created_message_ != 0 &&
      message == taskbar_button_created_message_) {
    thumb_buttons_added_ = false;
    SetupTaskbarButtons();
    return 0;
  }

  switch (message) {
    case WM_NCCALCSIZE:
      return 0;
    case WM_NCHITTEST:
      return NativeWindowHitTest(hwnd, lparam);
    case WM_SIZE:
    case WM_DPICHANGED:
    case WM_WINDOWPOSCHANGED:
      ApplyRoundedWindowAppearance();
      break;
    case WM_SETCURSOR:
      if (HandleNativeSetCursor(hwnd, wparam, lparam)) {
        return TRUE;
      }
      break;
    case kRefreshThumbButtonsMessage:
      SetupTaskbarButtons();
      return 0;
    case WM_SYSCOMMAND:
      if ((wparam & 0xFFF0) == SC_CLOSE && !allow_close_) {
        MinimizeToTray();
        return 0;
      }
      if ((wparam & 0xFFF0) == SC_KEYMENU) {
        return 0;
      }
      break;
    case WM_SYSKEYDOWN:
    case WM_SYSKEYUP:
      if (IsAltKeyMessage(wparam)) {
        return 0;
      }
      break;
    case WM_SYSCHAR:
      return 0;
    case WM_CLOSE:
      if (!allow_close_) {
        MinimizeToTray();
        return 0;
      }
      break;
    case kTrayCallbackMessage:
      switch (LOWORD(lparam)) {
        case NIN_SELECT:
        case NIN_KEYSELECT:
        case WM_LBUTTONUP:
        case WM_LBUTTONDBLCLK:
          RestoreFromTray();
          return 0;
        case WM_CONTEXTMENU:
        case WM_RBUTTONUP:
          ShowTrayMenu();
          return 0;
      }
      break;
    case WM_COMMAND:
      if (HIWORD(wparam) == THBN_CLICKED &&
          HandlePlaybackCommand(LOWORD(wparam))) {
        return 0;
      }
      switch (LOWORD(wparam)) {
        case kCommandRestore:
          RestoreFromTray();
          return 0;
        case kCommandExit:
          ExitApplication();
          return 0;
        default:
          if (HandlePlaybackCommand(LOWORD(wparam))) {
            return 0;
          }
      }
      break;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::AddTrayIcon() {
  if (tray_icon_added_) {
    return;
  }

  tray_icon_data_ = {};
  tray_icon_data_.cbSize = sizeof(NOTIFYICONDATA);
  tray_icon_data_.hWnd = GetHandle();
  tray_icon_data_.uID = kTrayIconId;
  tray_icon_data_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  tray_icon_data_.uCallbackMessage = kTrayCallbackMessage;
  tray_icon_data_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  lstrcpynW(tray_icon_data_.szTip, L"\u6816\u58F0",
            ARRAYSIZE(tray_icon_data_.szTip));

  if (Shell_NotifyIcon(NIM_ADD, &tray_icon_data_)) {
    tray_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &tray_icon_data_);
    tray_icon_added_ = true;
  }
}

void FlutterWindow::RemoveTrayIcon() {
  if (!tray_icon_added_) {
    return;
  }

  Shell_NotifyIcon(NIM_DELETE, &tray_icon_data_);
  tray_icon_added_ = false;
}

void FlutterWindow::MinimizeToTray() {
  AddTrayIcon();
  thumb_buttons_added_ = false;
  was_maximized_before_tray_ = WasWindowMaximized(GetHandle());
  ShowWindow(GetHandle(), SW_HIDE);
}

void FlutterWindow::RestoreFromTray() {
  allow_close_ = false;
  const bool restore_maximized = was_maximized_before_tray_;
  ShowWindow(
      GetHandle(),
      restore_maximized ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
  SetForegroundWindow(GetHandle());
  was_maximized_before_tray_ = WasWindowMaximized(GetHandle());
  PostMessage(GetHandle(), kRefreshThumbButtonsMessage, 0, 0);
}

void FlutterWindow::ExitApplication() {
  TerminateDesktopLyricProcesses();
  allow_close_ = true;
  PostMessage(GetHandle(), WM_CLOSE, 0, 0);
}

int FlutterWindow::GetIntArg(const flutter::EncodableMap* map, const char* key,
                             int default_value) {
  if (map == nullptr || key == nullptr) {
    return default_value;
  }

  const auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return default_value;
  }

  if (const auto* int_value = std::get_if<int32_t>(&it->second)) {
    return static_cast<int>(*int_value);
  }
  if (const auto* int_value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*int_value);
  }
  if (const auto* double_value = std::get_if<double>(&it->second)) {
    return static_cast<int>(*double_value);
  }
  return default_value;
}

std::string FlutterWindow::GetStringArg(const flutter::EncodableMap* map,
                                        const char* key,
                                        const std::string& default_value) {
  if (map == nullptr || key == nullptr) {
    return default_value;
  }

  const auto it = map->find(flutter::EncodableValue(key));
  if (it == map->end()) {
    return default_value;
  }

  if (const auto* string_value = std::get_if<std::string>(&it->second)) {
    return *string_value;
  }
  return default_value;
}

flutter::EncodableMap FlutterWindow::SetWindowBackdropMode(
    const std::string& requested_mode) {
  auto resolution = ResolveBackdropRequest(requested_mode);
  const HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    resolution.applied_mode = "none";
    resolution.fallback_reason = "window_handle_unavailable";
    return EncodeBackdropResolution(resolution);
  }

  if (!resolution.native_backdrop_supported) {
    const int fallback_type = DWMSBT_NONE;
    DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &fallback_type,
                          sizeof(fallback_type));
    if (resolution.applied_mode.empty()) {
      resolution.applied_mode = "none";
    }
    ApplyRoundedWindowAppearance();
    return EncodeBackdropResolution(resolution);
  }

  const HRESULT apply_result = DwmSetWindowAttribute(
      hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &resolution.backdrop_type,
      sizeof(resolution.backdrop_type));
  if (SUCCEEDED(apply_result)) {
    resolution.native_apply_succeeded = true;
    ApplyRoundedWindowAppearance();
    return EncodeBackdropResolution(resolution);
  }

  const int fallback_type = DWMSBT_NONE;
  DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &fallback_type,
                        sizeof(fallback_type));
  resolution.applied_mode = "none";
  if (resolution.fallback_reason.empty()) {
    std::ostringstream reason_stream;
    reason_stream << "native_apply_failed_" << std::hex
                  << static_cast<unsigned long>(apply_result);
    resolution.fallback_reason = reason_stream.str();
  }
  ApplyRoundedWindowAppearance();
  return EncodeBackdropResolution(resolution);
}

void FlutterWindow::ApplyRoundedWindowAppearance() {
  const HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  const int corner_preference =
      ShouldRoundMainWindow(hwnd) ? DWMWCP_ROUND : DWMWCP_DONOTROUND;
  DwmSetWindowAttribute(
      hwnd,
      DWMWA_WINDOW_CORNER_PREFERENCE,
      &corner_preference,
      sizeof(corner_preference));
  UpdateRoundedWindowRegion();
}

void FlutterWindow::UpdateRoundedWindowRegion() {
  const HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  if (!ShouldRoundMainWindow(hwnd)) {
    SetWindowRgn(hwnd, nullptr, TRUE);
    return;
  }

  RECT window_rect = {};
  if (GetWindowRect(hwnd, &window_rect) == FALSE) {
    return;
  }

  const int width =
      std::max(0, static_cast<int>(window_rect.right - window_rect.left));
  const int height =
      std::max(0, static_cast<int>(window_rect.bottom - window_rect.top));
  if (width == 0 || height == 0) {
    return;
  }

  const int radius = WindowCornerRadiusPx(hwnd);
  HRGN region =
      CreateRoundRectRgn(0, 0, width + 1, height + 1, radius, radius);
  if (region == nullptr) {
    return;
  }

  if (SetWindowRgn(hwnd, region, TRUE) == 0) {
    DeleteObject(region);
  }
}

HWND FlutterWindow::FindDesktopLyricWindowByPid(DWORD pid) const {
  if (pid == 0) {
    return nullptr;
  }

  WindowSearchData data = {};
  data.process_id = pid;
  EnumWindows(EnumDesktopLyricWindowByPidProc, reinterpret_cast<LPARAM>(&data));
  if (data.preferred_hwnd != nullptr) {
    return data.preferred_hwnd;
  }
  return data.fallback_hwnd;
}

void FlutterWindow::SetRegisteredDesktopLyricProcess(
    DWORD pid,
    const std::wstring& executable_path) {
  if (pid == 0 || executable_path.empty()) {
    desktop_lyric_pid_ = 0;
    desktop_lyric_executable_path_.clear();
    return;
  }

  desktop_lyric_pid_ = pid;
  desktop_lyric_executable_path_ = NormalizeWindowsPath(executable_path);
}

DWORD FlutterWindow::ResolveDesktopLyricPid(
    const flutter::EncodableValue* arguments) const {
  const auto* map = arguments == nullptr
                        ? nullptr
                        : std::get_if<flutter::EncodableMap>(arguments);
  if (map != nullptr) {
    const int pid = GetIntArg(map, "pid", 0);
    if (pid > 0) {
      return static_cast<DWORD>(pid);
    }
  }

  return desktop_lyric_pid_;
}

HWND FlutterWindow::FindDesktopLyricWindowFromArgs(
    const flutter::EncodableValue* arguments) const {
  const DWORD pid = ResolveDesktopLyricPid(arguments);
  if (pid == 0) {
    return nullptr;
  }
  return FindDesktopLyricWindowByPid(pid);
}

void FlutterWindow::TerminateDesktopLyricProcesses() const {
  if (desktop_lyric_pid_ == 0 || desktop_lyric_executable_path_.empty()) {
    return;
  }

  HANDLE process = OpenProcess(
      PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_TERMINATE,
      FALSE,
      desktop_lyric_pid_);
  if (process == nullptr) {
    return;
  }

  const auto image_path = GetProcessImagePath(process);
  if (image_path.has_value() &&
      NormalizeWindowsPath(*image_path) == desktop_lyric_executable_path_) {
    TerminateProcess(process, 0);
  }

  CloseHandle(process);
}

void FlutterWindow::ShowTrayMenu() {
  HMENU menu = CreatePopupMenu();
  if (!menu) {
    return;
  }

  AppendMenuW(menu, MF_STRING, kCommandRestore, L"\u6253\u5F00");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kCommandPrevious, L"\u4E0A\u4E00\u9996");
  AppendMenuW(menu, MF_STRING, kCommandPlayPause, L"\u64AD\u653E/\u6682\u505C");
  AppendMenuW(menu, MF_STRING, kCommandNext, L"\u4E0B\u4E00\u9996");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kCommandExit, L"\u9000\u51FA");

  POINT cursor_point;
  GetCursorPos(&cursor_point);
  SetForegroundWindow(GetHandle());
  TrackPopupMenu(menu, TPM_RIGHTBUTTON, cursor_point.x, cursor_point.y, 0,
                 GetHandle(), nullptr);
  PostMessage(GetHandle(), WM_NULL, 0, 0);
  DestroyMenu(menu);
}

void FlutterWindow::SetupTaskbarButtons() {
  if (taskbar_list_ == nullptr) {
    if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr,
                                CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&taskbar_list_)))) {
      taskbar_list_ = nullptr;
      return;
    }
    if (FAILED(taskbar_list_->HrInit())) {
      taskbar_list_->Release();
      taskbar_list_ = nullptr;
      return;
    }
  }

  if (icon_prev_ == nullptr) {
    icon_prev_ = CreateTransportIcon(TransportIconType::Previous);
  }
  if (icon_play_ == nullptr) {
    icon_play_ = CreateTransportIcon(TransportIconType::Play);
  }
  if (icon_pause_ == nullptr) {
    icon_pause_ = CreateTransportIcon(TransportIconType::Pause);
  }
  if (icon_next_ == nullptr) {
    icon_next_ = CreateTransportIcon(TransportIconType::Next);
  }

  if (icon_prev_ == nullptr || icon_play_ == nullptr || icon_pause_ == nullptr ||
      icon_next_ == nullptr) {
    icon_prev_ = LoadIcon(nullptr, IDI_WARNING);
    icon_play_ = LoadIcon(nullptr, IDI_INFORMATION);
    icon_pause_ = LoadIcon(nullptr, IDI_INFORMATION);
    icon_next_ = LoadIcon(nullptr, IDI_APPLICATION);
  }

  THUMBBUTTON buttons[3] = {};
  buttons[0].iId = kThumbButtonPrevious;
  buttons[0].dwMask = THB_FLAGS | THB_ICON | THB_TOOLTIP;
  buttons[0].dwFlags = THBF_ENABLED;
  buttons[0].hIcon = icon_prev_;
  wcscpy_s(buttons[0].szTip, L"\u4E0A\u4E00\u9996");

  buttons[1].iId = kThumbButtonPlayPause;
  buttons[1].dwMask = THB_FLAGS | THB_ICON | THB_TOOLTIP;
  buttons[1].dwFlags = THBF_ENABLED;
  buttons[1].hIcon = is_playing_ ? icon_pause_ : icon_play_;
  wcscpy_s(buttons[1].szTip, is_playing_ ? L"\u6682\u505C" : L"\u64AD\u653E");

  buttons[2].iId = kThumbButtonNext;
  buttons[2].dwMask = THB_FLAGS | THB_ICON | THB_TOOLTIP;
  buttons[2].dwFlags = THBF_ENABLED;
  buttons[2].hIcon = icon_next_;
  wcscpy_s(buttons[2].szTip, L"\u4E0B\u4E00\u9996");

  HRESULT result = E_FAIL;
  if (thumb_buttons_added_) {
    result =
        taskbar_list_->ThumbBarUpdateButtons(GetHandle(), ARRAYSIZE(buttons),
                                             buttons);
    if (FAILED(result)) {
      result = taskbar_list_->ThumbBarAddButtons(GetHandle(), ARRAYSIZE(buttons),
                                                 buttons);
    }
  } else {
    result = taskbar_list_->ThumbBarAddButtons(GetHandle(), ARRAYSIZE(buttons),
                                               buttons);
    if (FAILED(result)) {
      result =
          taskbar_list_->ThumbBarUpdateButtons(GetHandle(), ARRAYSIZE(buttons),
                                               buttons);
    }
  }
  thumb_buttons_added_ = SUCCEEDED(result);
}

HICON FlutterWindow::CreateTransportIcon(TransportIconType type) const {
  constexpr int kIconSize = 16;

  BITMAPV5HEADER bitmap_header = {};
  bitmap_header.bV5Size = sizeof(BITMAPV5HEADER);
  bitmap_header.bV5Width = kIconSize;
  bitmap_header.bV5Height = -kIconSize;
  bitmap_header.bV5Planes = 1;
  bitmap_header.bV5BitCount = 32;
  bitmap_header.bV5Compression = BI_BITFIELDS;
  bitmap_header.bV5RedMask = 0x00FF0000;
  bitmap_header.bV5GreenMask = 0x0000FF00;
  bitmap_header.bV5BlueMask = 0x000000FF;
  bitmap_header.bV5AlphaMask = 0xFF000000;

  void* raw_bits = nullptr;
  HDC screen_dc = GetDC(nullptr);
  HBITMAP color_bitmap = CreateDIBSection(
      screen_dc, reinterpret_cast<BITMAPINFO*>(&bitmap_header), DIB_RGB_COLORS,
      &raw_bits, nullptr, 0);
  ReleaseDC(nullptr, screen_dc);
  if (color_bitmap == nullptr || raw_bits == nullptr) {
    if (color_bitmap != nullptr) {
      DeleteObject(color_bitmap);
    }
    return nullptr;
  }

  auto* pixels = static_cast<std::uint32_t*>(raw_bits);
  std::fill_n(pixels, kIconSize * kIconSize, 0u);
  std::array<std::uint16_t, kIconSize> mask_rows;
  mask_rows.fill(0xFFFF);

  const auto set_pixel = [&](int x, int y) {
    if (x < 0 || x >= kIconSize || y < 0 || y >= kIconSize) {
      return;
    }
    pixels[y * kIconSize + x] = 0xFFFFFFFF;
    mask_rows[y] = static_cast<std::uint16_t>(
        mask_rows[y] & static_cast<std::uint16_t>(~(1u << (15 - x))));
  };

  const auto draw_rect = [&](int left, int top, int right, int bottom) {
    for (int y = top; y < bottom; ++y) {
      for (int x = left; x < right; ++x) {
        set_pixel(x, y);
      }
    }
  };

  const auto draw_triangle = [&](int x0, int y0, int x1, int y1, int x2,
                                 int y2) {
    const int min_x = std::max(0, std::min({x0, x1, x2}));
    const int max_x = std::min(kIconSize - 1, std::max({x0, x1, x2}));
    const int min_y = std::max(0, std::min({y0, y1, y2}));
    const int max_y = std::min(kIconSize - 1, std::max({y0, y1, y2}));

    const auto edge = [](double ax, double ay, double bx, double by, double cx,
                         double cy) {
      return (cx - ax) * (by - ay) - (cy - ay) * (bx - ax);
    };

    const double area = edge(x0, y0, x1, y1, x2, y2);
    if (area == 0.0) {
      return;
    }

    for (int y = min_y; y <= max_y; ++y) {
      for (int x = min_x; x <= max_x; ++x) {
        const double px = static_cast<double>(x) + 0.5;
        const double py = static_cast<double>(y) + 0.5;
        const double w0 = edge(x1, y1, x2, y2, px, py);
        const double w1 = edge(x2, y2, x0, y0, px, py);
        const double w2 = edge(x0, y0, x1, y1, px, py);

        const bool is_inside = area > 0
                                   ? (w0 >= 0 && w1 >= 0 && w2 >= 0)
                                   : (w0 <= 0 && w1 <= 0 && w2 <= 0);
        if (is_inside) {
          set_pixel(x, y);
        }
      }
    }
  };

  switch (type) {
    case TransportIconType::Previous:
      draw_rect(2, 3, 5, 13);
      draw_triangle(13, 3, 6, 8, 13, 13);
      break;
    case TransportIconType::Play:
      draw_triangle(4, 3, 4, 13, 12, 8);
      break;
    case TransportIconType::Pause:
      draw_rect(4, 3, 7, 13);
      draw_rect(9, 3, 12, 13);
      break;
    case TransportIconType::Next:
      draw_triangle(3, 3, 10, 8, 3, 13);
      draw_rect(11, 3, 14, 13);
      break;
  }

  HBITMAP mask_bitmap =
      CreateBitmap(kIconSize, kIconSize, 1, 1, mask_rows.data());
  if (mask_bitmap == nullptr) {
    DeleteObject(color_bitmap);
    return nullptr;
  }

  ICONINFO icon_info = {};
  icon_info.fIcon = TRUE;
  icon_info.hbmColor = color_bitmap;
  icon_info.hbmMask = mask_bitmap;
  HICON icon = CreateIconIndirect(&icon_info);

  DeleteObject(mask_bitmap);
  DeleteObject(color_bitmap);
  return icon;
}

bool FlutterWindow::HandlePlaybackCommand(UINT command_id) {
  switch (command_id) {
    case kCommandPrevious:
    case kThumbButtonPrevious:
      InvokePlaybackAction("previous");
      return true;
    case kCommandPlayPause:
    case kThumbButtonPlayPause:
      InvokePlaybackAction("play_pause");
      return true;
    case kCommandNext:
    case kThumbButtonNext:
      InvokePlaybackAction("next");
      return true;
    default:
      return false;
  }
}

void FlutterWindow::InvokePlaybackAction(const std::string& method_name) const {
  if (media_control_channel_) {
    media_control_channel_->InvokeMethod(method_name, nullptr);
    return;
  }

  if (method_name == "previous") {
    SendMediaKey(VK_MEDIA_PREV_TRACK);
  } else if (method_name == "play_pause") {
    SendMediaKey(VK_MEDIA_PLAY_PAUSE);
  } else if (method_name == "next") {
    SendMediaKey(VK_MEDIA_NEXT_TRACK);
  }
}

void FlutterWindow::SendMediaKey(WORD vk) const {
  keybd_event(static_cast<BYTE>(vk), 0, 0, 0);
  keybd_event(static_cast<BYTE>(vk), 0, KEYEVENTF_KEYUP, 0);
}
