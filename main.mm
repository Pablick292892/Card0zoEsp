#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>

// --- Заглушки для IL2CPP ---
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

// Хук для отключения проверки
void (*orig_AddRenderPasses)(void* __this, void* renderer, void* camera);
void hook_AddRenderPasses(void* __this, void* renderer, void* camera) {
    // Ничего не делаем, отключаем проверку
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    InitIL2CPP();

    std::thread([]() {
        usleep(3000000); // Ждем 3 секунды, пока игра загрузится

        if (il2cpp_domain_get && il2cpp_domain_assembly_open && il2cpp_assembly_get_image && il2cpp_class_from_name && il2cpp_class_get_method_from_name) {
            void* domain = il2cpp_domain_get();
            void* assembly = il2cpp_domain_assembly_open(domain, "Assembly-CSharp.dll");
            
            if (assembly) {
                void* image = il2cpp_assembly_get_image(assembly);
                if (image) {
                    // Ищем наш класс
                    void* klass = il2cpp_class_from_name(image, "Oxide.Features.Rendering.Security", "SecurityRenderFeature");
                    
                    if (klass) {
                        // Ищем метод AddRenderPasses
                        void* method = il2cpp_class_get_method_from_name(klass, "AddRenderPasses", 2);
                        
                        if (method) {
                            void* funcPtr = *(void**)method;
                            
                            if (funcPtr) {
                                // ВАЖНО: тут мы должны вызвать функцию хука Titanox.
                                // Пока её нет, мы просто компилируем этот код, чтобы проверить, что IL2CPP работает.
                                // Как только сборка пройдет, я добавлю точный вызов хука.
                            }
                        }
                    }
                }
            }
        }
    }).detach();
}
