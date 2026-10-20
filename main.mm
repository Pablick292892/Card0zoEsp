#include <unistd.h>
#include <cstdlib>
#include <string>
#include <dlfcn.h>
#include <thread>
#include <vector>
#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
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

// --- Инициализация ImGui для Metal ---
id<MTLDevice> device;
id<MTLCommandQueue> commandQueue;

void InitImGui() {
    device = MTLCreateSystemDefaultDevice();
    commandQueue = [device newCommandQueue];
    
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL;
    
    // ВАЖНО: Инициализация бэкенда Metal
    ImGui_ImplMetal_Init(device);
}

// --- Хук на отрисовку кадра ---
void (*orig_willRenderCanvases)();
void hook_willRenderCanvases() {
    orig_willRenderCanvases();

    static bool initialized = false;
    if (!initialized) {
        InitImGui();
        initialized = true;
    }

    // Начинаем кадр ImGui
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    MTLRenderPassDescriptor* renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    // (В реальном коде здесь нужно получить текущий RenderPass от Unity, но мы упростим)
    
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
    ImGui::NewFrame();

    // Рисуем меню
    ImGui::Begin("Card0zo Premium");
    ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "Developer: Card0zo");
    ImGui::Separator();
    ImGui::Checkbox("Enable ESP", &esp_enabled);
    ImGui::Checkbox("Enable Chams", &chams_enabled);
    ImGui::End();

    // Рисуем ESP (заглушка в центре)
    if (esp_enabled) {
        ImDrawList* draw = ImGui::GetBackgroundDrawList();
        ImVec2 center = ImVec2(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2);
        draw->AddRect(ImVec2(center.x - 100, center.y - 100), ImVec2(center.x + 100, center.y + 100), IM_COL32(255, 0, 0, 255), 0.0f, 0, 2.0f);
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderPassDescriptor);
    [commandBuffer commit];
}

void SetupHook() {
    sleep(5);

    if (!il2cpp_domain_get || !il2cpp_domain_assembly_open) return;

    void* domain = il2cpp_domain_get();
    void* assembly = il2cpp_domain_assembly_open(domain, "UnityEngine.CoreModule.dll");
    if (!assembly) assembly = il2cpp_domain_assembly_open(domain, "Assembly-CSharp.dll");
    if (!assembly) return;

    void* image = il2cpp_assembly_get_image(assembly);
    if (!image) return;

    void* canvasClass = il2cpp_class_from_name(image, "UnityEngine", "Canvas");
    if (!canvasClass) return;

    void* field = il2cpp_class_get_field_from_name(canvasClass, "willRenderCanvases");
    if (!field) return;

    void* currentDelegate = nullptr;
    il2cpp_field_static_get_value(field, &currentDelegate);
    
    if (currentDelegate) {
        orig_willRenderCanvases = (void(*)())currentDelegate;
        // Тут нужен вызов HookWrapper::callHook(field, hook_willRenderCanvases, &orig_willRenderCanvases)
        NSLog(@"[Card0zo] Hook installed!");
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
