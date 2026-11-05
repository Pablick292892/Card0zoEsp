#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <dlfcn.h>
#include <string.h>
#include "fishhook.h"

// Оригинальные указатели для exit / abort
static void (*original_exit)(int status) = NULL;
static void (*original_abort)(void) = NULL;

// Оригинальный указатель на метод показа UI-контроллеров
static void (*original_presentViewController)(id self, SEL _cmd, id viewControllerToPresent, BOOL flag, void (^completion)(void)) = NULL;

// Наш хук для перехвата показа модальных окон (UIAlertController)
void hooked_presentViewController(id self, SEL _cmd, id viewControllerToPresent, BOOL flag, void (^completion)(void)) {
    // Проверяем, является ли показываемое окно алертом
    if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
        NSString *title = alert.title;
        NSString *message = alert.message;
        
        // Если в заголовке или сообщении есть следы античита OXIDE / угрозы безопасности
        if ((title && ([title rangeOfString:@"OXIDE" options:NSCaseInsensitiveSearch].location != NSNotFound || 
                       [title rangeOfString:@"security" options:NSCaseInsensitiveSearch].location != NSNotFound)) ||
            (message && ([message rangeOfString:@"OXIDE" options:NSCaseInsensitiveSearch].location != NSNotFound || 
                         [message rangeOfString:@"threat" options:NSCaseInsensitiveSearch].location != NSNotFound))) {
            
            // Глушим показ этого окна на корню! Окно просто не появится, а игра продолжит жить.
            return;
        }
    }
    
    // Все остальные окна (меню, интерфейс игры) показываем штатно
    if (original_presentViewController) {
        original_presentViewController(self, _cmd, viewControllerToPresent, flag, completion);
    }
}

// Заглушки для exit и abort
void hooked_exit(int status) { return; }
void hooked_abort(void) { return; }

__attribute__((constructor)) void ui_shield_bypass() {
    // 1. Сброс флага cryptid для decrypted IPA
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

    // 2. Хукаем метод presentViewController через Objective-C Runtime
    Class uiViewControllerClass = objc_getClass("UIViewController");
    if (uiViewControllerClass) {
        SEL selector = sel_registerName("presentViewController:animated:completion:");
        Method method = class_getInstanceMethod(uiViewControllerClass, selector);
        if (method) {
            original_presentViewController = (void (*)(id, SEL, id, BOOL, void (^)(void)))method_setImplementation(method, (IMP)hooked_presentViewController);
        }
    }

    // 3. Дублируем страховку через fishhook для exit и abort
    struct rebinding rebindings[] = {
        { "exit",  (void*)hooked_exit,  (void**)&original_exit  },
        { "abort", (void*)hooked_abort, (void**)&original_abort }
    };
    rebind_symbols(rebindings, 2);
}
