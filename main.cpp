#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <dlfcn.h>
#include <string.h>
#include "fishhook.h"

// Оригинальные указатели
static void (*original_exit)(int status) = NULL;
static void (*original_abort)(void) = NULL;

// Проверка источника вызова (чтобы игра штатно закрывалась из меню, но игнорировала античит)
static bool is_from_anticheat() {
    void* return_address = __builtin_return_address(2);
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* img_name = _dyld_get_image_name(i);
        if (img_name && (strstr(img_name, "OXIDE") || strstr(img_name, "libloader"))) {
            const struct mach_header* hdr = _dyld_get_image_header(i);
            intptr_t slide = _dyld_get_image_vmaddr_slide(i);
            if (hdr) {
                uintptr_t start = (uintptr_t)hdr + slide;
                if ((uintptr_t)return_address >= start && (uintptr_t)return_address <= (start + 0x500000)) {
                    return true;
                }
            }
        }
    }
    return false;
}

// Безопасный перехватчик exit
void hooked_exit(int status) {
    if (is_from_anticheat()) {
        // Гасим попытку античита прибить приложение при детекте, предотвращая фриз
        return; 
    }
    if (original_exit) original_exit(status);
}

// Безопасный перехватчик abort
void hooked_abort(void) {
    if (is_from_anticheat()) {
        // Игнорируем аварийный сброс от OXIDE
        return; 
    }
    if (original_abort) original_abort();
}

// Обработчик сигналов ОС (перехват SIGABRT, чтобы игра не падала по сигналу ядра)
void handle_sigabrt(int sig, siginfo_t *info, void *context) {
    // Если сигнал пришел от античита, перехватываем и глушим его
    // Это защищает от зависания UI и принудительного закрытия
}

__attribute__((constructor)) void external_shield_bypass() {
    // 1. Сброс cryptid для decrypted IPA
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

    // 2. Ребиндинг функций завершения через fishhook
    struct rebinding rebindings[] = {
        { "exit",  (void*)hooked_exit,  (void**)&original_exit  },
        { "abort", (void*)hooked_abort, (void**)&original_abort }
    };
    rebind_symbols(rebindings, 2);

    // 3. Установка перехвата сигналов на случай низкоуровневого сброса
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = handle_sigabrt;
    sa.sa_flags = SA_SIGINFO;
    sigaction(SIGABRT, &sa, NULL);
}
