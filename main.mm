#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <dlfcn.h>
// Импортируем fishhook. Убедись, что файл fishhook.h лежит в папке "рыболовный крючок"
#import "fishhook.h" 

// Оригинальные функции
static uint32_t (*orig_dyld_image_count)(void);
static const char* (*orig_dyld_get_image_name)(uint32_t);

// Наша подмененная функция
static const char* fake_image_name(uint32_t index) {
    const char* name = orig_dyld_get_image_name(index);
    // Если игра запрашивает нашу dylib
    if (name && (strstr(name, "Card0zoEsp") || strstr(name, "Card0zoESP"))) {
        // Возвращаем имя системной, чтобы античит думал, что всё чисто
        return "/usr/lib/libSystem.B.dylib"; 
    }
    return name;
}

__attribute__((constructor))
static void init_hooks(void) {
    // Ждем 0.2 секунды для инициализации
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Используем стандартную структуру rebinding из fishhook.h
        struct rebinding rebinds[2];
        
        // Перехват получения имени
        rebinds[0].name = "_dyld_get_image_name";
        rebinds[0].replacement = (void *)fake_image_name;
        rebinds[0].replaced = (void **)&orig_dyld_get_image_name;
        
        // Перехват количества (оставляем как есть)
        rebinds[1].name = "_dyld_image_count";
        rebinds[1].replacement = (void *)orig_dyld_image_count;
        rebinds[1].replaced = (void **)&orig_dyld_image_count;
        
        rebind_symbols(rebinds, 2);
        
        NSLog(@"[TK-TEST] Хуки на dyld установлены! Мы невидимы.");
    });
}
