#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>

// Указатели на функции Unity
typedef void* (*il2cpp_domain_get_t)();
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);

il2cpp_domain_get_t il2cpp_domain_get_ptr = NULL;
il2cpp_class_from_name_t il2cpp_class_from_name_ptr = NULL;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name_ptr = NULL;

UIWindow *espWindow;
UILabel *espLabel;

// Ищем базу Unity
uintptr_t get_unity_base() {
    for (int i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

void UpdateESP() {
    uintptr_t unityBase = get_unity_base();
    if (!unityBase) return;

    if (!il2cpp_class_from_name_ptr) {
        dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: IL2CPP not loaded"; });
        return;
    }

    // Ищем класс
    void* klass = il2cpp_class_from_name_ptr(NULL, "ScarletWork.Game", "PlayerSkeleton");
    if (!klass) {
        dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: Class not found"; });
        return;
    }

    // Ищем поле Hittable
    void* field = il2cpp_class_get_field_from_name_ptr(klass, "Hittable");
    if (!field) {
        dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: Field not found"; });
        return;
    }

    // Если всё нашли — УСПЕХ!
    dispatch_async(dispatch_get_main_queue(), ^{
        espLabel.text = @"ESP: Memory READ OK!";
        espLabel.textColor = [UIColor cyanColor]; // Поменяем цвет, чтобы точно заметил
    });
}

__attribute__((constructor))
static void init() {
    NSLog(@"[Card0zoEsp] Loaded. Waiting for game...");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 1. Создаем UI
        espWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        espWindow.windowLevel = UIWindowLevelAlert + 1;
        espWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        
        espLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 400, 30)];
        espLabel.text = @"ESP: Loading IL2CPP...";
        espLabel.textColor = [UIColor yellowColor];
        espLabel.font = [UIFont boldSystemFontOfSize:16];
        [vc.view addSubview:espLabel];
        
        espWindow.rootViewController = vc;
        espWindow.hidden = NO;

        // 2. Подгружаем функции Unity
        void* unityHandle = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
        if (unityHandle) {
            il2cpp_domain_get_ptr = (il2cpp_domain_get_t)dlsym(unityHandle, "il2cpp_domain_get");
            il2cpp_class_from_name_ptr = (il2cpp_class_from_name_t)dlsym(unityHandle, "il2cpp_class_from_name");
            il2cpp_class_get_field_from_name_ptr = (il2cpp_class_get_field_from_name_t)dlsym(unityHandle, "il2cpp_class_get_field_from_name");
        }

        // 3. Запускаем таймер обновления раз в секунду
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:[NSBlockOperation blockOperationWithBlock:^{
            UpdateESP();
        }] selector:@selector(main) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}
