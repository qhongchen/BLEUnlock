#include "bleunlock_windows_plugin.h"

#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <chrono>
#include <iomanip>
#include <memory>
#include <mutex>
#include <shellapi.h>
#include <sstream>
#include <string>
#include <variant>
#include <vector>
#include <wincred.h>
#include <windows.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/base.h>
#include <wtsapi32.h>

namespace bleunlock_windows {
namespace {

constexpr char kScannerMethodChannelName[] =
    "bleunlock_windows/ble_scanner_methods";
constexpr char kScannerEventChannelName[] =
    "bleunlock_windows/ble_scanner_events";
constexpr char kSessionMethodChannelName[] =
    "bleunlock_windows/session_methods";
constexpr char kSessionEventChannelName[] =
    "bleunlock_windows/session_events";
constexpr char kSecureStoreMethodChannelName[] =
    "bleunlock_windows/secure_store_methods";
constexpr char kTrayMethodChannelName[] = "bleunlock_windows/tray_methods";
constexpr char kTrayEventChannelName[] = "bleunlock_windows/tray_events";
constexpr char kStartupMethodChannelName[] =
    "bleunlock_windows/startup_methods";
constexpr wchar_t kCredentialTargetPrefix[] =
    L"com.github.skyearn.bleunlock.flutter/";
constexpr wchar_t kStartupRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kStartupValueName[] = L"BLEUnlock Flutter";
constexpr UINT kTrayCallbackMessage = WM_APP + 42;
constexpr UINT kScanEventMessage = WM_APP + 43;
constexpr UINT_PTR kTrayIconId = 1;
constexpr UINT kTrayCommandOpenSettings = 1001;
constexpr UINT kTrayCommandStartMonitoring = 1002;
constexpr UINT kTrayCommandPauseMonitoring = 1003;
constexpr UINT kTrayCommandLockNow = 1004;
constexpr UINT kTrayCommandQuit = 1005;

using EventSink = flutter::EventSink<flutter::EncodableValue>;
using BluetoothLEAdvertisement = winrt::Windows::Devices::Bluetooth::
    Advertisement::BluetoothLEAdvertisement;
using BluetoothLEAdvertisementReceivedEventArgs = winrt::Windows::Devices::
    Bluetooth::Advertisement::BluetoothLEAdvertisementReceivedEventArgs;
using BluetoothLEAdvertisementWatcher = winrt::Windows::Devices::Bluetooth::
    Advertisement::BluetoothLEAdvertisementWatcher;
using BluetoothLEAdvertisementWatcherStatus = winrt::Windows::Devices::
    Bluetooth::Advertisement::BluetoothLEAdvertisementWatcherStatus;
using BluetoothLEScanningMode =
    winrt::Windows::Devices::Bluetooth::Advertisement::BluetoothLEScanningMode;
using DataReader = winrt::Windows::Storage::Streams::DataReader;

std::unique_ptr<EventSink> g_scan_event_sink;
std::unique_ptr<EventSink> g_session_event_sink;
std::unique_ptr<EventSink> g_tray_event_sink;
BleunlockWindowsPlugin *g_plugin_instance = nullptr;

int64_t CurrentTimeMillis() {
    const auto now = std::chrono::system_clock::now().time_since_epoch();
    return std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
}

std::string SessionKindFromWtsStatus(WPARAM status) {
    switch (status) {
        case WTS_SESSION_LOCK:
            return "locked";
        case WTS_SESSION_UNLOCK:
            return "unlocked";
        case WTS_SESSION_LOGOFF:
        case WTS_CONSOLE_DISCONNECT:
        case WTS_REMOTE_DISCONNECT:
            return "systemSleep";
        case WTS_SESSION_LOGON:
        case WTS_CONSOLE_CONNECT:
        case WTS_REMOTE_CONNECT:
            return "systemWake";
        default:
            return "";
    }
}

std::wstring Utf8ToWide(const std::string &value) {
    if (value.empty()) {
        return std::wstring();
    }

    const int length = MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), nullptr, 0);
    if (length <= 0) {
        return std::wstring();
    }

