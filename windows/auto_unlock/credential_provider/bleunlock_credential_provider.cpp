#include "../shared/bleunlock_auto_unlock.h"

#include <credentialprovider.h>
#include <ntsecapi.h>
#include <wincred.h>

#include <atomic>
#include <map>
#include <string>

using bleunlock_auto_unlock::Base64DecodeUtf8;
using bleunlock_auto_unlock::Base64EncodeUtf8;
using bleunlock_auto_unlock::BuildRequest;
using bleunlock_auto_unlock::PipeResponse;
using bleunlock_auto_unlock::SendPipeRequest;
using bleunlock_auto_unlock::Utf8ToWide;

namespace {

const CLSID CLSID_BLEUnlockCredentialProvider = {
    0x6e7b7f2d,
    0x061a,
    0x4f29,
    {0x8f, 0x6e, 0x0f, 0x5c, 0x0d, 0x42, 0xc6, 0xb1}};

enum FieldId {
    kFieldTitle = 0,
    kFieldSubtitle = 1,
    kFieldCount = 2,
};

HMODULE g_module = nullptr;
std::atomic<long> g_object_count = 0;
std::atomic<long> g_lock_count = 0;

PWSTR CoAllocString(const std::wstring &value) {
    const auto bytes = (value.size() + 1) * sizeof(wchar_t);
    auto *result = static_cast<PWSTR>(CoTaskMemAlloc(bytes));
    if (result == nullptr) {
        return nullptr;
    }
    memcpy(result, value.c_str(), bytes);
    return result;
}

HRESULT DuplicateString(const std::wstring &value, PWSTR *target) {
    if (target == nullptr) {
        return E_POINTER;
    }
    *target = CoAllocString(value);
    return *target == nullptr ? E_OUTOFMEMORY : S_OK;
}

HRESULT FieldDescriptor(DWORD field_id,
                        CREDENTIAL_PROVIDER_FIELD_TYPE type,
                        const std::wstring &label,
                        CREDENTIAL_PROVIDER_FIELD_DESCRIPTOR **descriptor) {
    if (descriptor == nullptr) {
        return E_POINTER;
    }
    *descriptor = static_cast<CREDENTIAL_PROVIDER_FIELD_DESCRIPTOR *>(
        CoTaskMemAlloc(sizeof(CREDENTIAL_PROVIDER_FIELD_DESCRIPTOR)));
    if (*descriptor == nullptr) {
        return E_OUTOFMEMORY;
    }
    ZeroMemory(*descriptor, sizeof(CREDENTIAL_PROVIDER_FIELD_DESCRIPTOR));
    (*descriptor)->dwFieldID = field_id;
    (*descriptor)->cpft = type;
    (*descriptor)->pszLabel = CoAllocString(label);
    if ((*descriptor)->pszLabel == nullptr) {
        CoTaskMemFree(*descriptor);
        *descriptor = nullptr;
        return E_OUTOFMEMORY;
    }
    return S_OK;
}

bool HasActiveGrant() {
    const auto response = SendPipeRequest(BuildRequest({{"command", "status"}}));
    return response.transport_ok && response.ok &&
           response.values["configured"] == "1" &&
           response.values["grantActive"] == "1";
}

HRESULT RetrieveNegotiateAuthPackage(ULONG *auth_package) {
    HANDLE lsa = nullptr;
    NTSTATUS status = LsaConnectUntrusted(&lsa);
    if (status != STATUS_SUCCESS) {
        return HRESULT_FROM_NT(status);
    }

    LSA_STRING package_name = {};
    const char negotiate[] = "Negotiate";
    package_name.Buffer = const_cast<PCHAR>(negotiate);
    package_name.Length = static_cast<USHORT>(strlen(negotiate));
    package_name.MaximumLength = package_name.Length + 1;

    status = LsaLookupAuthenticationPackage(lsa, &package_name, auth_package);
    LsaDeregisterLogonProcess(lsa);
    return status == STATUS_SUCCESS ? S_OK : HRESULT_FROM_NT(status);
}

struct ConsumedCredential {
    std::wstring username;
    std::wstring password;
};

HRESULT ConsumeCredential(ConsumedCredential *credential) {
    const auto response = SendPipeRequest(
        BuildRequest({{"command", "consumeCredential"}}));
    if (!response.transport_ok) {
        return HRESULT_FROM_WIN32(response.error_code);
    }
    if (!response.ok) {
        return HRESULT_FROM_WIN32(ERROR_LOGON_FAILURE);
    }

    std::string username;
    std::string domain;
    std::string password;
    if (!Base64DecodeUtf8(response.values["username"], &username) ||
        !Base64DecodeUtf8(response.values["password"], &password)) {
        return HRESULT_FROM_WIN32(ERROR_INVALID_DATA);
    }
    const auto domain_it = response.values.find("domain");
    if (domain_it != response.values.end()) {
        Base64DecodeUtf8(domain_it->second, &domain);
    }

    std::string principal = username;
    if (!domain.empty() && username.find('\\') == std::string::npos &&
        username.find('@') == std::string::npos) {
        principal = domain + "\\" + username;
    }
    credential->username = Utf8ToWide(principal);
    credential->password = Utf8ToWide(password);
    if (credential->username.empty() || credential->password.empty()) {
        return HRESULT_FROM_WIN32(ERROR_INVALID_DATA);
    }
    return S_OK;
}

class BLEUnlockCredential final : public ICredentialProviderCredential {
  public:
    BLEUnlockCredential() { g_object_count += 1; }
    ~BLEUnlockCredential() override { g_object_count -= 1; }

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                             void **object) override {
        if (object == nullptr) {
            return E_POINTER;
        }
        if (riid == IID_IUnknown ||
            riid == IID_ICredentialProviderCredential) {
            *object = static_cast<ICredentialProviderCredential *>(this);
            AddRef();
            return S_OK;
        }
        *object = nullptr;
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
        return static_cast<ULONG>(InterlockedIncrement(&ref_count_));
    }

