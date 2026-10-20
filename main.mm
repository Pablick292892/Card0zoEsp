#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>
#include <vector>
#include <Foundation/Foundation.h>
#include "imgui.h"
#include "imgui_impl_metal.h"

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

// --- Настройки ---
bool esp_enabled = true;
bool chams_enabled = true;

void RenderLoop() {
    sleep(5); // Ждем загрузки

    if (!il2cpp_domain_get || !il2cpp_domain_assembly_open) return;

    void* domain = il2cpp_domain_get();
    void* assembly = il2cpp_domain_assembly_open(domain, "Assembly-CSharp.dll");
    if (!assembly) return;

    void* image = il2cpp_assembly_get_image(assembly);
    if (!image) return;

    // Ищем PlayerSkeleton (ScarletWork.Game)
    void* playerSkeletonClass = il2cpp_class_from_name(image, "ScarletWork.Game", "PlayerSkeleton");
    if (!playerSkeletonClass) return;

    // Ищем поля
    void* hittableField = il2cpp_class_get_field_from_name(playerSkeletonClass, "Hittable"); // 0x0
    void* cachedRenderersField = il2cpp_class_get_field_from_name(playerSkeletonClass, "_cachedRenderers"); // 0x70
    void* bodyTransformField = il2cpp_class_get_field_from_name(playerSkeletonClass, "_boxTransform"); // 0x20 (в PlayerHull, но попробуем через Skeleton)

    while (true) {
        // Цикл отрисовки
        if (esp_enabled || chams_enabled) {
            // Здесь должна быть логика прохода по списку Hittable
            // Пока просто рисуем меню и заглушку ESP в центре
        }

        // Отрисовка меню
        ImGui::Begin("Card0zo CounterFlame");
        ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "Developer: Card0zo");
        ImGui::Separator();
        ImGui::Checkbox("Enable ESP", &esp_enabled);
        ImGui::Checkbox("Enable Chams", &chams_enabled);
        ImGui::End();

        usleep(16000); // 60 FPS
    }
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    InitIL2CPP();
    std::thread(RenderLoop).detach();
}