    std::wstring result(static_cast<size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, value.data(), static_cast<int>(value.size()), result.data(), length);
    return result;
}

std::wstring CredentialTargetForKey(const std::string &key) {
    return std::wstring(kCredentialTargetPrefix) + Utf8ToWide(key);
}

std::string FormatBluetoothAddress(uint64_t bluetooth_address) {
    std::ostringstream stream;
    stream << std::uppercase << std::hex << std::setw(12) << std::setfill('0')
           << bluetooth_address;
    return stream.str();
}

std::string FormatBluetoothAddressHint(uint64_t bluetooth_address) {
    const auto compact = FormatBluetoothAddress(bluetooth_address);
    std::ostringstream stream;
    for (size_t index = 0; index < compact.size(); index += 2) {
        if (index > 0) {
            stream << ":";
        }
        stream << compact.substr(index, 2);
    }
    return stream.str();
}

flutter::EncodableList ManufacturerDataBytes(
    const BluetoothLEAdvertisement &advertisement) {
    flutter::EncodableList result;
    for (const auto &section : advertisement.ManufacturerData()) {
        const auto company_id = section.CompanyId();
        result.emplace_back(static_cast<int32_t>(company_id & 0xFF));
        result.emplace_back(static_cast<int32_t>((company_id >> 8) & 0xFF));

        const auto data = section.Data();
        if (!data || data.Length() == 0) {
            continue;
        }

        auto reader = DataReader::FromBuffer(data);
        std::vector<uint8_t> bytes(data.Length());
        reader.ReadBytes(winrt::array_view<uint8_t>(bytes));
        for (const auto byte : bytes) {
            result.emplace_back(static_cast<int32_t>(byte));
        }
    }
    return result;
}

flutter::EncodableMap ScanEventFromAdvertisement(
    const BluetoothLEAdvertisementReceivedEventArgs &args) {
    const auto address = FormatBluetoothAddress(args.BluetoothAddress());
    const auto address_hint = FormatBluetoothAddressHint(args.BluetoothAddress());
    const auto advertisement = args.Advertisement();
    const auto local_name = winrt::to_string(advertisement.LocalName());

    flutter::EncodableMap event;
    event[flutter::EncodableValue("deviceId")] = flutter::EncodableValue(address);
    event[flutter::EncodableValue("displayName")] =
        flutter::EncodableValue(local_name);
    event[flutter::EncodableValue("addressHint")] =
        flutter::EncodableValue(address_hint);
    event[flutter::EncodableValue("rssi")] =
        flutter::EncodableValue(static_cast<int32_t>(
            args.RawSignalStrengthInDBm()));
    event[flutter::EncodableValue("seenAtMillis")] =
        flutter::EncodableValue(CurrentTimeMillis());
    event[flutter::EncodableValue("manufacturerData")] =
        flutter::EncodableValue(ManufacturerDataBytes(advertisement));
    return event;
}

void EnsureWinrtApartment() {
    static thread_local bool attempted = false;
    if (attempted) {
        return;
    }

    attempted = true;
    try {
        winrt::init_apartment(winrt::apartment_type::multi_threaded);
    } catch (...) {
        // Flutter may already initialize COM for the current thread.
    }
}

std::wstring TrayTitleForStatus(const std::string &status) {
    if (status == "monitoring") {
        return L"BLEUnlock 监听中";
    }
    if (status == "locked") {
        return L"BLEUnlock 已锁定";
    }
    if (status == "warning") {
        return L"BLEUnlock !";
    }
    return L"BLEUnlock";
}

std::wstring TrayTipForStatus(const std::string &status,
                              const std::string &recent_device_summary) {
    auto title = TrayTitleForStatus(status);
    if (recent_device_summary.empty()) {
        return title;
    }
    return title + L"\n" + Utf8ToWide(recent_device_summary);
}

const flutter::EncodableMap *ArgumentsMap(
    const flutter::EncodableValue *arguments) {
    if (arguments == nullptr) {
        return nullptr;
    }
    return std::get_if<flutter::EncodableMap>(arguments);
}

