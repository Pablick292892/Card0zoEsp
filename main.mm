#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>
#include <objc/runtime.h>

// Хук для UIAlertController
void (*orig_presentViewController)(id, SEL, id, BOOL, id);
void hook_presentViewController(id self, SEL _cmd, id viewController, BOOL animated, id completion) {
    if ([viewController isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)viewController;
        if ([alert.title containsString:@"security threat"] || [alert.message containsString:@"security threat"]) {
            // Это окно античита. Блокируем его показ.
            return;
        }
    }
    orig_presentViewController(self, _cmd, viewController, animated, completion);
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    // Хукаем метод presentViewController:animated:completion: у UIViewController
    Class uiViewControllerClass = objc_getClass("UIViewController");
    SEL selector = sel_registerName("presentViewController:animated:completion:");
    Method method = class_getInstanceMethod(uiViewControllerClass, selector);
    
    if (method) {
        // Используем стандартный метод замены реализации (method_exchangeImplementations)
        // В реальном проекте лучше использовать Titanox, но для теста сгодится и это
        IMP originalImp = method_getImplementation(method);
        orig_presentViewController = (void (*)(id, SEL, id, BOOL, id))originalImp;
        
        IMP newImp = imp_implementationWithBlock(^(id self, id viewController, BOOL animated, id completion) {
            if ([viewController isKindOfClass:[UIAlertController class]]) {
                UIAlertController *alert = (UIAlertController *)viewController;
                if (([alert.title containsString:@"security threat"]) || ([alert.message containsString:@"security threat"])) {
                    return; // Блокируем окно
                }
            }
            orig_presentViewController(self, selector, viewController, animated, completion);
        });
        
        method_setImplementation(method, newImp);
    }
}
