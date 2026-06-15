cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "bleunlock_windows")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "bleunlock_windows_plugin")

get_filename_component(BLEUNLOCK_WINDOWS_PLUGIN_DIR
  "${CMAKE_CURRENT_LIST_DIR}" REALPATH)
get_filename_component(BLEUNLOCK_REPO_ROOT
  "${BLEUNLOCK_WINDOWS_PLUGIN_DIR}/../../../.." ABSOLUTE)
set(BLEUNLOCK_AUTO_UNLOCK_SHARED_DIR
  "${BLEUNLOCK_REPO_ROOT}/windows/auto_unlock/shared")

add_library(${PLUGIN_NAME} SHARED
  "bleunlock_windows_plugin_c_api.cpp"
  "bleunlock_windows_plugin.cpp"
  "${BLEUNLOCK_AUTO_UNLOCK_SHARED_DIR}/bleunlock_auto_unlock.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)
target_compile_options(${PLUGIN_NAME} PRIVATE /utf-8)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}"
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)
target_include_directories(${PLUGIN_NAME} PRIVATE
  "${BLEUNLOCK_AUTO_UNLOCK_SHARED_DIR}"
)
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin runtimeobject windowsapp Advapi32 Crypt32 Shell32 User32 Wtsapi32)

set(bleunlock_windows_bundled_libraries
  ""
  PARENT_SCOPE
)