    ULONG STDMETHODCALLTYPE Release() override {
        const auto count = InterlockedDecrement(&ref_count_);
        if (count == 0) {
            delete this;
        }
        return static_cast<ULONG>(count);
    }

    HRESULT STDMETHODCALLTYPE
    Advise(ICredentialProviderCredentialEvents *) override {
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE UnAdvise() override { return S_OK; }

    HRESULT STDMETHODCALLTYPE SetSelected(BOOL *auto_logon) override {
        if (auto_logon != nullptr) {
            *auto_logon = TRUE;
        }
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE SetDeselected() override { return S_OK; }

    HRESULT STDMETHODCALLTYPE GetFieldState(
        DWORD field_id,
        CREDENTIAL_PROVIDER_FIELD_STATE *state,
        CREDENTIAL_PROVIDER_FIELD_INTERACTIVE_STATE *interactive_state)
        override {
        if (state == nullptr || interactive_state == nullptr) {
            return E_POINTER;
        }
        if (field_id >= kFieldCount) {
            return E_INVALIDARG;
        }
        *state = CPFS_DISPLAY_IN_SELECTED_TILE;
        *interactive_state = CPFIS_NONE;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetStringValue(DWORD field_id,
                                             PWSTR *value) override {
        switch (field_id) {
            case kFieldTitle:
                return DuplicateString(L"BLEUnlock", value);
            case kFieldSubtitle:
                return DuplicateString(
                    L"Trusted device authorized automatic unlock", value);
            default:
                return E_INVALIDARG;
        }
    }

    HRESULT STDMETHODCALLTYPE GetBitmapValue(DWORD, HBITMAP *) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE GetCheckboxValue(DWORD, BOOL *, PWSTR *) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE GetSubmitButtonValue(DWORD, DWORD *) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE GetComboBoxValueCount(DWORD,
                                                   DWORD *,
                                                   DWORD *) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE GetComboBoxValueAt(DWORD,
                                                DWORD,
                                                PWSTR *) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE SetStringValue(DWORD, PCWSTR) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE SetCheckboxValue(DWORD, BOOL) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE SetComboBoxSelectedValue(DWORD, DWORD) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE CommandLinkClicked(DWORD) override {
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE GetSerialization(
        CREDENTIAL_PROVIDER_GET_SERIALIZATION_RESPONSE *response,
        CREDENTIAL_PROVIDER_CREDENTIAL_SERIALIZATION *serialization,
        PWSTR *status_text,
        CREDENTIAL_PROVIDER_STATUS_ICON *status_icon) override {
        if (response == nullptr || serialization == nullptr) {
            return E_POINTER;
        }
        if (status_text != nullptr) {
            *status_text = nullptr;
        }
        if (status_icon != nullptr) {
            *status_icon = CPSI_NONE;
        }
        ZeroMemory(serialization, sizeof(*serialization));

        ConsumedCredential credential;
        HRESULT hr = ConsumeCredential(&credential);
        if (FAILED(hr)) {
            *response = CPGSR_NO_CREDENTIAL_NOT_FINISHED;
            if (status_text != nullptr) {
                DuplicateString(L"BLEUnlock authorization is not available",
                                status_text);
            }
            if (status_icon != nullptr) {
                *status_icon = CPSI_ERROR;
            }
            return S_OK;
        }

        DWORD packed_size = 0;
        if (!CredPackAuthenticationBufferW(
                0,
                const_cast<PWSTR>(credential.username.c_str()),
                const_cast<PWSTR>(credential.password.c_str()),
                nullptr,
                &packed_size) &&
            GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
            return HRESULT_FROM_WIN32(GetLastError());
        }

        auto *packed = static_cast<BYTE *>(CoTaskMemAlloc(packed_size));
        if (packed == nullptr) {
            return E_OUTOFMEMORY;
        }
        if (!CredPackAuthenticationBufferW(
                0,
                const_cast<PWSTR>(credential.username.c_str()),
                const_cast<PWSTR>(credential.password.c_str()),
                packed,
                &packed_size)) {
            const auto error = GetLastError();
            CoTaskMemFree(packed);
            return HRESULT_FROM_WIN32(error);
        }

        ULONG auth_package = 0;
        hr = RetrieveNegotiateAuthPackage(&auth_package);
        if (FAILED(hr)) {
            CoTaskMemFree(packed);
            return hr;
        }

        serialization->ulAuthenticationPackage = auth_package;
        serialization->clsidCredentialProvider =
            CLSID_BLEUnlockCredentialProvider;
        serialization->cbSerialization = packed_size;
        serialization->rgbSerialization = packed;
        *response = CPGSR_RETURN_CREDENTIAL_FINISHED;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE ReportResult(NTSTATUS,
                                          NTSTATUS,
                                          PWSTR *,
                                          CREDENTIAL_PROVIDER_STATUS_ICON *)
        override {
        return S_OK;
    }

  private:
    long ref_count_ = 1;
};

class BLEUnlockProvider final : public ICredentialProvider {
  public:
    BLEUnlockProvider() { g_object_count += 1; }
    ~BLEUnlockProvider() override { g_object_count -= 1; }

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                             void **object) override {
        if (object == nullptr) {
            return E_POINTER;
        }
        if (riid == IID_IUnknown || riid == IID_ICredentialProvider) {
            *object = static_cast<ICredentialProvider *>(this);
            AddRef();
            return S_OK;
        }
        *object = nullptr;
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
        return static_cast<ULONG>(InterlockedIncrement(&ref_count_));
    }

    ULONG STDMETHODCALLTYPE Release() override {
        const auto count = InterlockedDecrement(&ref_count_);
        if (count == 0) {
            delete this;
        }
        return static_cast<ULONG>(count);
    }

    HRESULT STDMETHODCALLTYPE SetUsageScenario(
        CREDENTIAL_PROVIDER_USAGE_SCENARIO scenario,
        DWORD) override {
        if (scenario == CPUS_LOGON || scenario == CPUS_UNLOCK_WORKSTATION) {
            usage_scenario_ = scenario;
            return S_OK;
        }
        return E_NOTIMPL;
    }

    HRESULT STDMETHODCALLTYPE SetSerialization(
        const CREDENTIAL_PROVIDER_CREDENTIAL_SERIALIZATION *) override {
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE Advise(ICredentialProviderEvents *,
                                    UINT_PTR) override {
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE UnAdvise() override { return S_OK; }

    HRESULT STDMETHODCALLTYPE GetFieldDescriptorCount(DWORD *count) override {
        if (count == nullptr) {
            return E_POINTER;
        }
        *count = kFieldCount;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetFieldDescriptorAt(
        DWORD field_id,
        CREDENTIAL_PROVIDER_FIELD_DESCRIPTOR **descriptor) override {
        switch (field_id) {
            case kFieldTitle:
                return FieldDescriptor(field_id, CPFT_LARGE_TEXT,
                                       L"BLEUnlock", descriptor);
            case kFieldSubtitle:
                return FieldDescriptor(field_id, CPFT_SMALL_TEXT,
                                       L"Automatic unlock", descriptor);
            default:
                return E_INVALIDARG;
        }
    }

    HRESULT STDMETHODCALLTYPE GetCredentialCount(DWORD *count,
                                                DWORD *default_credential,
                                                BOOL *auto_logon) override {
        if (count == nullptr || default_credential == nullptr ||
            auto_logon == nullptr) {
            return E_POINTER;
        }
        const bool active = usage_scenario_ != CPUS_INVALID && HasActiveGrant();
        *count = active ? 1 : 0;
        *default_credential =
            active ? 0 : CREDENTIAL_PROVIDER_NO_DEFAULT;
        *auto_logon = active ? TRUE : FALSE;
        return S_OK;
    }

    HRESULT STDMETHODCALLTYPE GetCredentialAt(
        DWORD index,
        ICredentialProviderCredential **credential) override {
        if (credential == nullptr) {
            return E_POINTER;
        }
        if (index != 0) {
            return E_INVALIDARG;
        }
        auto *item = new (std::nothrow) BLEUnlockCredential();
        if (item == nullptr) {
            return E_OUTOFMEMORY;
        }
        *credential = item;
        return S_OK;
    }

  private:
    long ref_count_ = 1;
    CREDENTIAL_PROVIDER_USAGE_SCENARIO usage_scenario_ = CPUS_INVALID;
};

class BLEUnlockClassFactory final : public IClassFactory {
  public:
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid,
                                             void **object) override {
        if (object == nullptr) {
            return E_POINTER;
        }
        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *object = static_cast<IClassFactory *>(this);
            AddRef();
            return S_OK;
        }
        *object = nullptr;
        return E_NOINTERFACE;
    }

    ULONG STDMETHODCALLTYPE AddRef() override {
        return static_cast<ULONG>(InterlockedIncrement(&ref_count_));
    }

    ULONG STDMETHODCALLTYPE Release() override {
        const auto count = InterlockedDecrement(&ref_count_);
        if (count == 0) {
            delete this;
        }
        return static_cast<ULONG>(count);
    }

    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown *outer,
                                            REFIID riid,
                                            void **object) override {
        if (outer != nullptr) {
            return CLASS_E_NOAGGREGATION;
        }
        auto *provider = new (std::nothrow) BLEUnlockProvider();
        if (provider == nullptr) {
            return E_OUTOFMEMORY;
        }
        const HRESULT hr = provider->QueryInterface(riid, object);
        provider->Release();
        return hr;
    }

    HRESULT STDMETHODCALLTYPE LockServer(BOOL lock) override {
        g_lock_count += lock ? 1 : -1;
        return S_OK;
    }

  private:
    long ref_count_ = 1;
};

HRESULT SetRegistryString(HKEY root,
                          const std::wstring &path,
                          const std::wstring &name,
                          const std::wstring &value) {
    HKEY key = nullptr;
    LSTATUS status = RegCreateKeyExW(root, path.c_str(), 0, nullptr, 0,
                                     KEY_WRITE, nullptr, &key, nullptr);
    if (status != ERROR_SUCCESS) {
        return HRESULT_FROM_WIN32(status);
    }
    status = RegSetValueExW(
        key,
        name.empty() ? nullptr : name.c_str(),
        0,
        REG_SZ,
        reinterpret_cast<const BYTE *>(value.c_str()),
        static_cast<DWORD>((value.size() + 1) * sizeof(wchar_t)));
    RegCloseKey(key);
    return HRESULT_FROM_WIN32(status);
}

std::wstring ModulePath() {
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(g_module, path, MAX_PATH);
    return path;
}

} // namespace

extern "C" BOOL WINAPI DllMain(HINSTANCE instance,
                               DWORD reason,
                               LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_module = instance;
        DisableThreadLibraryCalls(instance);
    }
    return TRUE;
}

extern "C" HRESULT __stdcall DllGetClassObject(REFCLSID clsid,
                                               REFIID riid,
                                               void **object) {
    if (clsid != CLSID_BLEUnlockCredentialProvider) {
        return CLASS_E_CLASSNOTAVAILABLE;
    }
    auto *factory = new (std::nothrow) BLEUnlockClassFactory();
    if (factory == nullptr) {
        return E_OUTOFMEMORY;
    }
    const HRESULT hr = factory->QueryInterface(riid, object);
    factory->Release();
    return hr;
}

extern "C" HRESULT __stdcall DllCanUnloadNow() {
    return g_object_count.load() == 0 && g_lock_count.load() == 0 ? S_OK
                                                                  : S_FALSE;
}

extern "C" HRESULT __stdcall DllRegisterServer() {
    const std::wstring clsid =
        bleunlock_auto_unlock::kCredentialProviderClsidString;
    HRESULT hr = SetRegistryString(
        HKEY_CLASSES_ROOT,
        L"CLSID\\" + clsid,
        L"",
        bleunlock_auto_unlock::kCredentialProviderDescription);
    if (FAILED(hr)) {
        return hr;
    }
    hr = SetRegistryString(HKEY_CLASSES_ROOT,
                           L"CLSID\\" + clsid + L"\\InprocServer32",
                           L"",
                           ModulePath());
    if (FAILED(hr)) {
        return hr;
    }
    hr = SetRegistryString(HKEY_CLASSES_ROOT,
                           L"CLSID\\" + clsid + L"\\InprocServer32",
                           L"ThreadingModel",
                           L"Apartment");
    if (FAILED(hr)) {
        return hr;
    }
    return SetRegistryString(
        HKEY_LOCAL_MACHINE,
        bleunlock_auto_unlock::kCredentialProviderRegistryPath,
        L"",
        bleunlock_auto_unlock::kCredentialProviderDescription);
}

extern "C" HRESULT __stdcall DllUnregisterServer() {
    const std::wstring clsid =
        bleunlock_auto_unlock::kCredentialProviderClsidString;
    RegDeleteTreeW(HKEY_LOCAL_MACHINE,
                   bleunlock_auto_unlock::kCredentialProviderRegistryPath);
    RegDeleteTreeW(HKEY_CLASSES_ROOT, (L"CLSID\\" + clsid).c_str());
    return S_OK;
}
