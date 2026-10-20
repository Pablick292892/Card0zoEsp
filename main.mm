#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

__attribute__((constructor))
void Init() {
    // Показываем Alert через 2 секунды после загрузки
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
        
        UIAlertController *alert = [UIAlertController 
            alertControllerWithTitle:@"Card0zo ESP"
            message:@"DYLIB LOADED SUCCESSFULLY!"
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:nil]];
        
        // Находим верхнее окно
        UIWindow *window = nil;
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.isKeyWindow) { window = w; break; }
        }
        if (!window && UIApplication.sharedApplication.windows.count > 0) {
            window = UIApplication.sharedApplication.windows.firstObject;
        }
        
        if (window) {
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
        }
    });
}
