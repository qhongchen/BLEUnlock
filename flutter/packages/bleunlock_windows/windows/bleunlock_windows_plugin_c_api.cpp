#include "include/bleunlock_windows/bleunlock_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "bleunlock_windows_plugin.h"

void BleunlockWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
    auto plugin_registrar =
        flutter::PluginRegistrarManager::GetInstance()
            ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
    bleunlock_windows::BleunlockWindowsPlugin::RegisterWithRegistrar(
        plugin_registrar);
}