bool StringArgument(const flutter::EncodableMap &arguments,
                    const char *key,
                    std::string *value) {
    const auto iterator = arguments.find(flutter::EncodableValue(key));
    if (iterator == arguments.end()) {
        return false;
    }

    const auto *string_value = std::get_if<std::string>(&iterator->second);
    if (string_value == nullptr) {
        return false;
    }

    *value = *string_value;
    return true;
}

bool OptionalStringArgument(const flutter::EncodableMap &arguments,
                            const char *key,
                            std::string *value) {
    const auto iterator = arguments.find(flutter::EncodableValue(key));
    if (iterator == arguments.end()) {
        value->clear();
        return true;
    }

    const auto *string_value = std::get_if<std::string>(&iterator->second);
    if (string_value == nullptr) {
        return false;
    }

    *value = *string_value;
    return true;
}

bool BoolArgument(const flutter::EncodableMap &arguments,
                  const char *key,
                  bool *value) {
    const auto iterator = arguments.find(flutter::EncodableValue(key));
    if (iterator == arguments.end()) {
        return false;
    }

    const auto *bool_value = std::get_if<bool>(&iterator->second);
    if (bool_value == nullptr) {
        return false;
    }

    *value = *bool_value;
    return true;
}

void CompleteWithWin32Error(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
    const char *method,
    DWORD error_code) {
    result->Error("win32_error", std::string(method) + " failed", flutter::EncodableValue(static_cast<int32_t>(error_code)));
}

flutter::EncodableValue CapabilityMap(const char *kind,
                                      const std::string &description = "") {
    flutter::EncodableMap value;
    value[flutter::EncodableValue("kind")] = flutter::EncodableValue(kind);
    if (!description.empty()) {
        value[flutter::EncodableValue("description")] =
            flutter::EncodableValue(description);
    }
    return flutter::EncodableValue(value);
}

LRESULT CALLBACK PluginWindowProc(HWND hwnd,
                                  UINT message,
                                  WPARAM wparam,
                                  LPARAM lparam) {
    if (g_plugin_instance != nullptr) {
        return g_plugin_instance->HandleWindowMessage(hwnd, message, wparam, lparam);
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

} // namespace

struct WindowsBleWatcherState {
    BluetoothLEAdvertisementWatcher watcher{nullptr};
    winrt::event_token received_token{};
    bool is_started = false;
};

BleunlockWindowsPlugin::BleunlockWindowsPlugin()
    : ble_watcher_(std::make_unique<WindowsBleWatcherState>()) {}

BleunlockWindowsPlugin::~BleunlockWindowsPlugin() {
    StopScan();
    if (tray_icon_created_) {
        Shell_NotifyIconW(NIM_DELETE, &tray_icon_data_);
    }
    if (registrar_window_ != nullptr) {
        WTSUnRegisterSessionNotification(registrar_window_);
        if (original_window_proc_ != nullptr) {
            SetWindowLongPtr(registrar_window_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(original_window_proc_));
        }
    }
    if (g_plugin_instance == this) {
        g_plugin_instance = nullptr;
    }
}

void BleunlockWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
    auto scanner_method_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kScannerMethodChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto scanner_event_channel =
        std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
            registrar->messenger(), kScannerEventChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto session_method_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kSessionMethodChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto session_event_channel =
        std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
            registrar->messenger(), kSessionEventChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto secure_store_method_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kSecureStoreMethodChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto tray_method_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kTrayMethodChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto tray_event_channel =
        std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
            registrar->messenger(), kTrayEventChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto startup_method_channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kStartupMethodChannelName, &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<BleunlockWindowsPlugin>();
    auto *view = registrar->GetView();
    plugin->registrar_window_ =
        view == nullptr ? nullptr : view->GetNativeWindow();
    g_plugin_instance = plugin.get();
    if (plugin->registrar_window_ != nullptr) {
        plugin->original_window_proc_ = reinterpret_cast<WNDPROC>(
            GetWindowLongPtr(plugin->registrar_window_, GWLP_WNDPROC));
        SetWindowLongPtr(plugin->registrar_window_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(PluginWindowProc));
        WTSRegisterSessionNotification(plugin->registrar_window_,
                                       NOTIFY_FOR_THIS_SESSION);
    }

    scanner_method_channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](
            const auto &call,
            auto result) { plugin_pointer->HandleMethodCall(call, std::move(result)); });

    session_method_channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](
            const auto &call,
            auto result) { plugin_pointer->HandleMethodCall(call, std::move(result)); });

    secure_store_method_channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](
            const auto &call,
            auto result) { plugin_pointer->HandleMethodCall(call, std::move(result)); });

    tray_method_channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](
            const auto &call,
            auto result) { plugin_pointer->HandleMethodCall(call, std::move(result)); });

    startup_method_channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](
            const auto &call,
            auto result) { plugin_pointer->HandleMethodCall(call, std::move(result)); });

    scanner_event_channel->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            [](const flutter::EncodableValue *arguments,
               std::unique_ptr<EventSink> &&events)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                g_scan_event_sink = std::move(events);
                return nullptr;
            },
            [](const flutter::EncodableValue *arguments)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                g_scan_event_sink.reset();
                return nullptr;
            }));

    session_event_channel->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            [](const flutter::EncodableValue *arguments,
               std::unique_ptr<EventSink> &&events)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                g_session_event_sink = std::move(events);
                return nullptr;
            },
            [](const flutter::EncodableValue *arguments)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                g_session_event_sink.reset();
                return nullptr;
            }));

    tray_event_channel->SetStreamHandler(
        std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
            [](const flutter::EncodableValue *arguments,
               std::unique_ptr<EventSink> &&events)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                g_tray_event_sink = std::move(events);
                if (g_plugin_instance != nullptr) {
                    g_plugin_instance->EnsureTrayIcon();
                }
                return nullptr;
            },
            [](const flutter::EncodableValue *arguments)
                -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
                g_tray_event_sink.reset();
                return nullptr;
            }));

    registrar->AddPlugin(std::move(plugin));
}

