# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "rust_lib_coriander_player")
project(${PROJECT_NAME} LANGUAGES CXX)

include("../cargokit/cmake/cargokit.cmake")
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../rust/Cargo.toml")
  set(RUST_DIR "../../rust")
elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../rust/Cargo.toml")
  set(RUST_DIR "../../../../../../rust")
else()
  message(FATAL_ERROR "Cannot find rust directory containing Cargo.toml")
endif()
apply_cargokit(${PROJECT_NAME} ${RUST_DIR} rust_lib_coriander_player "")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(rust_lib_coriander_player_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
