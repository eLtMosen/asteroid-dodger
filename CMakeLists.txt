cmake_minimum_required(VERSION 3.5)
project(asteroid-dodger LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt5 COMPONENTS Core Qml Quick REQUIRED)
find_package(AsteroidApp REQUIRED)

file(GLOB QML_FILES "*.qml")
file(GLOB IMG_FILES "usr/share/asteroid-launcher/watchfaces-img/*")

add_executable(asteroid-dodger main.cpp resources.qrc ${QML_FILES} ${IMG_FILES})

target_link_libraries(asteroid-dodger PRIVATE
    Qt5::Core
    Qt5::Qml
    Qt5::Quick
    AsteroidApp)

install(TARGETS asteroid-dodger DESTINATION /usr/bin/)
install(DIRECTORY usr/share/asteroid-launcher/watchfaces-img
        DESTINATION /usr/share/asteroid-launcher/)
install(FILES asteroid-dodger.desktop
        DESTINATION /usr/share/applications/)

set(CPACK_GENERATOR "AsteroidIPK")
set(CPACK_PACKAGE_NAME "asteroid-dodger")
set(CPACK_PACKAGE_VERSION "1.0")
include(CPack)
