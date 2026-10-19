#import <Foundation/Foundation.h>
#include <unistd.h>
#include <cstdlib>
#include <dlfcn.h>
#include <sys/stat.h>
#include <string.h>
#include <stdio.h>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <objc/runtime.h>
#include <errno.h>
#include "fishhook/fishhook.h"

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

// УБРАЛИ open — он variadic и может крашить на ARM64
// static int (*orig_open)(const char *pathname, int flags, ...);
// int new_open(const char *pathname, int flags, ...) { ... }

#pragma mark - UIKit Alert Block

static IMP orig_presentViewController = NULL;

void new_presentViewController(id self, SEL _cmd, id viewControllerToPresent, BOOL animated, id completion) {
    if ([viewControllerToPresent isKindOfClass:NSClassFromString(@"UIAlertController")]) {
        NSString *title = [viewControllerToPresent valueForKey:@"title"];
        NSString *message = [viewControllerToPresent valueForKey:@"message"];
        
        if ((title && [title containsString:@"OXIDE"]) || 
            (message && [message containsString:@"security threat"])) {
            NSLog(@"[Card0zo] Blocked native security alert!");
            if (completion) {
                void (^block)(void) = (void (^)(void))completion;
                block();
            }
            return;
        }
    }
    ((void (*)(id, SEL, id, BOOL, id))orig_presentViewController)(self, _cmd, viewControllerToPresent, animated, completion);
}

#pragma mark - Entry Point

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    struct rebinding access_rebinding = {"access", (void *)new_access, (void **)&orig_access};
    struct rebinding stat_rebinding = {"stat", (void *)new_stat, (void **)&orig_stat};
    rebind_symbols((struct rebinding[2]){access_rebinding, stat_rebinding}, 2);

    Class UIViewControllerClass = NSClassFromString(@"UIViewController");
    if (UIViewControllerClass) {
        Method method = class_getInstanceMethod(UIViewControllerClass, @selector(presentViewController:animated:completion:));
        orig_presentViewController = method_setImplementation(method, (IMP)new_presentViewController);
    }
    
    NSLog(@"[Card0zo] Init loaded. Hooks active. No memory scanner.");
}
