#include "bleunlock_auto_unlock.h"

#include <wincrypt.h>

#include <algorithm>
#include <sstream>

namespace bleunlock_auto_unlock {
namespace {

constexpr wchar_t kProgramDataSubdir[] = L"BLEUnlock";
constexpr wchar_t kCredentialFileName[] = L"windows-auto-unlock.dat";

std::string TrimAscii(const std::string &value) {
    const auto first = value.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) {
        return "";
    }
    const auto last = value.find_last_not_of(" \t\r\n");
    return value.substr(first, last - first + 1);
}

std::wstring ProgramDataDirectory() {
    wchar_t buffer[MAX_PATH] = {};
    const auto length = GetEnvironmentVariableW(L"ProgramData", buffer,
                                                static_cast<DWORD>(MAX_PATH));
    if (length > 0 && length < MAX_PATH) {
        std::wstring value(buffer, buffer + length);
        if (!value.empty()) {
            return value + L"\\" + kProgramDataSubdir;
        }
    }
    return L"C:\\ProgramData\\BLEUnlock";
}

bool ReadFileFully(const std::wstring &path,
                   std::vector<BYTE> *bytes,
                   DWORD *error_code) {
    bytes->clear();
    HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        if (error_code != nullptr) {
            *error_code = GetLastError();
        }
        return false;
    }

    LARGE_INTEGER size = {};
    if (!GetFileSizeEx(file, &size) || size.QuadPart < 0 ||
        size.QuadPart > 1024 * 1024) {
        if (error_code != nullptr) {
            *error_code = GetLastError();
        }
        CloseHandle(file);
        return false;
    }

    bytes->resize(static_cast<size_t>(size.QuadPart));
    DWORD read = 0;
    const bool ok = bytes->empty() ||
                    ReadFile(file, bytes->data(),
                             static_cast<DWORD>(bytes->size()), &read,
                             nullptr);
    CloseHandle(file);
    if (!ok || read != bytes->size()) {
        if (error_code != nullptr) {
            *error_code = ok ? ERROR_READ_FAULT : GetLastError();
        }
        bytes->clear();
        return false;
    }
    if (error_code != nullptr) {
        *error_code = ERROR_SUCCESS;
    }
    return true;
}

bool WriteFileFully(const std::wstring &path,
                    const std::vector<BYTE> &bytes,
                    DWORD *error_code) {
    HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, 0, nullptr,
                              CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) {
        if (error_code != nullptr) {
            *error_code = GetLastError();
        }
        return false;
    }

    DWORD written = 0;
    const bool ok = bytes.empty() ||
                    WriteFile(file, bytes.data(),
                              static_cast<DWORD>(bytes.size()), &written,
                              nullptr);
    CloseHandle(file);
    if (!ok || written != bytes.size()) {
        if (error_code != nullptr) {
            *error_code = ok ? ERROR_WRITE_FAULT : GetLastError();
        }
        return false;
    }
    if (error_code != nullptr) {
        *error_code = ERROR_SUCCESS;
    }
    return true;
}

} // namespace

std::wstring Utf8ToWide(const std::string &value) {
    if (value.empty()) {
        return std::wstring();
    }
    const int length = MultiByteToWideChar(CP_UTF8, 0, value.data(),
                                           static_cast<int>(value.size()),
                                           nullptr, 0);
    if (length <= 0) {
        return std::wstring();
    }
    std::wstring result(static_cast<size_t>(length), L'\0');
    MultiByteToWideChar(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), length);
    return result;
}

std::string WideToUtf8(const std::wstring &value) {
    if (value.empty()) {
        return std::string();
    }
    const int length = WideCharToMultiByte(CP_UTF8, 0, value.data(),
                                           static_cast<int>(value.size()),
                                           nullptr, 0, nullptr, nullptr);
    if (length <= 0) {
        return std::string();
    }
    std::string result(static_cast<size_t>(length), '\0');
    WideCharToMultiByte(CP_UTF8, 0, value.data(),
                        static_cast<int>(value.size()), result.data(), length,
                        nullptr, nullptr);
    return result;
}

