#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>
#include "libtitanox.h"

// --- Заглушки для IL2CPP (чтобы компилятор не ругался) ---
typedef void* (*il2cpp_domain_get_t)();
typedef void* (*il2cpp_domain_assembly_open_t)(void*, const char*);
typedef void* (*il2cpp_assembly_get_image_t)(void*);
typedef void* (*il2cpp_class_from_name_t)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_method_from_name_t)(void*, const char*, int);

il2cpp_domain_get_t il2cpp_domain_get;
il2cpp_domain_assembly_open_t il2cpp_domain_assembly_open;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image;
il2cpp_class_from_name_t il2cpp_class_from_name;
il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name;

void InitIL2CPP() {
    void* handle = dlopen("UnityFramework", RTLD_LAZY);
    if (!handle) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    il2cpp_domain_assembly_open = (il2cpp_domain_assembly_open_t)dlsym(handle, "il2cpp_domain_assembly_open");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
}

// Тот самый класс, который палит нас
void* klass_SecurityRenderFeature = nullptr;
void* method_AddRenderPasses = nullptr;

// Хук (пустышка), который отключит проверку
void (*orig_AddRenderPasses)(void* __this, void* renderer, void* camera);
void hook_AddRenderPasses(void* __this, void* renderer, void* camera) {
    // Ничего не делаем. Проверка безопасности отключена.
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    InitIL2CPP();

    // Ждем, пока игра загрузит UnityFramework
    std::thread([]() {
        usleep(3000000); // 3 секунды на загрузку

        if (il2cpp_domain_get && il2cpp_domain_assembly_open && il2cpp_assembly_get_image && il2cpp_class_from_name && il2cpp_class_get_method_from_name) {
            void* domain = il2cpp_domain_get();
            void* assembly = il2cpp_domain_assembly_open(domain, "Assembly-CSharp.dll");
            
            if (assembly) {
                void* image = il2cpp_assembly_get_image(assembly);
                if (image) {
                    // Ищем класс Oxide.Features.Rendering.Security.SecurityRenderFeature
                    klass_SecurityRenderFeature = il2cpp_class_from_name(image, "Oxide.Features.Rendering.Security", "SecurityRenderFeature");
                    
                    if (klass_SecurityRenderFeature) {
                        // Ищем метод AddRenderPasses
                        method_AddRenderPasses = il2cpp_class_get_method_from_name(klass_SecurityRenderFeature, "AddRenderPasses", 2);
                        
                        if (method_AddRenderPasses) {
                            // Получаем адрес функции в памяти
                            void* funcPtr = *(void**)method_AddRenderPasses;
                            
                            if (funcPtr) {
                                // Ставим хук через Titanox
                                // ВАЖНО: точный синтаксис зависит от версии Titanox
                                // HookWrapper::callHook(funcPtr, (void*)hook_AddRenderPasses, (void**)&orig_AddRenderPasses);
                            }
                        }
                    }
                }
            }
        }
    }).detach();
}
