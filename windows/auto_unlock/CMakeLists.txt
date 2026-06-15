cmake_minimum_required(VERSION 3.20)
project(BLEUnlockWindowsAutoUnlock LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(bleunlock_auto_unlock_shared STATIC
  shared/bleunlock_auto_unlock.cpp
)
target_include_directories(bleunlock_auto_unlock_shared PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/shared
)
target_compile_definitions(bleunlock_auto_unlock_shared PRIVATE
  UNICODE
  _UNICODE
  NOMINMAX
)
target_link_libraries(bleunlock_auto_unlock_shared PUBLIC
  Advapi32
  Crypt32
)

add_executable(BLEUnlockCredentialService
  service/bleunlock_credential_service.cpp
)
target_compile_definitions(BLEUnlockCredentialService PRIVATE
  UNICODE
  _UNICODE
  NOMINMAX
)
target_link_libraries(BLEUnlockCredentialService PRIVATE
  bleunlock_auto_unlock_shared
  Advapi32
)

add_library(BLEUnlockCredentialProvider SHARED
  credential_provider/bleunlock_credential_provider.cpp
)
target_compile_definitions(BLEUnlockCredentialProvider PRIVATE
  UNICODE
  _UNICODE
  NOMINMAX
)
target_link_libraries(BLEUnlockCredentialProvider PRIVATE
  bleunlock_auto_unlock_shared
  Advapi32
  Credui
  Secur32
)