std::string BuildRequest(
    const std::map<std::string, std::string> &values) {
    std::ostringstream stream;
    stream << "protocol=1\n";
    for (const auto &entry : values) {
        stream << entry.first << "=" << entry.second << "\n";
    }
    return stream.str();
}

std::map<std::string, std::string> ParseKeyValueLines(
    const std::string &text) {
    std::map<std::string, std::string> values;
    std::istringstream stream(text);
    std::string line;
    while (std::getline(stream, line)) {
        line = TrimAscii(line);
        if (line.empty()) {
            continue;
        }
        const auto separator = line.find('=');
        if (separator == std::string::npos) {
            continue;
        }
        values[TrimAscii(line.substr(0, separator))] =
            TrimAscii(line.substr(separator + 1));
    }
    return values;
}

PipeResponse SendPipeRequest(const std::string &request,
                             DWORD timeout_millis) {
    PipeResponse response;
    if (!WaitNamedPipeW(kPipeName, timeout_millis)) {
        response.error_code = GetLastError();
        response.error_message = "Credential service pipe is unavailable";
        return response;
    }

    HANDLE pipe = CreateFileW(kPipeName, GENERIC_READ | GENERIC_WRITE, 0,
                              nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
    if (pipe == INVALID_HANDLE_VALUE) {
        response.error_code = GetLastError();
        response.error_message = "Credential service pipe open failed";
        return response;
    }

    DWORD written = 0;
    const bool wrote = WriteFile(pipe, request.data(),
                                 static_cast<DWORD>(request.size()), &written,
                                 nullptr);
    if (!wrote || written != request.size()) {
        response.error_code = wrote ? ERROR_WRITE_FAULT : GetLastError();
        response.error_message = "Credential service pipe write failed";
        CloseHandle(pipe);
        return response;
    }

    char buffer[8192] = {};
    DWORD read = 0;
    const bool read_ok = ReadFile(pipe, buffer, sizeof(buffer) - 1, &read,
                                  nullptr);
    CloseHandle(pipe);
    if (!read_ok) {
        response.error_code = GetLastError();
        response.error_message = "Credential service pipe read failed";
        return response;
    }

    response.transport_ok = true;
    response.values = ParseKeyValueLines(std::string(buffer, buffer + read));
    response.ok = response.values["ok"] == "1";
    response.error_message = response.values["error"];
    return response;
}

std::string Base64Encode(const std::vector<BYTE> &bytes) {
    if (bytes.empty()) {
        return "";
    }
    DWORD length = 0;
    if (!CryptBinaryToStringA(bytes.data(), static_cast<DWORD>(bytes.size()),
                              CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                              nullptr, &length)) {
        return "";
    }
    std::string result(length, '\0');
    if (!CryptBinaryToStringA(bytes.data(), static_cast<DWORD>(bytes.size()),
                              CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF,
                              result.data(), &length)) {
        return "";
    }
    while (!result.empty() && result.back() == '\0') {
        result.pop_back();
    }
    return result;
}

bool Base64Decode(const std::string &text, std::vector<BYTE> *bytes) {
    bytes->clear();
    if (text.empty()) {
        return true;
    }
    DWORD length = 0;
    if (!CryptStringToBinaryA(text.c_str(), static_cast<DWORD>(text.size()),
                              CRYPT_STRING_BASE64, nullptr, &length, nullptr,
                              nullptr)) {
        return false;
    }
    bytes->resize(length);
    if (!CryptStringToBinaryA(text.c_str(), static_cast<DWORD>(text.size()),
                              CRYPT_STRING_BASE64, bytes->data(), &length,
                              nullptr, nullptr)) {
        bytes->clear();
        return false;
    }
    bytes->resize(length);
    return true;
}

std::string Base64EncodeUtf8(const std::string &value) {
    return Base64Encode(std::vector<BYTE>(value.begin(), value.end()));
}

bool Base64DecodeUtf8(const std::string &text, std::string *value) {
    std::vector<BYTE> bytes;
    if (!Base64Decode(text, &bytes)) {
        return false;
    }
    *value = std::string(bytes.begin(), bytes.end());
    return true;
}

std::wstring CredentialStorePath() {
    return ProgramDataDirectory() + L"\\" + kCredentialFileName;
}

bool EnsureCredentialStoreDirectory(DWORD *error_code) {
    const auto directory = ProgramDataDirectory();
    if (CreateDirectoryW(directory.c_str(), nullptr)) {
        if (error_code != nullptr) {
            *error_code = ERROR_SUCCESS;
        }
        return true;
    }
    const auto error = GetLastError();
    if (error == ERROR_ALREADY_EXISTS) {
        if (error_code != nullptr) {
            *error_code = ERROR_SUCCESS;
        }
        return true;
    }
    if (error_code != nullptr) {
        *error_code = error;
    }
    return false;
}

bool WriteProtectedCredentialFile(const std::string &plain_text,
                                  DWORD *error_code) {
    DWORD directory_error = ERROR_SUCCESS;
    if (!EnsureCredentialStoreDirectory(&directory_error)) {
        if (error_code != nullptr) {
            *error_code = directory_error;
        }
        return false;
    }

    DATA_BLOB input = {};
    input.pbData = reinterpret_cast<BYTE *>(
        const_cast<char *>(plain_text.data()));
    input.cbData = static_cast<DWORD>(plain_text.size());
    DATA_BLOB output = {};
    if (!CryptProtectData(&input, L"BLEUnlock Windows Auto Unlock", nullptr,
                          nullptr, nullptr, CRYPTPROTECT_LOCAL_MACHINE,
                          &output)) {
        if (error_code != nullptr) {
            *error_code = GetLastError();
        }
        return false;
    }

    std::vector<BYTE> encrypted(output.pbData, output.pbData + output.cbData);
    LocalFree(output.pbData);
    return WriteFileFully(CredentialStorePath(), encrypted, error_code);
}

bool ReadProtectedCredentialFile(std::string *plain_text,
                                 bool *found,
                                 DWORD *error_code) {
    plain_text->clear();
    if (found != nullptr) {
        *found = false;
    }

    std::vector<BYTE> encrypted;
    DWORD read_error = ERROR_SUCCESS;
    if (!ReadFileFully(CredentialStorePath(), &encrypted, &read_error)) {
        if (read_error == ERROR_FILE_NOT_FOUND ||
            read_error == ERROR_PATH_NOT_FOUND) {
            if (error_code != nullptr) {
                *error_code = ERROR_SUCCESS;
            }
            return true;
        }
        if (error_code != nullptr) {
            *error_code = read_error;
        }
        return false;
    }

    DATA_BLOB input = {};
    input.pbData = encrypted.data();
    input.cbData = static_cast<DWORD>(encrypted.size());
    DATA_BLOB output = {};
    if (!CryptUnprotectData(&input, nullptr, nullptr, nullptr, nullptr, 0,
                            &output)) {
        if (error_code != nullptr) {
            *error_code = GetLastError();
        }
        return false;
    }

    plain_text->assign(reinterpret_cast<const char *>(output.pbData),
                       reinterpret_cast<const char *>(output.pbData) +
                           output.cbData);
    LocalFree(output.pbData);
    if (found != nullptr) {
        *found = true;
    }
    if (error_code != nullptr) {
        *error_code = ERROR_SUCCESS;
    }
    return true;
}

bool DeleteCredentialFile(DWORD *error_code) {
    if (DeleteFileW(CredentialStorePath().c_str())) {
        if (error_code != nullptr) {
            *error_code = ERROR_SUCCESS;
        }
        return true;
    }
    const auto error = GetLastError();
    if (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) {
        if (error_code != nullptr) {
            *error_code = ERROR_SUCCESS;
        }
        return true;
    }
    if (error_code != nullptr) {
        *error_code = error;
    }
    return false;
}

bool FileExists(const std::wstring &path) {
    const auto attributes = GetFileAttributesW(path.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES &&
           (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

} // namespace bleunlock_auto_unlock