LRESULT BleunlockWindowsPlugin::HandleWindowMessage(HWND hwnd,
                                                    UINT message,
                                                    WPARAM wparam,
                                                    LPARAM lparam) {
    if (message == kScanEventMessage) {
        FlushScanEvents();
        return 0;
    }

    if (message == kTrayCallbackMessage) {
        const auto action = LOWORD(lparam);
        if (action == WM_CONTEXTMENU || action == WM_RBUTTONUP ||
            action == WM_LBUTTONUP) {
            ShowTrayMenu();
            return 0;
        }
    }

    if (message == WM_COMMAND && HandleTrayCommand(LOWORD(wparam))) {
        return 0;
    }

    if (message == WM_WTSSESSION_CHANGE) {
        const auto kind = SessionKindFromWtsStatus(wparam);
        if (!kind.empty()) {
            if (kind == "locked" || kind == "systemSleep") {
                session_locked_ = true;
            } else if (kind == "unlocked" || kind == "systemWake") {
                session_locked_ = false;
            }
            EmitSessionEvent(kind.c_str(), "WM_WTSSESSION_CHANGE");
        }
    }

    if (registrar_window_ == hwnd && original_window_proc_ != nullptr) {
        return CallWindowProc(original_window_proc_, hwnd, message, wparam, lparam);
    }

    return DefWindowProc(hwnd, message, wparam, lparam);
}

void BleunlockWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name() == "getScannerCapability") {
        result->Success(GetScannerCapability());
        return;
    }

    if (method_call.method_name() == "startScan") {
        try {
            StartScan();
            result->Success();
        } catch (const winrt::hresult_error &error) {
            result->Error("ble_scan_failed", winrt::to_string(error.message()));
        } catch (const std::exception &error) {
            result->Error("ble_scan_failed", error.what());
        }
        return;
    }

    if (method_call.method_name() == "stopScan") {
        try {
            StopScan();
            result->Success();
        } catch (const winrt::hresult_error &error) {
            result->Error("ble_scan_failed", winrt::to_string(error.message()));
        } catch (const std::exception &error) {
            result->Error("ble_scan_failed", error.what());
        }
        return;
    }

    if (method_call.method_name() == "lock") {
        Lock();
        result->Success();
        return;
    }

    if (method_call.method_name() == "wakeDisplay") {
        WakeDisplay();
        result->Success();
        return;
    }

    if (method_call.method_name() == "isLocked") {
        result->Success(flutter::EncodableValue(IsLocked()));
        return;
    }

    if (method_call.method_name() == "writeSecret") {
        const auto *arguments = ArgumentsMap(method_call.arguments());
        std::string key;
        std::string value;
        if (arguments == nullptr || !StringArgument(*arguments, "key", &key) ||
            !StringArgument(*arguments, "value", &value)) {
            result->Error("bad_args", "writeSecret requires key and value strings");
            return;
        }

        DWORD error_code = ERROR_SUCCESS;
        if (!WriteSecret(key, value, &error_code)) {
            CompleteWithWin32Error(std::move(result), "CredWriteW", error_code);
            return;
        }

        result->Success();
        return;
    }

    if (method_call.method_name() == "readSecret") {
        const auto *arguments = ArgumentsMap(method_call.arguments());
        std::string key;
        if (arguments == nullptr || !StringArgument(*arguments, "key", &key)) {
            result->Error("bad_args", "readSecret requires a key string");
            return;
        }

        std::string value;
        bool found = false;
        DWORD error_code = ERROR_SUCCESS;
        if (!ReadSecret(key, &value, &found, &error_code)) {
            CompleteWithWin32Error(std::move(result), "CredReadW", error_code);
            return;
        }

        if (!found) {
            result->Success();
            return;
        }

        result->Success(flutter::EncodableValue(value));
        return;
    }

    if (method_call.method_name() == "deleteSecret") {
        const auto *arguments = ArgumentsMap(method_call.arguments());
        std::string key;
        if (arguments == nullptr || !StringArgument(*arguments, "key", &key)) {
            result->Error("bad_args", "deleteSecret requires a key string");
            return;
        }

        DWORD error_code = ERROR_SUCCESS;
        if (!DeleteSecret(key, &error_code)) {
            CompleteWithWin32Error(std::move(result), "CredDeleteW", error_code);
            return;
        }

        result->Success();
        return;
    }

    if (method_call.method_name() == "setStatus") {
        const auto *arguments = ArgumentsMap(method_call.arguments());
        std::string status;
        std::string recent_device_summary;
        bool is_monitoring = false;
        if (arguments == nullptr || !StringArgument(*arguments, "status", &status) ||
            !OptionalStringArgument(*arguments, "recentDeviceSummary",
                                    &recent_device_summary)) {
            result->Error("bad_args", "setStatus requires a status string");
            return;
        }
        BoolArgument(*arguments, "isMonitoring", &is_monitoring);

        SetTrayStatus(status, recent_device_summary, is_monitoring);
        result->Success();
        return;
    }

    if (method_call.method_name() == "showQuickMenu") {
        ShowTrayMenu();
        result->Success();
        return;
    }

    if (method_call.method_name() == "isEnabled") {
        result->Success(flutter::EncodableValue(IsStartupEnabled()));
        return;
    }

    if (method_call.method_name() == "setEnabled") {
        const auto *arguments = ArgumentsMap(method_call.arguments());
        bool enabled = false;
        if (arguments == nullptr || !BoolArgument(*arguments, "enabled", &enabled)) {
            result->Error("bad_args", "setEnabled requires an enabled bool");
            return;
        }

        DWORD error_code = ERROR_SUCCESS;
        if (!SetStartupEnabled(enabled, &error_code)) {
            CompleteWithWin32Error(std::move(result), "startup registry update", error_code);
            return;
        }

        result->Success();
        return;
    }

    result->NotImplemented();
}

