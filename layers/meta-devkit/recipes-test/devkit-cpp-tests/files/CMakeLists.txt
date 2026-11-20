cmake_minimum_required(VERSION 3.16)
project(devkit_cpp_tests VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Catch2 3 REQUIRED)
find_package(fmt REQUIRED)
find_package(spdlog REQUIRED)

add_executable(devkit-cpp-tests test.cpp)
target_link_libraries(devkit-cpp-tests PRIVATE Catch2::Catch2WithMain fmt::fmt spdlog::spdlog)
target_compile_options(devkit-cpp-tests PRIVATE -Wall -Wextra -Wpedantic)

include(CTest)
add_test(NAME devkit-cpp-tests COMMAND devkit-cpp-tests)
install(TARGETS devkit-cpp-tests RUNTIME DESTINATION bin)
