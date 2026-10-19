#include <unistd.h>
#include <cstdlib>
#include <dlfcn.h>
#include <string.h>
#include <mach-o/dyld.h>
#include "fishhook.h" // Упростил путь, чтобы компилятор нашел его в корне

static const char* (*orig_dyld_get_image_name)(uint32_t image_index);

const char* hook_dyld_get_image_name(uint32_t image_index) {
    const char* name = orig_dyld_get_image_name(image_index);
    if (name && strstr(name, "Card0zoESP.dylib")) {
        return "/usr/lib/libSystem.B.dylib"; 
    }
    return name;
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    struct rebinding rebindings[] = {
        {"_dyld_get_image_name", (void*)hook_dyld_get_image_name, (void**)&orig_dyld_get_image_name}
    };
    rebind_symbols(rebindings, 1);
}
