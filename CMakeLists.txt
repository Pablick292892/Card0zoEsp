cmake_minimum_required(VERSION 3.10)
project(bypass)

# Указываем правильное расширение .mm для поддержки Objective-C++
add_library(bypass SHARED main.mm)

# Подключаем необходимые системные фреймворки iOS
target_link_libraries(bypass "-framework Foundation" "-framework UIKit")
