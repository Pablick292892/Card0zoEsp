#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <dlfcn.h>

// Правильные сигнатуры функций IL2CPP
typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);

il2cpp_domain_get_t il2cpp_domain_get_ptr = NULL;
il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies_ptr = NULL;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image_ptr = NULL;
il2cpp_class_from_name_t il2cpp_class_from_name_ptr = NULL;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name_ptr = NULL;

UIWindow *espWindow;
UILabel *espLabel;
void* gameImage = NULL; // Указатель на нашу сборку с классами

void UpdateESP() {
    if (!gameImage) {
        dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: Image not found"; });
        return;
    }

    // Теперь передаем правильный gameImage
    void* klass = il2cpp_class_from_name_ptr(gameImage, "ScarletWork.Game", "PlayerSkeleton");
    if (!klass) {
        dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: Class not found"; });
        return;
    }

    void* field = il2cpp_class_get_field_from_name_ptr(klass, "Hittable");
    if (!field) {
        dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: Field not found"; });
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        espLabel.text = @"ESP: Memory READ OK!";
        espLabel.textColor = [UIColor cyanColor]; 
    });
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 1. Создаем UI
        espWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        espWindow.windowLevel = UIWindowLevelAlert + 1;
        espWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        
        espLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 400, 30)];
        espLabel.text = @"ESP: Initializing...";
        espLabel.textColor = [UIColor yellowColor];
        espLabel.font = [UIFont boldSystemFontOfSize:16];
        [vc.view addSubview:espLabel];
        
        espWindow.rootViewController = vc;
        espWindow.hidden = NO;

        // 2. Ищем библиотеку
        NSString *unityPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
        void* unityHandle = dlopen([unityPath UTF8String], RTLD_LAZY);
        
        if (unityHandle) {
            il2cpp_domain_get_ptr = (il2cpp_domain_get_t)dlsym(unityHandle, "il2cpp_domain_get");
            il2cpp_domain_get_assemblies_ptr = (il2cpp_domain_get_assemblies_t)dlsym(unityHandle, "il2cpp_domain_get_assemblies");
            il2cpp_assembly_get_image_ptr = (il2cpp_assembly_get_image_t)dlsym(unityHandle, "il2cpp_assembly_get_image");
            il2cpp_class_from_name_ptr = (il2cpp_class_from_name_t)dlsym(unityHandle, "il2cpp_class_from_name");
            il2cpp_class_get_field_from_name_ptr = (il2cpp_class_get_field_from_name_t)dlsym(unityHandle, "il2cpp_class_get_field_from_name");
            
            if (il2cpp_domain_get_ptr && il2cpp_domain_get_assemblies_ptr && il2cpp_assembly_get_image_ptr) {
                // Ищем сборку Assembly-CSharp
                void* domain = il2cpp_domain_get_ptr();
                size_t assemblyCount = 0;
                void** assemblies = il2cpp_domain_get_assemblies_ptr(domain, &assemblyCount);
                
                if (assemblies) {
                    for (size_t i = 0; i < assemblyCount; i++) {
                        void* image = il2cpp_assembly_get_image_ptr(assemblies[i]);
                        if (image) {
                            void* testClass = il2cpp_class_from_name_ptr(image, "ScarletWork.Game", "PlayerSkeleton");
                            if (testClass) {
                                gameImage = image; // Нашли нужную сборку!
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ espLabel.text = @"ESP: dlopen failed"; });
            return;
        }

        // 3. Цикл обновления
        __block void (^loop)(void);
        loop = ^{
            UpdateESP();
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), loop);
        };
        loop();
    });
}