void BleunlockWindowsPlugin::StartScan() {
    EnsureWinrtApartment();

    if (!ble_watcher_->watcher) {
        ble_watcher_->watcher = BluetoothLEAdvertisementWatcher();
        ble_watcher_->watcher.ScanningMode(BluetoothLEScanningMode::Passive);
        ble_watcher_->received_token = ble_watcher_->watcher.Received(
            [this](const BluetoothLEAdvertisementWatcher &,
                   const BluetoothLEAdvertisementReceivedEventArgs &args) {
                QueueScanEvent(ScanEventFromAdvertisement(args));
            });
    }

    if (ble_watcher_->watcher.Status() !=
        BluetoothLEAdvertisementWatcherStatus::Started) {
        ble_watcher_->watcher.Start();
    }
    ble_watcher_->is_started = true;
}

void BleunlockWindowsPlugin::StopScan() {
    if (ble_watcher_ == nullptr || !ble_watcher_->watcher) {
        return;
    }

    if (ble_watcher_->watcher.Status() ==
        BluetoothLEAdvertisementWatcherStatus::Started) {
        ble_watcher_->watcher.Stop();
    }
    ble_watcher_->is_started = false;
}

flutter::EncodableValue BleunlockWindowsPlugin::GetScannerCapability() {
    try {
        EnsureWinrtApartment();
        BluetoothLEAdvertisementWatcher probe;
        probe.ScanningMode(BluetoothLEScanningMode::Passive);
        return CapabilityMap("supported");
    } catch (const winrt::hresult_error &error) {
        return CapabilityMap(
            "temporarilyUnavailable",
            "Bluetooth watcher unavailable: " + winrt::to_string(error.message()));
    } catch (const std::exception &error) {
        return CapabilityMap(
            "temporarilyUnavailable",
            std::string("Bluetooth watcher unavailable: ") + error.what());
    }
}

void BleunlockWindowsPlugin::QueueScanEvent(flutter::EncodableMap event) {
    {
        std::lock_guard<std::mutex> lock(pending_scan_events_mutex_);
        pending_scan_events_.emplace_back(std::move(event));
    }

    if (registrar_window_ != nullptr) {
        PostMessage(registrar_window_, kScanEventMessage, 0, 0);
    } else {
        FlushScanEvents();
    }
}

void BleunlockWindowsPlugin::FlushScanEvents() {
    std::vector<flutter::EncodableValue> events;
    {
        std::lock_guard<std::mutex> lock(pending_scan_events_mutex_);
        events.swap(pending_scan_events_);
    }

    for (const auto &event : events) {
        EmitScanEvent(event);
    }
}

void BleunlockWindowsPlugin::Lock() {
    LockWorkStation();
    session_locked_ = true;
}

void BleunlockWindowsPlugin::WakeDisplay() {
    SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED |
                            ES_DISPLAY_REQUIRED);
    SetThreadExecutionState(ES_CONTINUOUS);
}

bool BleunlockWindowsPlugin::IsLocked() const {
    return session_locked_;
}

bool BleunlockWindowsPlugin::WriteSecret(const std::string &key,
                                         const std::string &value,
                                         DWORD *error_code) const {
    const auto target = CredentialTargetForKey(key);
    auto mutable_value = std::vector<uint8_t>(value.begin(), value.end());

    CREDENTIALW credential = {};
    credential.Type = CRED_TYPE_GENERIC;
    credential.TargetName = const_cast<LPWSTR>(target.c_str());
    credential.CredentialBlobSize =
        static_cast<DWORD>(mutable_value.size() * sizeof(uint8_t));
    credential.CredentialBlob =
        mutable_value.empty() ? nullptr : mutable_value.data();
    credential.Persist = CRED_PERSIST_LOCAL_MACHINE;
    credential.UserName = const_cast<LPWSTR>(L"BLEUnlock");

    if (!CredWriteW(&credential, 0)) {
        *error_code = GetLastError();
        return false;
    }

    *error_code = ERROR_SUCCESS;
    return true;
}

bool BleunlockWindowsPlugin::ReadSecret(const std::string &key,
                                        std::string *value,
                                        bool *found,
                                        DWORD *error_code) const {
    const auto target = CredentialTargetForKey(key);
    PCREDENTIALW credential = nullptr;
    if (!CredReadW(target.c_str(), CRED_TYPE_GENERIC, 0, &credential)) {
        const auto last_error = GetLastError();
        if (last_error == ERROR_NOT_FOUND) {
            *found = false;
            *error_code = ERROR_SUCCESS;
            return true;
        }

        *error_code = last_error;
        return false;
    }

    value->assign(reinterpret_cast<const char *>(credential->CredentialBlob),
                  credential->CredentialBlobSize);
    CredFree(credential);
    *found = true;
    *error_code = ERROR_SUCCESS;
    return true;
}

