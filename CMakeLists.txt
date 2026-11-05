cmake_minimum_required(VERSION 3.12)
project(anticheat_bypass)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_C_STANDARD 99)

# Компилируем наш модуль вместе с исходником fishhook
add_library(bypass SHARED 
    main.cpp
    fishhook.c
)

# Настройки для компиляции под iOS dylib
set_target_properties(bypass PROPERTIES
    PREFIX ""
    SUFFIX ".dylib"
    LINK_FLAGS "-flat_namespace -undefined suppress"
)
