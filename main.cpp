#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>
#include "fishhook.h"

// Указатель на оригинальную функцию системного сканера памяти
static kern_return_t (*original_mach_vm_region)(
    vm_map_t target_task, 
    mach_vm_address_t *address, 
    mach_vm_size_t *size, 
    vm_region_flavor_t flavor, 
    vm_region_info_t info, 
    mach_msg_type_number_t *count, 
    mach_port_t *object_name
) = NULL;

// Реальный перехватчик с подменой атрибутов памяти для античита
kern_return_t hooked_mach_vm_region(
    vm_map_t target_task, 
    mach_vm_address_t *address, 
    mach_vm_size_t *size, 
    vm_region_flavor_t flavor, 
    vm_region_info_t info, 
    mach_msg_type_number_t *count, 
    mach_port_t *object_name
) {
    if (!original_mach_vm_region) {
        return KERN_FAILURE;
    }

    // Вызываем оригинальный системный вызов ядра iOS
    kern_return_t result = original_mach_vm_region(target_task, address, size, flavor, info, count, object_name);

    if (result == KERN_SUCCESS && flavor == VM_REGION_BASIC_INFO_64) {
        vm_region_basic_info_64_t basic_info = (vm_region_basic_info_64_t)info;
        
        // Получаем базу главного модуля для точечной маскировки
        const struct mach_header* hdr = _dyld_get_image_header(0);
        intptr_t slide = _dyld_get_image_vmaddr_slide(0);
        if (hdr) {
            uintptr_t mod_start = (uintptr_t)hdr + slide;
            // Если античит проверяет наш диапазон памяти, где сделаны патчи, 
            // скрываем флаг записи (PROT_WRITE), чтобы сканер видел только честный Read/Execute
            if (*address >= mod_start && *address <= (mod_start + 0x100000)) {
                basic_info->protection &= ~VM_PROT_WRITE;
                basic_info->max_protection &= ~VM_PROT_WRITE;
            }
        }
    }

    return result;
}

__attribute__((constructor)) void enterprise_stealth_bypass() {
    // 1. Корректный сброс флага шифрования cryptid для decrypted IPA
    const struct mach_header_64* main_header = (const struct mach_header_64*)_dyld_get_image_header(0);
    if (main_header) {
        uint8_t* cursor = (uint8_t*)main_header + sizeof(struct mach_header_64);
        for (uint32_t i = 0; i < main_header->ncmds; i++) {
            struct load_command* lc = (struct load_command*)cursor;
            if (lc->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64* eic = (struct encryption_info_command_64*)lc;
                uintptr_t page_size = sysconf(_SC_PAGESIZE);
                if (mprotect((void*)((uintptr_t)&eic->cryptid & ~(page_size - 1)), page_size, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                    eic->cryptid = 0;
                }
            }
            cursor += lc->cmdsize;
        }
    }

    // 2. Интеграция реального хука через fishhook для подмены mach_vm_region
    struct rebinding rb = {
        .name = "mach_vm_region",
        .replacement = (void*)hooked_mach_vm_region,
        .replaced = (void**)&original_mach_vm_region
    };
    
    rebind_symbols(&rb, 1);
}
