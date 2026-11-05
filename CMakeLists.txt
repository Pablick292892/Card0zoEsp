cmake_minimum_required(VERSION 3.12)
project(anticheat_bypass)

set(CMAKE_CXX_STANDARD 17)
add_library(bypass SHARED main.cpp)

set_target_properties(bypass PROPERTIES
    PREFIX ""
    SUFFIX ".dylib"
    LINK_FLAGS "-flat_namespace -undefined suppress"
)
