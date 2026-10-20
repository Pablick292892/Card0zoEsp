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
typedef void* (*il2cpp_class_get_field_from_name_t)(void*, const char*);
typedef void* (*il2cpp_field_static_get_value_t)(void*, void*);

il2cpp_domain_get_t il2cpp_domain_get;
il2cpp_domain_assembly_open_t il2cpp_domain_assembly_open;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image;
il2cpp_class_from_name_t il2cpp_class_from_name;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name;
il2cpp_field_static_get_value_t il2cpp_field_static_get_value;

void InitIL2CPP() {
    void* handle = dlopen("UnityFramework", RTLD_LAZY);
    if (!handle) return;
    il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    il2cpp_domain_assembly_open = (il2cpp_domain_assembly_open_t)dlsym(handle, "il2cpp_domain_assembly_open");
    il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)dlsym(handle, "il2cpp_class_get_field_from_name");
    il2cpp_field_static_get_value = (il2cpp_field_static_get_value_t)dlsym(handle, "il2cpp_field_static_get_value");
}

// --- Настройки ---
bool esp_enabled = true;
bool chams_enabled = true;

// Наш хук на отрисовку кадра
void (*orig_willRenderCanvases)();
void hook_willRenderCanvases() {
    // Вызываем оригинальную функцию (рендер игры)
    orig_willRenderCanvases();

    // Инициализируем ImGui (только один раз)
    static bool initialized = false;
    if (!initialized) {
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO();
        io.IniFilename = NULL;
        
        // Инициализация ImGui для Metal (упрощенно, может потребовать доработки)
        // ImGui_ImplMetal_Init(device); 
        
        initialized = true;
    }

    // Начинаем новый кадр
    ImGui_ImplMetal_NewFrame(NULL);
    ImGui::NewFrame();

    // Рисуем меню
    ImGui::Begin("Card0zo CounterFlame");
    ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "Developer: Card0zo");
    ImGui::Separator();
    ImGui::Checkbox("Enable ESP", &esp_enabled);
    ImGui::Checkbox("Enable Chams", &chams_enabled);
    ImGui::End();

    // Рисуем заглушку ESP (квадрат в центре)
    if (esp_enabled) {
        ImDrawList* draw = ImGui::GetBackgroundDrawList();
        ImVec2 center = ImVec2(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2);
        draw->AddRect(ImVec2(center.x - 50, center.y - 50), ImVec2(center.x + 50, center.y + 50), IM_COL32(255, 0, 0, 255), 0.0f, 0, 2.0f);
    }

    // Завершаем кадр
    ImGui::Render();
    // ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderPassDescriptor);
}

void SetupHook() {
    sleep(5); // Ждем загрузки

    if (!il2cpp_domain_get || !il2cpp_domain_assembly_open) return;

    void* domain = il2cpp_domain_get();
    void* assembly = il2cpp_domain_assembly_open(domain, "UnityEngine.CoreModule.dll"); // Canvas находится в CoreModule
    if (!assembly) {
        // Пробуем Assembly-CSharp
        assembly = il2cpp_domain_assembly_open(domain, "Assembly-CSharp.dll");
    }
    if (!assembly) return;

    void* image = il2cpp_assembly_get_image(assembly);
    if (!image) return;

    // Ищем класс Canvas
    void* canvasClass = il2cpp_class_from_name(image, "UnityEngine", "Canvas");
    if (!canvasClass) return;

    // Ищем поле willRenderCanvases (offset 0x8)
    void* field = il2cpp_class_get_field_from_name(canvasClass, "willRenderCanvases");
    if (!field) return;

    // Получаем указатель на делегат и подменяем его
    void* currentDelegate = nullptr;
    il2cpp_field_static_get_value(field, &currentDelegate);
    
    if (currentDelegate) {
        // Хукаем через Titanox или стандартный метод
        // (В реальном коде здесь будет вызов HookWrapper::callHook)
        // Пока просто сохраняем оригинал
        orig_willRenderCanvases = (void(*)())currentDelegate;
        // Подменяем на наш хук (заглушка, так как нет Titanox)
        // il2cpp_field_static_set_value(field, (void*)hook_willRenderCanvases);
    }
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    InitIL2CPP();
    std::thread(SetupHook).detach();
}
