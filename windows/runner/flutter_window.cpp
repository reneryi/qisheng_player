#include "flutter_window.h"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cwchar>
#include <commctrl.h>
#include <tlhelp32.h>
#include <optional>

#include "../flutter/generated_plugin_registrant.h"
#include "resource.h"

#ifndef NIN_SELECT
#define NIN_SELECT (WM_USER + 0)
#endif

namespace {
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
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {
  taskbar_button_created_message_ =
      RegisterWindowMessage(L"TaskbarButtonCreated");
  activate_window_message_ =
      RegisterWindowMessage(L"CorianderPlayerActivateMainWindow");
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
          "coriander_player/window_controls",
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

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

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
    case kRefreshThumbButtonsMessage:
      SetupTaskbarButtons();
      return 0;
    case WM_SYSCOMMAND:
      if ((wparam & 0xFFF0) == SC_CLOSE && !allow_close_) {
        MinimizeToTray();
        return 0;
      }
      break;
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
  lstrcpynW(tray_icon_data_.szTip, L"Coriander Player",
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

HWND FlutterWindow::FindDesktopLyricWindowFromArgs(
    const flutter::EncodableValue* arguments) const {
  const auto* map = arguments == nullptr
                        ? nullptr
                        : std::get_if<flutter::EncodableMap>(arguments);
  if (map != nullptr) {
    const int pid = GetIntArg(map, "pid", 0);
    if (pid > 0) {
      if (HWND by_pid =
              FindDesktopLyricWindowByPid(static_cast<DWORD>(pid))) {
        return by_pid;
      }
    }
  }
  return FindDesktopLyricWindowByTitle();
}

void FlutterWindow::TerminateDesktopLyricProcesses() const {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (snapshot == INVALID_HANDLE_VALUE) {
    return;
  }

  PROCESSENTRY32W entry = {};
  entry.dwSize = sizeof(PROCESSENTRY32W);
  if (!Process32FirstW(snapshot, &entry)) {
    CloseHandle(snapshot);
    return;
  }

  do {
    if (_wcsicmp(entry.szExeFile, L"desktop_lyric.exe") != 0) {
      continue;
    }

    HANDLE process = OpenProcess(PROCESS_TERMINATE, FALSE, entry.th32ProcessID);
    if (process == nullptr) {
      continue;
    }
    TerminateProcess(process, 0);
    CloseHandle(process);
  } while (Process32NextW(snapshot, &entry));

  CloseHandle(snapshot);
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
