#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>

// Функция, которая выполнится при загрузке чита
__attribute__((constructor))
void Init() {
    // Очищаем переменные, чтобы античит не спалил инжект
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    
    // Здесь позже мы вызовем Titanox, чтобы он спрятал наш dylib из списка
}
