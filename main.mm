#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach.h>

__attribute__((constructor))
static void init_patch(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Получаем заголовок главного бинаря игры
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
        if (!header) return;

        // Ищем сегмент шифрования и меняем флаг на 1 (типа зашифровано)
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
    });
}
