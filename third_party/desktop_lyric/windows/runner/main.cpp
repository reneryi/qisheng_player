#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  bool is_config_window = false;
  for (const auto& arg : command_line_arguments) {
    if (arg == "--config-window") {
      is_config_window = true;
      break;
    }
  }

  // 为父进程配置 Job Object，确保一旦父进程被终止或崩溃，子进程自动跟随终结，绝不发生子进程孤立残留
  if (!is_config_window) {
    HANDLE job = CreateJobObject(nullptr, nullptr);
    if (job != nullptr) {
      JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli = {};
      jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
      SetInformationJobObject(job, JobObjectExtendedLimitInformation, &jeli, sizeof(jeli));
      AssignProcessToJobObject(job, GetCurrentProcess());
    }
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size = is_config_window ? Win32Window::Size(720, 640)
                                            : Win32Window::Size(800, 180);
  const wchar_t* title =
      is_config_window ? L"desktop_lyric_config" : L"desktop_lyric";
  if (!window.Create(title, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
