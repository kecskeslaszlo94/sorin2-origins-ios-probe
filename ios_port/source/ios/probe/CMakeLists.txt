cmake_minimum_required(VERSION 3.24)
if(NOT CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    message(FATAL_ERROR "OriginsIOSProbe requires macOS and Xcode with an iOS SDK.")
endif()
if(NOT CMAKE_GENERATOR STREQUAL "Xcode" OR NOT CMAKE_SYSTEM_NAME STREQUAL "iOS")
    message(FATAL_ERROR "Use the Xcode generator with CMAKE_SYSTEM_NAME=iOS.")
endif()
if(NOT CMAKE_OSX_ARCHITECTURES STREQUAL "arm64")
    message(FATAL_ERROR "Only explicit arm64 builds are supported by this probe.")
endif()
if(NOT CMAKE_OSX_SYSROOT MATCHES "^(iphoneos|iphonesimulator)$")
    message(FATAL_ERROR "Set CMAKE_OSX_SYSROOT to iphoneos or iphonesimulator.")
endif()
if(NOT DEFINED CMAKE_OSX_DEPLOYMENT_TARGET)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "15.0" CACHE STRING "Minimum supported iOS")
endif()
if(NOT CMAKE_OSX_DEPLOYMENT_TARGET MATCHES "^[0-9]+\\.[0-9]+$" OR CMAKE_OSX_DEPLOYMENT_TARGET VERSION_LESS "15.0")
    message(FATAL_ERROR "The probe requires an explicit iOS minimum version of 15.0 or newer.")
endif()

project(OriginsIOSProbe VERSION 0.1.0 LANGUAGES OBJCXX)
set(PROBE_EXECUTABLE "OriginsIOSProbe")
configure_file(Info.plist.in "${CMAKE_CURRENT_BINARY_DIR}/Info.plist" @ONLY)
add_executable(OriginsIOSProbe MACOSX_BUNDLE main.mm)
set_target_properties(OriginsIOSProbe PROPERTIES
    OBJCXX_STANDARD 17
    OBJCXX_STANDARD_REQUIRED YES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_BINARY_DIR}/Info.plist"
    MACOSX_BUNDLE_GUI_IDENTIFIER "eu.sorin2.origins.iosprobe"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "eu.sorin2.origins.iosprobe"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1"
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC "YES"
    XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO"
    XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY ""
    XCODE_ATTRIBUTE_GENERATE_INFOPLIST_FILE "NO"
    XCODE_ATTRIBUTE_ENABLE_BITCODE "NO"
    XCODE_ATTRIBUTE_SUPPORTS_MACCATALYST "NO"
)
target_compile_options(OriginsIOSProbe PRIVATE -fobjc-arc)
target_link_libraries(OriginsIOSProbe PRIVATE "-framework UIKit" "-framework Metal")
