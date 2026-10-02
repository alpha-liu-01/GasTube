cmake_minimum_required(VERSION 3.10)
project(hello_click NONE)

set(BUNDLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bundle")
if(NOT EXISTS "${BUNDLE_DIR}/hello")
  message(FATAL_ERROR "Prebuilt Flutter bundle is missing: ${BUNDLE_DIR}/hello")
endif()

configure_file(manifest.json.in manifest.json COPYONLY)
configure_file(hello.apparmor.in hello.apparmor COPYONLY)
configure_file(hello.desktop.in hello.desktop COPYONLY)
configure_file(hello.png hello.png COPYONLY)

install(DIRECTORY "${BUNDLE_DIR}/" DESTINATION . USE_SOURCE_PERMISSIONS)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/manifest.json"
  "${CMAKE_CURRENT_BINARY_DIR}/hello.apparmor"
  "${CMAKE_CURRENT_BINARY_DIR}/hello.desktop"
  "${CMAKE_CURRENT_BINARY_DIR}/hello.png"
  DESTINATION .
)
