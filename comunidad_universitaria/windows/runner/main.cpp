#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <string>

#include "flutter_window.h"
#include "utils.h"
#include "app_links/app_links_plugin_c_api.h"

namespace {

// Registra el protocolo comunidadusac:// en el Registro de Windows del usuario actual.
// Esto permite que el navegador web despache callbacks de OAuth (Supabase) hacia la app.
void RegisterCustomUrlScheme() {
  wchar_t exePath[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exePath, MAX_PATH) == 0) {
    return;
  }

  std::wstring command = L"\"" + std::wstring(exePath) + L"\" \"%1\"";

  HKEY hKey;
  if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Classes\\comunidadusac", 0, nullptr,
                      REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
    const wchar_t* protocolDesc = L"URL:comunidadusac Protocol";
    RegSetValueExW(hKey, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(protocolDesc),
                   static_cast<DWORD>((wcslen(protocolDesc) + 1) * sizeof(wchar_t)));
    RegSetValueExW(hKey, L"URL Protocol", 0, REG_SZ, reinterpret_cast<const BYTE*>(L""), sizeof(wchar_t));

    HKEY hCmdKey;
    if (RegCreateKeyExW(hKey, L"shell\\open\\command", 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS, nullptr, &hCmdKey, nullptr) == ERROR_SUCCESS) {
      RegSetValueExW(hCmdKey, nullptr, 0, REG_SZ, reinterpret_cast<const BYTE*>(command.c_str()),
                     static_cast<DWORD>((command.length() + 1) * sizeof(wchar_t)));
      RegCloseKey(hCmdKey);
    }
    RegCloseKey(hKey);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Reenvía el deep link (comunidadusac://) a la instancia principal si ya está abierta y finaliza.
  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }

  // Registra el esquema comunidadusac:// apuntando a este ejecutable.
  RegisterCustomUrlScheme();

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

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"comunidad_universitaria", origin, size)) {
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
