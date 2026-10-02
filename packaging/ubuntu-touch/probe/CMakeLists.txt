cmake_minimum_required(VERSION 3.10)
project(probe LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED IMPORTED_TARGET gtk+-3.0)

add_executable(probe src/main.cpp)
pkg_check_modules(EGL REQUIRED IMPORTED_TARGET egl)
pkg_check_modules(GLES2 REQUIRED IMPORTED_TARGET glesv2)

target_link_libraries(probe PRIVATE PkgConfig::GTK3 PkgConfig::EGL PkgConfig::GLES2)

configure_file(manifest.json.in manifest.json COPYONLY)
configure_file(probe.apparmor.in probe.apparmor COPYONLY)
configure_file(probe.desktop.in probe.desktop COPYONLY)
configure_file(probe.png probe.png COPYONLY)

install(TARGETS probe RUNTIME DESTINATION .)
install(FILES
  ${CMAKE_CURRENT_BINARY_DIR}/manifest.json
  ${CMAKE_CURRENT_BINARY_DIR}/probe.apparmor
  ${CMAKE_CURRENT_BINARY_DIR}/probe.desktop
  ${CMAKE_CURRENT_BINARY_DIR}/probe.png
  DESTINATION .
)
