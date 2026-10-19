#include <unistd.h>
#include <cstdlib>
#include <dlfcn.h>
#include <sys/stat.h>
#include <string.h>
#include <stdio.h>
#include <objc/runtime.h>
#include <mach/mach.h>
#include "fishhook/fishhook.h"

#pragma mark - Memory Patching Utils (IL2CPP Scanner)

#define ARM64_RET 0xD65F03C0

void patch_memory(uintptr_t address, void *data, size_t len) {
    uintptr_t page = address & ~0xFFF;
    mach_vm_protect(mach_task_self(), page, 0x1000, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    memcpy((void *)address, data, len);
    mach_vm_protect(mach_task_self(), page, 0x1000, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
}

uintptr_t find_function_prologue(uintptr_t addr) {
    // Ищем стандартный пролог ARM64: STP X29, X30, [SP, #-imm]!
    for (int i = 0; i < 0x200; i += 4) {
        uint32_t instruction = *(uint32_t *)(addr - i);
        if ((instruction & 0xFFC003FF) == 0xA90003FD) {
            return addr - i;
        }
    }
    return 0;
}

void bypass_oxide_detection() {
    const char *target_string = "OXIDE detected";
    size_t str_len = strlen(target_string);
    
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "GameAssembly.dylib")) {
            uintptr_t base = (uintptr_t)_dyld_get_image_header(i);
            uintptr_t current = base;
            uintptr_t end = base + 0x10000000; // Сканируем первые 256MB (__TEXT сегмент)
            
            while (current < end) {
                if (memcmp((void *)current, target_string, str_len) == 0) {
                    uintptr_t func_start = find_function_prologue(current);
                    if (func_start != 0) {
                        uint32_t ret_instr = ARM64_RET;
                        patch_memory(func_start, &ret_instr, 4);
                        printf("[Card0zo] IL2CPP Detection bypassed at: 0x%lx\n", func_start);
                        return; // Вышли после успешного патча
                    }
                }
                current += 4;
            }
            break;
        }
    }
    printf("[Card0zo] Detection string not found or already patched.\n");
}

#pragma mark - Fishhook & System Hooks

static int (*orig_access)(const char *pathname, int mode);
int new_access(const char *pathname, int mode) {
    if (strstr(pathname, "/Applications/Cydia.app") || strstr(pathname, "/bin/bash") || 
        strstr(pathname, "/usr/sbin/sshd") || strstr(pathname, "/etc/apt") || 
        strstr(pathname, "/var/lib/cydia") || strstr(pathname, "/MobileSubstrate") || 
        strstr(pathname, "/Substitute") || strstr(pathname, "frida")) {
        errno = ENOENT;
        return -1;
    }
    return orig_access(pathname, mode);
}

static int (*orig_stat)(const char *pathname, struct stat *statbuf);
int new_stat(const char *pathname, struct stat *statbuf) {
    if (strstr(pathname, "/Applications/Cydia.app") || strstr(pathname, "/bin/bash") || 
        strstr(pathname, "/usr/sbin/sshd")) {
        errno = ENOENT;
        return -1;
    }
    return orig_stat(pathname, statbuf);
}

static int (*orig_open)(const char *pathname, int flags, ...);
int new_open(const char *pathname, int flags, ...) {
    if (strstr(pathname, "/Applications/Cydia.app") || strstr(pathname, "/bin/bash") || 
        strstr(pathname, "/usr/sbin/sshd") || strstr(pathname, "/Substitute")) {
        errno = ENOENT;
        return -1;
    }
    return orig_open(pathname, flags);
}

#pragma mark - UIKit Alert Block

static IMP orig_presentViewController;
void new_presentViewController(id self, SEL _cmd, id viewControllerToPresent, BOOL animated, id completion) {
    if ([viewControllerToPresent isKindOfClass:NSClassFromString(@"UIAlertController")]) {
        NSString *title = [viewControllerToPresent valueForKey:@"title"];
        NSString *message = [viewControllerToPresent valueForKey:@"message"];
        
        if ((title && [title containsString:@"OXIDE"]) || 
            (message && [message containsString:@"security threat"])) {
            NSLog(@"[Card0zo] Blocked native security alert!");
            if (completion) ((void(*)(id, SEL, id))completion)(nil, nil);
            return;
        }
    }
    orig_presentViewController(self, _cmd, viewControllerToPresent, animated, completion);
}

#pragma mark - Entry Point

__attribute__((constructor))
void Init() {
    // 1. Очистка окружения от следов инъекции (eSign / dyld)
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    // 2. Fishhook ребайндинг системных вызовов
    struct rebinding access_rebinding = {"access", new_access, (void *)&orig_access};
    struct rebinding stat_rebinding = {"stat", new_stat, (void *)&orig_stat};
    struct rebinding open_rebinding = {"open", new_open, (void *)&orig_open};
    rebind_symbols((struct rebinding[3]){access_rebinding, stat_rebinding, open_rebinding}, 3);

    // 3. Хук UIKit алертов
    Class UIViewControllerClass = NSClassFromString(@"UIViewController");
    if (UIViewControllerClass) {
        Method method = class_getInstanceMethod(UIViewControllerClass, @selector(presentViewController:animated:completion:));
        orig_presentViewController = method_setImplementation(method, (IMP)new_presentViewController);
    }
    
    NSLog(@"[Card0zo] Init loaded. Hooks active.");

    // 4. Запускаем сканер IL2CPP в фоне через 3 секунды, чтобы GameAssembly точно загрузился
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        bypass_oxide_detection();
    });
}
