#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>
#include <vector>

// --- IL2CPP API ---
typedef void* (*il2cpp_domain_get_t)();
typedef void* (*il2cpp_domain_assembly_open_t)(void*, const char*);
typedef void* (*il2cpp_assembly_get_image_t)(void*);
typedef void* (*il2cpp_class_from_name_t)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_method_from_name_t)(void*, const char*, int);
typedef void* (*il2cpp_class_get_field_from_name_t)(void*, const char*);
typedef void* (*il2cpp_field_get_value_t)(void*, void*, void*);
typedef void* (*il2cpp_runtime_invoke_t)(void*, void*, void**, void*);

il2cpp_domain_get_t il2cpp_domain_get;
il2cpp_domain_assembly_open_t il2cpp_domain_assembly_open;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image;
il2cpp_class_from_name_t il2cpp_class_from_name;
il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name;
il2cpp_field_get_value_t il2cpp_field_get_value;
il2cpp_runtime_invoke_t il2cpp_runtime_invoke;

void InitIL2CPP() {
    void* handle = dlopen("UnityFramework", RTLD_LAZY);
    if (!handle) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    il2cpp_domain_assembly_open = (il2cpp_domain_assembly_open_t)dlsym(handle, "il2cpp_domain_assembly_open");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)dlsym(handle, "il2cpp_class_get_field_from_name");
    il2cpp_field_get_value = (il2cpp_field_get_value_t)dlsym(handle, "il2cpp_field_get_value");
    il2cpp_runtime_invoke = (il2cpp_runtime_invoke_t)dlsym(handle, "il2cpp_runtime_invoke");
}

void ChamsLoop() {
    sleep(5); // Ждем загрузки игры

    if (!il2cpp_domain_get || !il2cpp_domain_assembly_open) return;

    void* domain = il2cpp_domain_get();
    void* assembly = il2cpp_domain_assembly_open(domain, "Assembly-CSharp.dll");
    if (!assembly) return;

    void* image = il2cpp_assembly_get_image(assembly);
    if (!image) return;

    // 1. Ищем класс PlayerHull
    void* playerHullClass = il2cpp_class_from_name(image, "", "PlayerHull");
    if (!playerHullClass) return;

    // 2. Ищем класс PlayerModel (где лежат _renderers)
    // Нам нужно угадать название, скорее всего это PlayerModel или PlayerSkin
    void* playerModelClass = il2cpp_class_from_name(image, "", "PlayerModel");
    if (!playerModelClass) {
        playerModelClass = il2cpp_class_from_name(image, "", "PlayerSkin");
    }
    if (!playerModelClass) return;

    // 3. Ищем SkinnedMeshRenderer и Material
    void* skinnedMeshRendererClass = il2cpp_class_from_name(image, "UnityEngine", "SkinnedMeshRenderer");
    void* materialClass = il2cpp_class_from_name(image, "UnityEngine", "Material");
    if (!skinnedMeshRendererClass || !materialClass) return;

    // Ищем метод get_material у SkinnedMeshRenderer
    void* getMaterialMethod = il2cpp_class_get_method_from_name(skinnedMeshRendererClass, "get_material", 0);
    // Ищем метод set_color у Material
    void* setColorMethod = il2cpp_class_get_method_from_name(materialClass, "set_color", 1);

    if (!getMaterialMethod || !setColorMethod) return;

    while (true) {
        // Здесь должен быть цикл по игрокам и вызов getMaterial -> setColor
        // Но для этого нужно получить список игроков (Active) и их рендереры.
        // Пока это заглушка, чтобы проверить, что классы находятся.

        usleep(100000); // 100 мс
    }
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    InitIL2CPP();
    std::thread(ChamsLoop).detach();
}
