#import <stdint.h>
#import <unistd.h>
#import <sys/mman.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <signal.h>
#import <dlfcn.h>
#import <string.h>
#import <Foundation/Foundation.h>
#include "fishhook.h"

// Оригинальные указатели для перехвата
static int (*original_kill)(pid_t pid, int sig) = NULL;
static void (*original_exit)(int status) = NULL;
static void (*original_abort)(void) = NULL;
static void (*original_presentViewController)(id self, SEL _cmd, id viewControllerToPresent, BOOL flag, void (^completion)(void)) = NULL;

// 1. Безопасные хуки для глушения завершения процесса
int hooked_kill(pid_t pid, int sig) {
    if (pid == getpid() && (sig == SIGKILL || sig == SIGABRT || sig == SIGTERM)) {
        return 0; // Игнорируем попытку убить процесс изнутри
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

// 2. Интеллектуальный перехват модальных окон (уничтожаем алерт OXIDE на подлете)
void hooked_presentViewController(id self, SEL _cmd, id viewControllerToPresent, BOOL flag, void (^completion)(void)) {
    if (viewControllerToPresent) {
        Class vcClass = [viewControllerToPresent class];
        id classNameObj = ((id (*)(id, SEL))objc_msgSend)((id)vcClass, sel_registerName("description"));
        if (classNameObj) {
            const char *classNameUtf8 = [(NSString *)classNameObj UTF8String];
            if (classNameUtf8 && (strcasestr(classNameUtf8, "Alert") != NULL || strcasestr(classNameUtf8, "Security") != NULL)) {
                return; // Глушим показ окна угрозы безопасности OXIDE на корню!
            }
        }
    }
    if (original_presentViewController) {
        original_presentViewController(self, _cmd, viewControllerToPresent, flag, completion);
    }
}

__attribute__((constructor)) void impenetrable_shield_bypass() {
    // 1. Сброс cryptid для decrypted IPA
    const struct mach_header_64* target_hdr = (const struct mach_header_64*)_dyld_get_image_header(0);
    if (target_hdr) {
        uint8_t* cursor = (uint8_t*)target_hdr + sizeof(struct mach_header_64);
        for (uint32_t i = 0; i < target_hdr->ncmds; i++) {
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

    // 2. Перехват через fishhook (exit, abort, kill)
    struct rebinding rebindings[] = {
        { "exit",  (void*)hooked_exit,  (void**)&original_exit  },
        { "abort", (void*)hooked_abort, (void**)&original_abort },
        { "kill",  (void*)hooked_kill,  (void**)&original_kill  }
    };
    rebind_symbols(rebindings, 3);

    // 3. Перехват метода показа контроллеров (UIViewController -> presentViewController:animated:completion:)
    Class uiViewControllerClass = objc_getClass("UIViewController");
    if (uiViewControllerClass) {
        SEL selector = sel_registerName("presentViewController:animated:completion:");
        Method method = class_getInstanceMethod(uiViewControllerClass, selector);
        if (method) {
            original_presentViewController = (void (*)(id, SEL, id, BOOL, void (^)(void)))method_setImplementation(method, (IMP)hooked_presentViewController);
        }
    }
}
