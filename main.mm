#import <Foundation/Foundation.h>
#include <unistd.h>
#include <cstdlib>
#include <dlfcn.h>
#include <string.h>
#include "fishhook/fishhook.h"

// Хук CC_SHA256 из CommonCrypto
typedef void* (*CC_SHA256_t)(const void *data, unsigned int len, void *md);
static CC_SHA256_t orig_CC_SHA256 = NULL;

void* new_CC_SHA256(const void *data, unsigned int len, void *md) {
    // Вызываем оригинал
    orig_CC_SHA256(data, len, md);
    
    // Подменяем первые 4 байта хэша на нули (сбиваем проверку)
    if (md) {
        memset(md, 0, 4);
    }
    return md;
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    
    // Хукаем CC_SHA256
    struct rebinding sha256_rebinding = {"CC_SHA256", (void *)new_CC_SHA256, (void **)&orig_CC_SHA256};
    rebind_symbols((struct rebinding[1]){sha256_rebinding}, 1);
    
    NSLog(@"[Card0zo] Init loaded. SHA256 hooked.");
}
