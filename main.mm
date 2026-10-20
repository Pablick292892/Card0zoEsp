#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#include <dlfcn.h>
#include <string.h>
#include <mach-o/dyld.h>

#pragma mark - IL2CPP Types
typedef void* Il2CppClass;
typedef void* Il2CppFieldInfo;
typedef void* Il2CppDomain;
typedef void* Il2CppAssembly;
typedef void* Il2CppImage;

typedef Il2CppDomain* (*il2cpp_domain_get_t)();
typedef Il2CppAssembly* (*il2cpp_domain_assembly_open_t)(Il2CppDomain*, const char*);
typedef Il2CppImage* (*il2cpp_assembly_get_image_t)(Il2CppAssembly*);
typedef Il2CppClass* (*il2cpp_class_from_name_t)(Il2CppImage*, const char*, const char*);
typedef Il2CppFieldInfo* (*il2cpp_class_get_fields_t)(Il2CppClass*, void**);
typedef void (*il2cpp_field_static_get_value_t)(Il2CppFieldInfo*, void*);
typedef const char* (*il2cpp_field_get_name_t)(Il2CppFieldInfo*);

static uintptr_t g_base = 0;
static void* g_hittable = NULL;

#pragma mark - Memory
static uintptr_t GetBase(const char* name) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (strstr(_dyld_get_image_name(i), name))
            return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

template<typename T>
static T Read(uintptr_t a) { return a ? *(T*)a : T{}; }

#pragma mark - Entry Point
__attribute__((constructor))
void Init() {
    // 1. ТРОЙНАЯ ВИБРАЦИЯ (сразу скажет, что код выполнился)
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    usleep(200000);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    usleep(200000);
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);

    // 2. Ждём 3 секунды, чтобы игра прогрузила UI
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        g_base = GetBase("GameAssembly");
        
        NSString* status = @"DYLIB ЗАГРУЖЕН!\n";
        status = [status stringByAppendingFormat:@"GameAssembly Base: 0x%lx\n", g_base];
        
        if (g_base > 0) {
            // Пробуем найти IL2CPP функции
            il2cpp_domain_get_t fn_domain_get = (il2cpp_domain_get_t)dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
            il2cpp_class_from_name_t fn_class_from_name = (il2cpp_class_from_name_t)dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
            
            if (fn_domain_get && fn_class_from_name) {
                status = [status stringByAppendingString:@"IL2CPP Functions: FOUND\n"];
                
                auto domain = fn_domain_get();
                auto assembly = ((il2cpp_domain_assembly_open_t)dlsym(RTLD_DEFAULT, "il2cpp_domain_assembly_open"))(domain, "Assembly-CSharp");
                auto image = ((il2cpp_assembly_get_image_t)dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image"))(assembly);
                
                if (image) {
                    status = [status stringByAppendingString:@"Assembly-CSharp: FOUND\n"];
                    
                    auto cls = fn_class_from_name(image, "ScarletWork.Game", "PlayerSkeleton");
                    if (cls) {
                        status = [status stringByAppendingString:@"Class PlayerSkeleton: FOUND\n"];
                        
                        void* iter = NULL;
                        Il2CppFieldInfo* field;
                        auto fn_get_fields = (il2cpp_class_get_fields_t)dlsym(RTLD_DEFAULT, "il2cpp_class_get_fields");
                        auto fn_get_name = (il2cpp_field_get_name_t)dlsym(RTLD_DEFAULT, "il2cpp_field_get_name");
                        auto fn_static_get = (il2cpp_field_static_get_value_t)dlsym(RTLD_DEFAULT, "il2cpp_field_static_get_value");
                        
                        while ((field = fn_get_fields(cls, &iter)) != NULL) {
                            const char* name = fn_get_name(field);
                            if (name && strcmp(name, "Hittable") == 0) {
                                fn_static_get(field, &g_hittable);
                                status = [status stringByAppendingFormat:@"Field Hittable: %p\n", g_hittable];
                                break;
                            }
                        }
                        if (!g_hittable) {
                            status = [status stringByAppendingString:@"Field Hittable: NOT FOUND\n"];
                        }
                    } else {
                        status = [status stringByAppendingString:@"Class PlayerSkeleton: NOT FOUND\n"];
                    }
                } else {
                    status = [status stringByAppendingString:@"Assembly-CSharp: NOT FOUND\n"];
                }
            } else {
                status = [status stringByAppendingString:@"IL2CPP Functions: NOT FOUND (dlsym failed)\n"];
            }
        } else {
            status = [status stringByAppendingString:@"GameAssembly: NOT FOUND\n"];
        }

        // 3. ПОКАЗЫВАЕМ ОГРОМНОЕ ОКНО СО СТАТУСОМ
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"CARD0ZO ESP STATUS" message:status preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        UIWindow* window = UIApplication.sharedApplication.windows.firstObject;
        [window.rootViewController presentViewController:alert animated:YES completion:nil];
    });
}
