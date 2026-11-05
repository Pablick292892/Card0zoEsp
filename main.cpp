#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <signal.h>
#include <dlfcn.h>
#include <string.h>
#include "fishhook.h"

// Оригинальные указатели
static int (*original_kill)(pid_t pid, int sig) = NULL;
static void (*original_exit)(int status) = NULL;
static void (*original_abort)(void) = NULL;
static void (*original_addSubview)(id self, SEL _cmd, id view) = NULL;

// 1. Реализация хуков (обязательно ДО вызова rebind_symbols)
int hooked_kill(pid_t pid, int sig) {
    if (pid == getpid() && (sig == SIGKILL || sig == SIGABRT || sig == SIGTERM)) {
        return 0; // Игнорируем попытку убить процесс
    }
    if (original_kill) {
        return original_kill(pid, sig);
    }
    return -1;
}

void hooked_exit(int status) {
    return; // Глушим штатный exit
}

void hooked_abort(void) {
    return; // Глушим аварийный abort
}

void hooked_addSubview(id self, SEL _cmd, id view) {
    if (view && [NSStringFromClass([view class]) rangeOfString:@"Alert" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return; // Глушим показ кастомных алертов античита
    }
    if (original_addSubview) {
        original_addSubview(self, _cmd, view);
    }
}

__attribute__((constructor)) void impenetrable_shield_bypass() {
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

    // 2. Перехват через fishhook (exit, abort, kill) теперь видит все функции
    struct rebinding rebindings[] = {
        { "exit",  (void*)hooked_exit,  (void**)&original_exit  },
        { "abort", (void*)hooked_abort, (void**)&original_abort },
        { "kill",  (void*)hooked_kill,  (void**)&original_kill  }
    };
    rebind_symbols(rebindings, 3);

    // 3. Перехват на уровне UIView (addSubview) для борьбы с кастомными окнами алертов
    Class uiViewClass = objc_getClass("UIView");
    if (uiViewClass) {
        SEL selector = sel_registerName("addSubview:");
        Method method = class_getInstanceMethod(uiViewClass, selector);
        if (method) {
            original_addSubview = (void (*)(id, SEL, id))method_setImplementation(method, (IMP)hooked_addSubview);
        }
    }
}
