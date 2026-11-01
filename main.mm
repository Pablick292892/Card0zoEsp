#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <fishhook/fishhook.h>

// Оригинальные функции
static kern_return_t (*orig_mach_vm_read_overwrite)(vm_map_t, vm_address_t, vm_size_t, vm_address_t, vm_size_t *);
static const struct mach_header_64* (*orig_dyld_get_image_header)(uint32_t);

// 1. Патчим заголовок, чтобы cryptid был 1
static const struct mach_header_64* fake_get_image_header(uint32_t index) {
    const struct mach_header_64* header = orig_dyld_get_image_header(index);
    if (header && index == 0) {
        struct mach_header_64 *h64 = (struct mach_header_64 *)header;
        const struct load_command *cmd = (const struct load_command *)(h64 + 1);
        for (uint32_t i = 0; i < h64->ncmds; i++) {
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
    return header;
}

// 2. Хукаем чтение памяти (mach_vm_read_overwrite)
static kern_return_t fake_mach_vm_read_overwrite(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize) {
    // Если античит пытается читать память, мы просто отдаем нули (или ошибку)
    // Или возвращаем KERN_INVALID_ADDRESS, чтобы он думал, что память недоступна
    if (outsize) *outsize = 0;
    return KERN_INVALID_ADDRESS; 
}

__attribute__((constructor))
static void init_hooks(void) {
    // Мгновенный патч cryptid
    orig_dyld_get_image_header = dlsym(RTLD_DEFAULT, "_dyld_get_image_header");
    if (orig_dyld_get_image_header) {
        fake_get_image_header(0);
    }

    // Хукаем чтение памяти через fishhook
    struct rebinding rebinds[2];
    
    rebinds[0].name = "mach_vm_read_overwrite";
    rebinds[0].replacement = (void *)fake_mach_vm_read_overwrite;
    rebinds[0].replaced = (void **)&orig_mach_vm_read_overwrite;

    // Также подменяем dyld заголовок
    rebinds[1].name = "_dyld_get_image_header";
    rebinds[1].replacement = (void *)fake_get_image_header;
    rebinds[1].replaced = (void **)&orig_dyld_get_image_header;

    rebind_symbols(rebinds, 2);
}
