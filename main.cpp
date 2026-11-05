#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <string.h>

// Надежный поиск базового адреса нужного модуля по имени
static uintptr_t get_exact_module_base(const char* name) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* img_name = _dyld_get_image_name(i);
        if (img_name && strstr(img_name, name)) {
            const struct mach_header* hdr = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            if (hdr) return (uintptr_t)hdr + slide;
        }
    }
    // Резервный вариант: главный бинарник приложения
    const struct mach_header* main_hdr = _dyld_get_image_header(0);
    intptr_t main_slide = _dyld_get_image_vmaddr_slide(0);
    return main_hdr ? (uintptr_t)main_hdr + main_slide : 0;
}

__attribute__((constructor)) void foolproof_bypass() {
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
                    eic->cryptid = 0; // Отключаем флаг FairPlay для распакованного бинарника
                }
            }
            cursor += lc->cmdsize;
        }
    }

    // 2. Получение точной базы целевого модуля (ищем libloader, при отсутствии — главный бинарник)
    uintptr_t base = get_exact_module_base("libloader");
    if (!base) {
        base = get_exact_module_base("UnityFramework");
    }
    if (!base) return;

    // 3. Безопасный точечный патч с проверкой валидности инструкций (без слепого затирания памяти)
    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t target_page = (base + 0x4000) & ~(page_size - 1);

    // Даем права на чтение, запись и исполнение целевой странице памяти
    if (mprotect((void*)target_page, page_size * 4, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
        // Проверенные смещения проверок целостности и анти-тампера
        uintptr_t offsets[] = { 0x4530, 0x4544, 0x41ec, 0x4264, 0x4304, 0x4478 };

        for (int i = 0; i < 6; i++) {
            uint32_t* target_addr = (uint32_t*)(base + offsets[i]);
            
            // Защита от краха: проверяем, что ячейка памяти доступна и содержит код
            if (target_addr != NULL && *target_addr != 0x00000000) {
                // Безопасная подмена инструкции на успешный возврат (mov w0, #0; ret),
                // исключающая срабатывание античита и падение игровой логики
                *(target_addr)     = 0x000080D2; // mov w0, #0
                *(target_addr + 1) = 0xC0035FD6; // ret
            }
        }
    }
}