bool BleunlockWindowsPlugin::DeleteSecret(const std::string &key,
                                          DWORD *error_code) const {
    const auto target = CredentialTargetForKey(key);
    if (!CredDeleteW(target.c_str(), CRED_TYPE_GENERIC, 0)) {
        const auto last_error = GetLastError();
        if (last_error == ERROR_NOT_FOUND) {
            *error_code = ERROR_SUCCESS;
            return true;
        }

        *error_code = last_error;
        return false;
    }

    *error_code = ERROR_SUCCESS;
    return true;
}

bool BleunlockWindowsPlugin::IsStartupEnabled() const {
    HKEY key = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, kStartupRunKey, 0, KEY_READ, &key) !=
        ERROR_SUCCESS) {
        return false;
    }

    const auto status = RegQueryValueExW(
        key, kStartupValueName, nullptr, nullptr, nullptr, nullptr);
    RegCloseKey(key);
    return status == ERROR_SUCCESS;
}

bool BleunlockWindowsPlugin::SetStartupEnabled(bool enabled,
                                               DWORD *error_code) const {
    HKEY key = nullptr;
    const auto create_status =
        RegCreateKeyExW(HKEY_CURRENT_USER, kStartupRunKey, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &key, nullptr);
    if (create_status != ERROR_SUCCESS) {
        *error_code = create_status;
        return false;
    }

    if (!enabled) {
        const auto delete_status = RegDeleteValueW(key, kStartupValueName);
        RegCloseKey(key);
        if (delete_status == ERROR_FILE_NOT_FOUND ||
            delete_status == ERROR_SUCCESS) {
            *error_code = ERROR_SUCCESS;
            return true;
        }
        *error_code = delete_status;
        return false;
    }

    wchar_t executable_path[MAX_PATH];
    const auto path_length =
        GetModuleFileNameW(nullptr, executable_path, MAX_PATH);
    if (path_length == 0 || path_length >= MAX_PATH) {
        *error_code = GetLastError();
        RegCloseKey(key);
        return false;
    }

    const std::wstring command =
        L"\"" + std::wstring(executable_path, path_length) + L"\"";
    const auto value_size =
        static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t));
    const auto set_status = RegSetValueExW(
        key, kStartupValueName, 0, REG_SZ, reinterpret_cast<const BYTE *>(command.c_str()), value_size);
    RegCloseKey(key);
    if (set_status != ERROR_SUCCESS) {
        *error_code = set_status;
        return false;
    }

    *error_code = ERROR_SUCCESS;
    return true;
}

void BleunlockWindowsPlugin::SetTrayStatus(
    const std::string &status,
    const std::string &recent_device_summary,
    bool is_monitoring) {
    tray_status_ = status;
    tray_recent_device_summary_ = recent_device_summary;
    tray_is_monitoring_ = is_monitoring;
    EnsureTrayIcon();
    UpdateTrayTip();
}

void BleunlockWindowsPlugin::ShowTrayMenu() {
    if (registrar_window_ == nullptr) {
        return;
    }

    EnsureTrayIcon();

    POINT cursor_position;
    GetCursorPos(&cursor_position);

    HMENU menu = CreatePopupMenu();
    AppendMenuW(menu, MF_STRING, kTrayCommandOpenSettings, L"打开设置");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    if (!tray_recent_device_summary_.empty()) {
        const auto summary = Utf8ToWide(tray_recent_device_summary_);
        AppendMenuW(menu, MF_STRING | MF_GRAYED, 0, summary.c_str());
        AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    }
    if (tray_is_monitoring_) {
        AppendMenuW(menu, MF_STRING, kTrayCommandPauseMonitoring, L"暂停监听");
    } else {
        AppendMenuW(menu, MF_STRING, kTrayCommandStartMonitoring, L"开始监听");
    }
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, kTrayCommandLockNow, L"立即锁屏");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, kTrayCommandQuit, L"退出 BLEUnlock");

    SetForegroundWindow(registrar_window_);
    TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_LEFTALIGN, cursor_position.x, cursor_position.y, 0, registrar_window_, nullptr);
    DestroyMenu(menu);
    PostMessage(registrar_window_, WM_NULL, 0, 0);
}

