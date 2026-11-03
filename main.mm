#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <dlfcn.h>
#include "dobby.h"

#define LIBLOADER_DISPATCH_OFFSET 0x04100

static void (*orig_dispatch)(void);

static void fake_dispatch(void) {
    // Ничего не делаем, просто выходим (возвращаем "успех")
}

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

    uintptr_t libloader_base = 0;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "libloader")) {
            libloader_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }

    if (libloader_base != 0) {
        void *target = (void *)(libloader_base + LIBLOADER_DISPATCH_OFFSET);
        DobbyHook(target, (void *)fake_dispatch, (void **)&orig_dispatch);
    }
}
