# Project-level configuration.
cmake_minimum_required(VERSION 3.14)

# Export compile_commands.json so that clangd/IDE can index the C++ sources
# with the exact include paths and flags used by the real Flutter build.
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

project(qisheng_player LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "qisheng_player")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  # Keep warnings visible without promoting them to errors. Use unquoted MSVC
  # warning switches so both Visual Studio and Ninja receive valid arguments.
  target_compile_options(${TARGET} PRIVATE /W4 /wd4100 /utf-8 /wd4819)
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
# Resolve real plugin paths from .flutter-plugins-dependencies in case Windows
# ProcessRedirectionTrustPolicy blocks traversal of .plugin_symlinks (ERROR_UNTRUSTED_MOUNT_POINT / 0x800701C0).
set(FLUTTER_PLUGINS_DEP_FILE "${CMAKE_CURRENT_SOURCE_DIR}/../.flutter-plugins-dependencies")
if(EXISTS "${FLUTTER_PLUGINS_DEP_FILE}")
  file(READ "${FLUTTER_PLUGINS_DEP_FILE}" _PLUGINS_JSON)
  string(JSON _WINDOWS_PLUGINS_LEN ERROR_VARIABLE _JSON_ERR LENGTH "${_PLUGINS_JSON}" "plugins" "windows")
  if(NOT _JSON_ERR AND _WINDOWS_PLUGINS_LEN GREATER 0)
    math(EXPR _STOP "${_WINDOWS_PLUGINS_LEN} - 1")
    foreach(_IDX RANGE 0 ${_STOP})
      string(JSON _P_NAME GET "${_PLUGINS_JSON}" "plugins" "windows" ${_IDX} "name")
      string(JSON _P_PATH GET "${_PLUGINS_JSON}" "plugins" "windows" ${_IDX} "path")
      file(TO_CMAKE_PATH "${_P_PATH}windows" _NORMALIZED_P_PATH)
      if(EXISTS "${_NORMALIZED_P_PATH}/CMakeLists.txt")
        set(FLUTTER_PLUGIN_REAL_DIR_${_P_NAME} "${_NORMALIZED_P_PATH}")
      endif()
    endforeach()
  endif()
endif()

macro(add_subdirectory dir)
  set(_ADD_SUBDIR_TARGET "${dir}")
  if("${_ADD_SUBDIR_TARGET}" MATCHES "flutter/ephemeral/\\.plugin_symlinks/([^/]+)/windows")
    set(_PLUGIN_NAME "${CMAKE_MATCH_1}")
    if(DEFINED FLUTTER_PLUGIN_REAL_DIR_${_PLUGIN_NAME})
      if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${dir}")
        set(_ADD_SUBDIR_TARGET "${FLUTTER_PLUGIN_REAL_DIR_${_PLUGIN_NAME}}")
      endif()
    endif()
  endif()
  _add_subdirectory("${_ADD_SUBDIR_TARGET}" ${ARGN})
endmacro()

include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# Copy optional local BASS runtime binaries into the app folder.
# Put required dlls under <repo>/BASS (not committed) for local development.
set(BASS_SOURCE_DIR "${CMAKE_SOURCE_DIR}/../BASS")
if(EXISTS "${BASS_SOURCE_DIR}/bass.dll")
  install(DIRECTORY "${BASS_SOURCE_DIR}/"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}/BASS"
    COMPONENT Runtime
    FILES_MATCHING PATTERN "*.dll")
else()
  message(WARNING "BASS runtime dlls not found at ${BASS_SOURCE_DIR}. Playback features will be unavailable.")
endif()
