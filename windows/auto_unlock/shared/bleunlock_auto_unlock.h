#pragma once

#include <windows.h>

#include <map>
#include <string>
#include <vector>

namespace bleunlock_auto_unlock {

constexpr wchar_t kServiceName[] = L"BLEUnlockCredentialService";
constexpr wchar_t kServiceDisplayName[] = L"BLEUnlock Credential Service";
constexpr wchar_t kCredentialProviderClsidString[] =
    L"{6E7B7F2D-061A-4F29-8F6E-0F5C0D42C6B1}";
constexpr wchar_t kCredentialProviderDescription[] =
    L"BLEUnlock Credential Provider";
constexpr wchar_t kCredentialProviderRegistryPath[] =
    L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Authentication\\Credential Providers\\{6E7B7F2D-061A-4F29-8F6E-0F5C0D42C6B1}";
constexpr wchar_t kPipeName[] =
    L"\\\\.\\pipe\\BLEUnlockCredentialService";

struct PipeResponse {
    bool transport_ok = false;
    bool ok = false;
    DWORD error_code = ERROR_SUCCESS;
    std::string error_message;
    std::map<std::string, std::string> values;
};

std::wstring Utf8ToWide(const std::string &value);
std::string WideToUtf8(const std::wstring &value);

std::string BuildRequest(
    const std::map<std::string, std::string> &values);
std::map<std::string, std::string> ParseKeyValueLines(
    const std::string &text);

PipeResponse SendPipeRequest(const std::string &request,
                             DWORD timeout_millis = 3000);

std::string Base64Encode(const std::vector<BYTE> &bytes);
bool Base64Decode(const std::string &text, std::vector<BYTE> *bytes);
std::string Base64EncodeUtf8(const std::string &value);
bool Base64DecodeUtf8(const std::string &text, std::string *value);

std::wstring CredentialStorePath();
bool WriteProtectedCredentialFile(const std::string &plain_text,
                                  DWORD *error_code);
bool ReadProtectedCredentialFile(std::string *plain_text,
                                 bool *found,
                                 DWORD *error_code);
bool DeleteCredentialFile(DWORD *error_code);

bool EnsureCredentialStoreDirectory(DWORD *error_code);
bool FileExists(const std::wstring &path);

} // namespace bleunlock_auto_unlock
