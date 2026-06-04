#ifndef FLUTTER_PLUGIN_BLEUNLOCK_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_BLEUNLOCK_WINDOWS_PLUGIN_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <mutex>
#include <shellapi.h>
#include <string>
#include <vector>
#include <windows.h>

namespace bleunlock_windows {

struct WindowsBleWatcherState;

class BleunlockWindowsPlugin : public flutter::Plugin {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    BleunlockWindowsPlugin();

    virtual ~BleunlockWindowsPlugin();

    BleunlockWindowsPlugin(const BleunlockWindowsPlugin &) = delete;
    BleunlockWindowsPlugin &operator=(const BleunlockWindowsPlugin &) = delete;

    LRESULT HandleWindowMessage(HWND hwnd,
                                UINT message,
                                WPARAM wparam,
                                LPARAM lparam);

    void QueueScanEvent(flutter::EncodableMap event);

  private:
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    void StartScan(bool active);

    void StopScan();

    flutter::EncodableValue GetScannerCapability();

    flutter::EncodableValue GetUnlockCapability() const;

    flutter::EncodableValue UnlockWithCredentialProvider() const;

    void OpenUnlockSettings() const;

    void FlushScanEvents();

    bool Lock(DWORD *error_code);

    void WakeDisplay();

    bool IsLocked() const;

    bool WriteSecret(const std::string &key,
                     const std::string &value,
                     DWORD *error_code) const;

    bool ReadSecret(const std::string &key,
                    std::string *value,
                    bool *found,
                    DWORD *error_code) const;

    bool DeleteSecret(const std::string &key, DWORD *error_code) const;

    bool IsStartupEnabled() const;

    bool SetStartupEnabled(bool enabled, DWORD *error_code) const;

    void SetTrayStatus(const std::string &status,
                       const std::string &recent_device_summary,
                       bool is_monitoring);

    void ShowTrayMenu();

    bool HandleTrayCommand(UINT command_id);

    void EnsureTrayIcon();

    void UpdateTrayTip();

    void EmitSessionEvent(const char *kind, const char *reason) const;

    void EmitScanEvent(const flutter::EncodableValue &event) const;

    void EmitTrayAction(const char *kind) const;

    std::unique_ptr<WindowsBleWatcherState> ble_watcher_;
    std::mutex pending_scan_events_mutex_;
    std::vector<flutter::EncodableValue> pending_scan_events_;
    WNDPROC original_window_proc_ = nullptr;
    HWND registrar_window_ = nullptr;
    HPOWERNOTIFY display_power_notify_ = nullptr;
    NOTIFYICONDATAW tray_icon_data_ = {};
    std::string tray_status_ = "normal";
    std::string tray_recent_device_summary_;
    bool tray_is_monitoring_ = false;
    bool session_locked_ = false;
    bool tray_icon_created_ = false;
};

} // namespace bleunlock_windows

#endif // FLUTTER_PLUGIN_BLEUNLOCK_WINDOWS_PLUGIN_H_