bool BleunlockWindowsPlugin::HandleTrayCommand(UINT command_id) {
    switch (command_id) {
        case kTrayCommandOpenSettings:
            if (registrar_window_ != nullptr) {
                ShowWindow(registrar_window_, SW_RESTORE);
                SetForegroundWindow(registrar_window_);
            }
            EmitTrayAction("openSettings");
            return true;
        case kTrayCommandStartMonitoring:
            EmitTrayAction("startMonitoring");
            return true;
        case kTrayCommandPauseMonitoring:
            EmitTrayAction("pauseMonitoring");
            return true;
        case kTrayCommandLockNow:
            EmitTrayAction("lockNow");
            return true;
        case kTrayCommandQuit:
            EmitTrayAction("quit");
            return true;
        default:
            return false;
    }
}

void BleunlockWindowsPlugin::EnsureTrayIcon() {
    if (tray_icon_created_ || registrar_window_ == nullptr) {
        return;
    }

    ZeroMemory(&tray_icon_data_, sizeof(tray_icon_data_));
    tray_icon_data_.cbSize = sizeof(NOTIFYICONDATAW);
    tray_icon_data_.hWnd = registrar_window_;
    tray_icon_data_.uID = kTrayIconId;
    tray_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    tray_icon_data_.uCallbackMessage = kTrayCallbackMessage;
    tray_icon_data_.hIcon = LoadIconW(nullptr, IDI_APPLICATION);
    const auto title = TrayTipForStatus(tray_status_, tray_recent_device_summary_);
    wcsncpy_s(tray_icon_data_.szTip, title.c_str(), _TRUNCATE);

    if (Shell_NotifyIconW(NIM_ADD, &tray_icon_data_)) {
        tray_icon_created_ = true;
        tray_icon_data_.uVersion = NOTIFYICON_VERSION_4;
        Shell_NotifyIconW(NIM_SETVERSION, &tray_icon_data_);
    }
}

void BleunlockWindowsPlugin::UpdateTrayTip() {
    if (!tray_icon_created_) {
        return;
    }

    tray_icon_data_.uFlags = NIF_TIP;
    const auto title = TrayTipForStatus(tray_status_, tray_recent_device_summary_);
    wcsncpy_s(tray_icon_data_.szTip, title.c_str(), _TRUNCATE);
    Shell_NotifyIconW(NIM_MODIFY, &tray_icon_data_);
}

void BleunlockWindowsPlugin::EmitSessionEvent(const char *kind,
                                              const char *reason) const {
    if (g_session_event_sink == nullptr) {
        return;
    }

    flutter::EncodableMap event;
    event[flutter::EncodableValue("kind")] = flutter::EncodableValue(kind);
    event[flutter::EncodableValue("timestampMillis")] =
        flutter::EncodableValue(CurrentTimeMillis());
    event[flutter::EncodableValue("reason")] = flutter::EncodableValue(reason);
    g_session_event_sink->Success(flutter::EncodableValue(event));
}

void BleunlockWindowsPlugin::EmitScanEvent(
    const flutter::EncodableValue &event) const {
    if (g_scan_event_sink == nullptr) {
        return;
    }

    g_scan_event_sink->Success(event);
}

void BleunlockWindowsPlugin::EmitTrayAction(const char *kind) const {
    if (g_tray_event_sink == nullptr) {
        return;
    }

    flutter::EncodableMap event;
    event[flutter::EncodableValue("kind")] = flutter::EncodableValue(kind);
    event[flutter::EncodableValue("timestampMillis")] =
        flutter::EncodableValue(CurrentTimeMillis());
    g_tray_event_sink->Success(flutter::EncodableValue(event));
}

} // namespace bleunlock_windows
