#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>
#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
#include "imgui.h"
#include "imgui_impl_metal.h"

// Подключаем Titanox (путь может отличаться, но он должен быть в -I)
#include "libtitanox.h" 
#include "HookWrapper.h" // Если есть отдельный заголовок

// --- IL2CPP API ---
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

// --- Настройки ---
bool esp_enabled = true;

// --- Инициализация ImGui ---
id<MTLDevice> device;
id<MTLCommandQueue> commandQueue;

void InitImGui() {
    device = MTLCreateSystemDefaultDevice();
    commandQueue = [device newCommandQueue];
    
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL;
    ImGui_ImplMetal_Init(device);
}

// --- Функция отрисовки (хук) ---
void (*orig_Render)();
void hook_Render() {
    orig_Render(); // Вызываем оригинал

    // Инициализация (только 1 раз)
    static bool init = false;
    if (!init) { InitImGui(); init = true; }

    // Начинаем кадр ImGui
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    MTLRenderPassDescriptor* rpd = [MTLRenderPassDescriptor renderPassDescriptor];
    ImGui_ImplMetal_NewFrame(rpd);
    ImGui::NewFrame();

    // Рисуем меню
    ImGui::Begin("Card0zo Premium");
    ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "Developer: Card0zo");
    ImGui::Separator();
    ImGui::Checkbox("Enable ESP", &esp_enabled);
    ImGui::End();

    // Рисуем заглушку ESP
    if (esp_enabled) {
        ImDrawList* draw = ImGui::GetBackgroundDrawList();
        ImVec2 center = ImVec2(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2);
        draw->AddRect(ImVec2(center.x - 100, center.y - 100), ImVec2(center.x + 100, center.y + 100), IM_COL32(255, 0, 0, 255), 0.0f, 0, 2.0f);
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, rpd);
    [commandBuffer commit];
}

void SetupHook() {
    sleep(5); // Ждем загрузки

    if (!il2cpp_domain_get || !il2cpp_domain_assembly_open) return;

    void* domain = il2cpp_domain_get();
    void* assembly = il2cpp_domain_assembly_open(domain, "UnityEngine.CoreModule.dll");
    if (!assembly) return;

    void* image = il2cpp_assembly_get_image(assembly);
    if (!image) return;

    // Ищем класс Canvas
    void* canvasClass = il2cpp_class_from_name(image, "UnityEngine", "Canvas");
    if (!canvasClass) return;

    // Ищем метод, который вызывает отрисовку. В Unity это часто SendWillRenderCanvases
    void* method = il2cpp_class_get_method_from_name(canvasClass, "SendWillRenderCanvases", 0);
    if (!method) return;

    // Получаем указатель на функцию
    void* funcPtr = *(void**)method;
    if (funcPtr) {
        // Хукаем через Titanox
        HookWrapper::callHook(funcPtr, (void*)hook_Render, (void**)&orig_Render);
        NSLog(@"[Card0zo] Hook installed on Canvas!");
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
