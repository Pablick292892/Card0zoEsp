#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <string.h>
#import "fishhook/fishhook.h"

// Оригинальные функции
static uint32_t (*orig_dyld_image_count)(void);
static const char* (*orig_dyld_get_image_name)(uint32_t);
static const struct mach_header* (*orig_dyld_get_image_header)(uint32_t);

// Наша функция (подменяет имя)
static const char* fake_dyld_get_image_name(uint32_t index) {
    const char* name = orig_dyld_get_image_name(index);
    if (name && strstr(name, "Card0zoESP")) {
        return "/usr/lib/libSystem.B.dylib"; // Подсовываем системную
    }
    return name;
}

// Патч cryptid (обход 927)
static void patch_cryptid() {
    const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
    if (!header) return;
    const struct load_command *cmd = (const struct load_command *)(header + 1);
    for (uint32_t i = 0; i < header->ncmds; i++) {
        if (cmd->cmd == LC_ENCRYPTION_INFO_64) {
            struct encryption_info_command_64 *info = (struct encryption_info_command_64 *)cmd;
            if (info->cryptid == 0) {
                vm_protect(mach_task_self(), (vm_address_t)info, sizeof(*info), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                info->cryptid = 1;
            }
        }
        cmd = (const struct load_command *)((uint8_t *)cmd + cmd->cmdsize);
    }
}

__attribute__((constructor))
static void init_hooks(void) {
    patch_cryptid();
    
    // Хукаем только функцию имени
    struct rebinding rebinds[1];
    rebinds[0].name = "_dyld_get_image_name";
    rebinds[0].replacement = (void *)fake_dyld_get_image_name;
    rebinds[0].replaced = (void **)&orig_dyld_get_image_name;
    
    rebind_symbols(rebinds, 1);
}
