cmake_minimum_required(VERSION 3.10)
project(bypass)

# Указываем оба файла для сборки нашей динамической библиотеки
add_library(bypass SHARED main.mm fishhook.c)

# Подключаем обязательный системный фреймворк
target_link_libraries(bypass "-framework Foundation")
