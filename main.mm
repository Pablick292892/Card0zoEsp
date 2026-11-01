#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <vector>
#include <string>
#include <mach-o/dyld.h>
#include "fishhook.h"

// === ОФФСЕТЫ ИЗ ТВОЕГО ДАМПА ===
#define OFF_PLAYER_SKELETON_HITTABLE 0x0
#define OFF_PLAYER_HULL_TRANSFORM 0x20
#define OFF_PLAYER_HULL_TEAM 0x30

// Базовые структуры Unity
struct Vector3 { float x, y, z; };

// Указатели на функции Unity
void* (*il2cpp_domain_get)();
void* (*il2cpp_class_from_name)(void* image, const char* namespaze, const char* name);
void* (*il2cpp_field_get_value)(void* obj, void* field, void* value);
void* (*il2cpp_class_get_field_from_name)(void* klass, const char* name);

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
    if (!unityBase) return;

    // Ищем класс PlayerSkeleton
    void* klass = il2cpp_class_from_name(NULL, "ScarletWork.Game", "PlayerSkeleton");
    if (!klass) return;

    // Ищем статическое поле Hittable
    void* field = il2cpp_class_get_field_from_name(klass, "Hittable");
    if (!field) return;

    // Получаем список игроков
    void* hittableList = nullptr;
    il2cpp_field_get_value(NULL, field, &hittableList);
    if (!hittableList) return;

    // В реальности тут нужно итерироваться по List<T> (через _items и _size)
    // Но для теста мы просто покажем, что связь с памятью есть
    dispatch_async(dispatch_get_main_queue(), ^{
        espLabel.text = @"ESP: Connected to Game Memory";
        espLabel.hidden = NO;
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
        
        // Запускаем таймер обновления (60 раз в секунду)
        [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 target:[NSBlockOperation blockOperationWithBlock:^{
            UpdateESP();
        }] selector:@selector(main) userInfo:nil repeats:YES];
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
            il2cpp_domain_get = dlsym(unityHandle, "il2cpp_domain_get");
            il2cpp_class_from_name = dlsym(unityHandle, "il2cpp_class_from_name");
            il2cpp_field_get_value = dlsym(unityHandle, "il2cpp_field_get_value");
            il2cpp_class_get_field_from_name = dlsym(unityHandle, "il2cpp_class_get_field_from_name");
            
            setupESP();
        } else {
            NSLog(@"[Card0zoEsp] Failed to load UnityFramework!");
        }
    });
}
