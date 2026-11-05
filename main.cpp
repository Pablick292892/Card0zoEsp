#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <string.h>

// Универсальный поиск базы нужного модуля по подстроке в имени
uintptr_t get_target_module_base(const char* target_name) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* image_name = _dyld_get_image_name(i);
        if (image_name && strstr(image_name, target_name)) {
            const struct mach_header* header = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            if (header) {
                return (uintptr_t)header + slide;
            }
        }
    }
    // Фоллбек на главный бинарник (индекс 0), если имя не найдено
    const struct mach_header* header = _dyld_get_image_header(0);
    intptr_t slide = _dyld_get_image_vmaddr_slide(0);
    return header ? (uintptr_t)header + slide : 0;
}

__attribute__((constructor)) void complete_bypass_from_a_to_z() {
    // 1. Сброс флага шифрования cryptid для decrypted IPA в главном бинарнике приложения
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

    // 2. Динамический выбор модуля античита (ищем libloader, при отсутствии — UnityFramework или главный бинарник)
    uintptr_t base = get_target_module_base("libloader");
    if (!base) {
        base = get_target_module_base("UnityFramework");
    }
    if (!base) {
        base = (uintptr_t)_dyld_get_image_header(0) + _dyld_get_image_vmaddr_slide(0);
    }
    if (!base) return;

    // 3. Безопасный точечный патч анти-тампера, сканера памяти и проверок хуков по точным смещениям
    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t target_page = (base + 0x4000) & ~(page_size - 1);
    
    if (mprotect((void*)target_page, page_size * 4, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
        uintptr_t offsets[] = {
            0x4530, 0x4544, 0x41ec, 0x4264, 0x4304, 0x4478
        };

        for (int i = 0; i < 6; i++) {
            *(uint32_t*)(base + offsets[i]) = 0xD503201F; // ARM64 NOP инструкция
        }
    }
}
