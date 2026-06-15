#include "../shared/bleunlock_auto_unlock.h"

#include <sddl.h>

#include <atomic>
#include <chrono>
#include <map>
#include <mutex>
#include <sstream>
#include <string>

using bleunlock_auto_unlock::Base64DecodeUtf8;
using bleunlock_auto_unlock::Base64EncodeUtf8;
using bleunlock_auto_unlock::BuildRequest;
using bleunlock_auto_unlock::DeleteCredentialFile;
using bleunlock_auto_unlock::FileExists;
using bleunlock_auto_unlock::ParseKeyValueLines;
using bleunlock_auto_unlock::ReadProtectedCredentialFile;
using bleunlock_auto_unlock::WriteProtectedCredentialFile;

namespace {

SERVICE_STATUS_HANDLE g_status_handle = nullptr;
SERVICE_STATUS g_status = {};
HANDLE g_stop_event = nullptr;
std::atomic<bool> g_stopping = false;

std::mutex g_grant_mutex;
std::chrono::system_clock::time_point g_grant_expires_at;
std::string g_grant_reason;

void SetServiceStatusState(DWORD state, DWORD win32_exit_code = NO_ERROR) {
    if (g_status_handle == nullptr) {
        return;
    }
    g_status.dwCurrentState = state;
    g_status.dwWin32ExitCode = win32_exit_code;
    g_status.dwControlsAccepted =
        state == SERVICE_RUNNING ? SERVICE_ACCEPT_STOP : 0;
    SetServiceStatus(g_status_handle, &g_status);
}

bool IsGrantActiveLocked() {
    return std::chrono::system_clock::now() < g_grant_expires_at;
}

bool IsGrantActive() {
    std::lock_guard<std::mutex> lock(g_grant_mutex);
    return IsGrantActiveLocked();
}

void ClearGrant() {
    std::lock_guard<std::mutex> lock(g_grant_mutex);
    g_grant_expires_at = {};
    g_grant_reason.clear();
}

std::string CredentialRecord(const std::string &username,
                             const std::string &domain,
                             const std::string &password) {
    return BuildRequest({
        {"domain", Base64EncodeUtf8(domain)},
        {"password", Base64EncodeUtf8(password)},
        {"username", Base64EncodeUtf8(username)},
    });
}

bool ReadCredentialRecord(std::string *username,
                          std::string *domain,
                          std::string *password,
                          bool *found,
                          DWORD *error_code) {
    std::string protected_text;
    if (!ReadProtectedCredentialFile(&protected_text, found, error_code)) {
        return false;
    }
    if (found != nullptr && !*found) {
        return true;
    }
    const auto values = ParseKeyValueLines(protected_text);
    const auto username_it = values.find("username");
    const auto domain_it = values.find("domain");
    const auto password_it = values.find("password");
    if (username_it == values.end() || password_it == values.end()) {
        if (error_code != nullptr) {
            *error_code = ERROR_INVALID_DATA;
        }
        return false;
    }
    std::string decoded_username;
    std::string decoded_domain;
    std::string decoded_password;
    if (!Base64DecodeUtf8(username_it->second, &decoded_username) ||
        !Base64DecodeUtf8(password_it->second, &decoded_password) ||
        (domain_it != values.end() &&
         !Base64DecodeUtf8(domain_it->second, &decoded_domain))) {
        if (error_code != nullptr) {
            *error_code = ERROR_INVALID_DATA;
        }
        return false;
    }
    *username = decoded_username;
    *domain = decoded_domain;
    *password = decoded_password;
    if (error_code != nullptr) {
        *error_code = ERROR_SUCCESS;
    }
    return true;
}

std::string ResponseOk(std::map<std::string, std::string> values = {}) {
    values["ok"] = "1";
    return BuildRequest(values);
}

std::string ResponseError(const std::string &error) {
    return BuildRequest({
        {"error", Base64EncodeUtf8(error)},
        {"ok", "0"},
    });
}

std::string HandleStatus() {
    bool found = false;
    std::string ignored_username;
    std::string ignored_domain;
    std::string ignored_password;
    DWORD error_code = ERROR_SUCCESS;
    const bool readable = ReadCredentialRecord(
        &ignored_username,
        &ignored_domain,
        &ignored_password,
        &found,
        &error_code);
    return ResponseOk({
        {"configured", readable && found ? "1" : "0"},
        {"credentialReadable", readable ? "1" : "0"},
        {"credentialStoreExists",
         FileExists(bleunlock_auto_unlock::CredentialStorePath()) ? "1" : "0"},
        {"grantActive", IsGrantActive() ? "1" : "0"},
        {"lastError", std::to_string(error_code)},
        {"service", "running"},
    });
}

std::string HandleSetCredential(
    const std::map<std::string, std::string> &request) {
    std::string username;
    std::string domain;
    std::string password;
    const auto username_it = request.find("username");
    const auto password_it = request.find("password");
    const auto domain_it = request.find("domain");
    if (username_it == request.end() || password_it == request.end() ||
        !Base64DecodeUtf8(username_it->second, &username) ||
        !Base64DecodeUtf8(password_it->second, &password) ||
        (domain_it != request.end() &&
         !Base64DecodeUtf8(domain_it->second, &domain))) {
        return ResponseError("bad credential request");
    }
    if (username.empty() || password.empty()) {
        return ResponseError("username and password are required");
    }

    DWORD error_code = ERROR_SUCCESS;
    if (!WriteProtectedCredentialFile(
            CredentialRecord(username, domain, password), &error_code)) {
        return ResponseError("credential save failed: " +
                             std::to_string(error_code));
    }
    ClearGrant();
    return ResponseOk({{"configured", "1"}});
}

std::string HandleDeleteCredential() {
    DWORD error_code = ERROR_SUCCESS;
    if (!DeleteCredentialFile(&error_code)) {
        return ResponseError("credential delete failed: " +
                             std::to_string(error_code));
    }
    ClearGrant();
    return ResponseOk({{"configured", "0"}});
}

std::string HandleGrantUnlock(
    const std::map<std::string, std::string> &request) {
    bool found = false;
    std::string ignored_username;
    std::string ignored_domain;
    std::string ignored_password;
    DWORD error_code = ERROR_SUCCESS;
    if (!ReadCredentialRecord(&ignored_username, &ignored_domain,
                              &ignored_password, &found, &error_code)) {
        return ResponseError("credential read failed: " +
                             std::to_string(error_code));
    }
    if (!found) {
        return ResponseError("credential is not configured");
    }

    int ttl_seconds = 30;
    const auto ttl_it = request.find("ttlSeconds");
    if (ttl_it != request.end()) {
        ttl_seconds = std::max(5, std::min(120, atoi(ttl_it->second.c_str())));
    }
    std::string reason;
    const auto reason_it = request.find("reason");
    if (reason_it != request.end()) {
        Base64DecodeUtf8(reason_it->second, &reason);
    }

    {
        std::lock_guard<std::mutex> lock(g_grant_mutex);
        g_grant_expires_at =
            std::chrono::system_clock::now() +
            std::chrono::seconds(ttl_seconds);
        g_grant_reason = reason;
    }
    return ResponseOk({
        {"grantActive", "1"},
        {"ttlSeconds", std::to_string(ttl_seconds)},
    });
}

std::string HandleConsumeCredential() {
    {
        std::lock_guard<std::mutex> lock(g_grant_mutex);
        if (!IsGrantActiveLocked()) {
            return ResponseError("no active unlock grant");
        }
        g_grant_expires_at = {};
    }

    bool found = false;
    std::string username;
    std::string domain;
    std::string password;
    DWORD error_code = ERROR_SUCCESS;
    if (!ReadCredentialRecord(&username, &domain, &password, &found,
                              &error_code)) {
        return ResponseError("credential read failed: " +
                             std::to_string(error_code));
    }
    if (!found) {
        return ResponseError("credential is not configured");
    }

    return ResponseOk({
        {"domain", Base64EncodeUtf8(domain)},
        {"password", Base64EncodeUtf8(password)},
        {"username", Base64EncodeUtf8(username)},
    });
}

std::string HandleRequest(const std::string &request_text) {
    const auto request = ParseKeyValueLines(request_text);
    const auto command_it = request.find("command");
    if (command_it == request.end()) {
        return ResponseError("missing command");
    }
    const auto &command = command_it->second;
    if (command == "status") {
        return HandleStatus();
    }
    if (command == "setCredential") {
        return HandleSetCredential(request);
    }
    if (command == "deleteCredential") {
        return HandleDeleteCredential();
    }
    if (command == "grantUnlock") {
        return HandleGrantUnlock(request);
    }
    if (command == "consumeCredential") {
        return HandleConsumeCredential();
    }
    return ResponseError("unknown command");
}

PSECURITY_DESCRIPTOR CreatePipeSecurityDescriptor() {
    PSECURITY_DESCRIPTOR descriptor = nullptr;
    ConvertStringSecurityDescriptorToSecurityDescriptorW(
        L"D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GRGW;;;IU)",
        SDDL_REVISION_1,
        &descriptor,
        nullptr);
    return descriptor;
}

void ServePipeLoop() {
    while (!g_stopping.load()) {
        PSECURITY_DESCRIPTOR descriptor = CreatePipeSecurityDescriptor();
        SECURITY_ATTRIBUTES attributes = {};
        attributes.nLength = sizeof(attributes);
        attributes.lpSecurityDescriptor = descriptor;
        attributes.bInheritHandle = FALSE;

        HANDLE pipe = CreateNamedPipeW(
            bleunlock_auto_unlock::kPipeName,
            PIPE_ACCESS_DUPLEX,
            PIPE_TYPE_MESSAGE | PIPE_READMODE_MESSAGE | PIPE_WAIT,
            PIPE_UNLIMITED_INSTANCES,
            8192,
            8192,
            3000,
            descriptor == nullptr ? nullptr : &attributes);
        if (descriptor != nullptr) {
            LocalFree(descriptor);
        }
        if (pipe == INVALID_HANDLE_VALUE) {
            Sleep(1000);
            continue;
        }

        const BOOL connected =
            ConnectNamedPipe(pipe, nullptr) ||
            GetLastError() == ERROR_PIPE_CONNECTED;
        if (!connected) {
            CloseHandle(pipe);
            continue;
        }

        char buffer[8192] = {};
        DWORD read = 0;
        std::string response = ResponseError("read failed");
        if (ReadFile(pipe, buffer, sizeof(buffer) - 1, &read, nullptr)) {
            response = HandleRequest(std::string(buffer, buffer + read));
        }
        DWORD written = 0;
        WriteFile(pipe, response.data(), static_cast<DWORD>(response.size()),
                  &written, nullptr);
        FlushFileBuffers(pipe);
        DisconnectNamedPipe(pipe);
        CloseHandle(pipe);
    }
}

DWORD WINAPI ServiceControlHandler(DWORD control,
                                   DWORD,
                                   LPVOID,
                                   LPVOID) {
    if (control == SERVICE_CONTROL_STOP) {
        g_stopping = true;
        SetServiceStatusState(SERVICE_STOP_PENDING);
        if (g_stop_event != nullptr) {
            SetEvent(g_stop_event);
        }
        return NO_ERROR;
    }
    return ERROR_CALL_NOT_IMPLEMENTED;
}

void WINAPI ServiceMain(DWORD, LPWSTR *) {
    g_status_handle = RegisterServiceCtrlHandlerExW(
        bleunlock_auto_unlock::kServiceName,
        ServiceControlHandler,
        nullptr);
    if (g_status_handle == nullptr) {
        return;
    }

    g_status.dwServiceType = SERVICE_WIN32_OWN_PROCESS;
    g_status.dwCurrentState = SERVICE_START_PENDING;
    g_status.dwControlsAccepted = 0;
    SetServiceStatusState(SERVICE_START_PENDING);

    g_stop_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    if (g_stop_event == nullptr) {
        SetServiceStatusState(SERVICE_STOPPED, GetLastError());
        return;
    }

    SetServiceStatusState(SERVICE_RUNNING);
    ServePipeLoop();
    CloseHandle(g_stop_event);
    g_stop_event = nullptr;
    SetServiceStatusState(SERVICE_STOPPED);
}

int RunConsole() {
    g_stop_event = CreateEventW(nullptr, TRUE, FALSE, nullptr);
    ServePipeLoop();
    if (g_stop_event != nullptr) {
        CloseHandle(g_stop_event);
        g_stop_event = nullptr;
    }
    return 0;
}

} // namespace

int wmain(int argc, wchar_t **argv) {
    if (argc > 1 && wcscmp(argv[1], L"--console") == 0) {
        return RunConsole();
    }

    SERVICE_TABLE_ENTRYW service_table[] = {
        {const_cast<LPWSTR>(bleunlock_auto_unlock::kServiceName), ServiceMain},
        {nullptr, nullptr},
    };
    if (!StartServiceCtrlDispatcherW(service_table)) {
        return static_cast<int>(GetLastError());
    }
    return 0;
}
