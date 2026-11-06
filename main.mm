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

// 2. Интеллектуальный перехват модальных окон
void hooked_presentViewController(id self, SEL _cmd, id viewControllerToPresent, BOOL flag, void (^completion)(void)) {
    if (viewControllerToPresent) {
        Class vcClass = [viewControllerToPresent class];
        id classNameObj = ((id (*)(id, SEL))objc_msgSend)((id)vcClass, sel_registerName("description"));
        if (classNameObj) {
            const char *classNameUtf8 = [(NSString *)classNameObj UTF8String];
            if (classNameUtf8 && (strcasestr(classNameUtf8, "Alert") != NULL || strcasestr(classNameUtf8, "Security") != NULL)) {
                return; // Глушим показ окна угрозы безопасности OXIDE
            }
        }
    }
    if (original_presentViewController) {
        original_presentViewController(self, _cmd, viewControllerToPresent, flag, completion);
    }
}

// Функция скрытия загруженного образа из списков dyld (Stealth Mode)
static void hide_our_dylib() {
    uint32_t image_count = _dyld_image_count();
    for (uint32_t i = 0; i < image_count; i++) {
        const char *image_name = _dyld_get_image_name(i);
        if (image_name && strcasestr(image_name, "bypass") != NULL) {
            // Нашли наш образ в памяти. 
            // Пытаемся затереть имя или модифицировать указатели заголовка, 
            // чтобы сканеры античита по списку образов не смогли нас идентифицировать.
            Dl_info info;
            if (dladdr((void *)&hide_our_dylib, &info) != 0) {
                struct mach_header_64 *hdr = (struct mach_header_64 *)info.dli_fbase;
                if (hdr) {
                    // Обнуляем количество команд загрузки или маскируем майн-хедер для dyld-сканеров
                    // Превращаем секцию в «невидимую» для стандартных итераторов
                    uintptr_t page_size = sysconf(_SC_PAGESIZE);
                    if (mprotect((void *)((uintptr_t)hdr & ~(page_size - 1)), page_size, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                        hdr->ncmds = 0; // Сбиваем счетчик команд загрузки для внешних парсеров
                    }
                }
            }
            break;
        }
    }
}

__attribute__((constructor)) void impenetrable_shield_bypass() {
    // 0. Прячем модуль от сканеров dyld
    hide_our_dylib();

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

    // 3. Перехват метода показа контроллеров
    Class uiViewControllerClass = objc_getClass("UIViewController");
    if (uiViewControllerClass) {
        SEL selector = sel_registerName("presentViewController:animated:completion:");
        Method method = class_getInstanceMethod(uiViewControllerClass, selector);
        if (method) {
            original_presentViewController = (void (*)(id, SEL, id, BOOL, void (^)(void)))method_setImplementation(method, (IMP)hooked_presentViewController);
        }
    }
}
