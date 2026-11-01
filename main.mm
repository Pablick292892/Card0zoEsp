#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <vector>
#include <string>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#include "fishhook.h"

// === ОФФСЕТЫ ИЗ ТВОЕГО ДАМПА ===
#define OFF_PLAYER_SKELETON_HITTABLE 0x0
#define OFF_PLAYER_HULL_TRANSFORM 0x20
#define OFF_PLAYER_HULL_TEAM 0x30

// Базовые структуры Unity
struct Vector3 { float x, y, z; };

// Указатели на функции Unity (Обязательно extern "C" и typedef)
extern "C" {
    typedef void* (*il2cpp_domain_get_t)();
    typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
    typedef void* (*il2cpp_field_get_value_t)(void* obj, void* field, void* value);
    typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);
}

il2cpp_domain_get_t il2cpp_domain_get_ptr = NULL;
il2cpp_class_from_name_t il2cpp_class_from_name_ptr = NULL;
il2cpp_field_get_value_t il2cpp_field_get_value_ptr = NULL;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name_ptr = NULL;

// Окно для отрисовки
UIWindow *espWindow;
UILabel *espLabel;

// Получение базы UnityFramework
uintptr_t get_unity_base() {
    for (int i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, "UnityFramework")) {
            return _dyld_get_image_vmaddr_slide(i);
        }
    }
    return 0;
}

// Твоя логика ESP
void UpdateESP() {
    uintptr_t unityBase = get_unity_base();
    if (!unityBase || !il2cpp_class_from_name_ptr) return;

    // Ищем класс PlayerSkeleton
    void* klass = il2cpp_class_from_name_ptr(NULL, "ScarletWork.Game", "PlayerSkeleton");
    if (!klass) {
        dispatch_async(dispatch_get_main_queue(), ^{
            espLabel.text = @"ESP: Class not found";
        });
        return;
    }

    // Ищем статическое поле Hittable
    void* field = il2cpp_class_get_field_from_name_ptr(klass, "Hittable");
    if (!field) {
        dispatch_async(dispatch_get_main_queue(), ^{
            espLabel.text = @"ESP: Field not found";
        });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        espLabel.text = @"ESP: Connected to Game Memory!";
    });
}

// Создание UI (вызывается через 3 секунды после запуска)
void setupESP() {
    dispatch_async(dispatch_get_main_queue(), ^{
        espWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        espWindow.windowLevel = UIWindowLevelAlert + 1;
        espWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO; // Чтобы не мешать играть
        
        espLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 30)];
        espLabel.text = @"ESP: Loading...";
        espLabel.textColor = [UIColor greenColor];
        espLabel.font = [UIFont boldSystemFontOfSize:16];
        [vc.view addSubview:espLabel];
        
        espWindow.rootViewController = vc;
        espWindow.hidden = NO;
        
        // Запускаем таймер обновления
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0/60.0 target:[NSBlockOperation blockOperationWithBlock:^{
            UpdateESP();
        }] selector:@selector(main) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

// Точка входа
__attribute__((constructor))
static void init() {
    NSLog(@"[Card0zoEsp] Loaded. Waiting for Unity...");
    
    // Ждем 3 секунды, чтобы игра прогрузилась
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Подгружаем функции IL2CPP из UnityFramework
        void* unityHandle = dlopen("@executable_path/Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
        if (unityHandle) {
            il2cpp_domain_get_ptr = (il2cpp_domain_get_t)dlsym(unityHandle, "il2cpp_domain_get");
            il2cpp_class_from_name_ptr = (il2cpp_class_from_name_t)dlsym(unityHandle, "il2cpp_class_from_name");
            il2cpp_field_get_value_ptr = (il2cpp_field_get_value_t)dlsym(unityHandle, "il2cpp_field_get_value");
            il2cpp_class_get_field_from_name_ptr = (il2cpp_class_get_field_from_name_t)dlsym(unityHandle, "il2cpp_class_get_field_from_name");
            
            setupESP();
        } else {
            NSLog(@"[Card0zoEsp] Failed to load UnityFramework!");
        }
    });
}
