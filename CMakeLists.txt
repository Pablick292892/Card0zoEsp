cmake_minimum_required(VERSION 3.10)
project(bypass)

# Указываем сборку динамической библиотеки из нашего модуля маскировки и fishhook
add_library(bypass SHARED main.mm fishhook.c)

# Подключаем обязательный системный фреймворк Foundation
target_link_libraries(bypass "-framework Foundation")
