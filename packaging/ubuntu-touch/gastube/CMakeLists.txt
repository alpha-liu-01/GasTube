cmake_minimum_required(VERSION 3.10)
project(gastube_click NONE)

set(BUNDLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/bundle")
if(NOT EXISTS "${BUNDLE_DIR}/gastube")
  message(FATAL_ERROR "Prebuilt Flutter bundle is missing: ${BUNDLE_DIR}/gastube")
endif()

configure_file(manifest.json.in manifest.json COPYONLY)
configure_file(gastube.apparmor.in gastube.apparmor COPYONLY)
configure_file(gastube.desktop.in gastube.desktop COPYONLY)
configure_file(gastube.png gastube.png COPYONLY)

install(DIRECTORY "${BUNDLE_DIR}/" DESTINATION . USE_SOURCE_PERMISSIONS)
install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/manifest.json"
  "${CMAKE_CURRENT_BINARY_DIR}/gastube.apparmor"
  "${CMAKE_CURRENT_BINARY_DIR}/gastube.desktop"
  "${CMAKE_CURRENT_BINARY_DIR}/gastube.png"
  DESTINATION .
)
