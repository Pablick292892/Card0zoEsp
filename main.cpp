#include <iostream>
#include <vector>
#include <string>
#include <dlfcn.h>
#include <unistd.h>
#include <thread>
#include <cstdlib>
#include "imgui.h"
#include "imgui_impl_metal.h"
#include "libtitanox.h" // Подключаем Titanox

namespace Settings {
    bool Authenticated = true;
    bool ESP_Enabled = true;
    bool ESP_Skeleton = true;
    bool ESP_Health = true;
    bool Watermark = true;
    float Color_Enemy[4] = { 1.0f, 0.2f, 0.2f, 1.0f }; 
}

void SetupPremiumStyle() {
    ImGuiStyle& style = ImGui::GetStyle();
    ImVec4* colors = style.Colors;

    style.WindowRounding = 10.0f;
    style.FrameRounding = 6.0f;
    style.WindowPadding = ImVec2(10, 10);
    style.ItemSpacing = ImVec2(10, 10);

    colors[ImGuiCol_WindowBg] = ImVec4(0.05f, 0.05f, 0.08f, 0.95f);
    colors[ImGuiCol_Border] = ImVec4(0.2f, 0.1f, 0.3f, 1.0f);
    colors[ImGuiCol_Text] = ImVec4(0.9f, 0.9f, 0.9f, 1.0f);
    
    colors[ImGuiCol_Button] = ImVec4(0.15f, 0.1f, 0.2f, 1.0f);
    colors[ImGuiCol_ButtonHovered] = ImVec4(0.25f, 0.15f, 0.35f, 1.0f);
    colors[ImGuiCol_CheckMark] = ImVec4(0.6f, 0.2f, 0.8f, 1.0f);
}

void DrawWatermark() {
    if (!Settings::Watermark) return;
    ImDrawList* draw = ImGui::GetBackgroundDrawList();
    ImGuiIO& io = ImGui::GetIO();
    const char* text = "CARD0ZO PREMIUM";
    ImVec2 textSize = ImGui::CalcTextSize(text);
    ImVec2 pos(io.DisplaySize.x - textSize.x - 20, io.DisplaySize.y - textSize.y - 20);
    draw->AddText(ImVec2(pos.x + 1, pos.y + 1), IM_COL32(0, 0, 0, 150), text);
    draw->AddText(pos, IM_COL32(150, 50, 200, 255), text);
}

void RenderESP() {
    if (!Settings::ESP_Enabled) return;
    ImDrawList* draw = ImGui::GetBackgroundDrawList();
    ImVec2 center = ImVec2(ImGui::GetIO().DisplaySize.x / 2, ImGui::GetIO().DisplaySize.y / 2);
    
    if (Settings::ESP_Skeleton) {
        ImU32 color = ImGui::ColorConvertFloat4ToU32(*(ImVec4*)Settings::Color_Enemy);
        draw->AddLine(ImVec2(center.x, center.y - 50), ImVec2(center.x, center.y + 50), color, 2.0f); 
        draw->AddLine(ImVec2(center.x - 20, center.y - 30), ImVec2(center.x + 20, center.y - 30), color, 2.0f); 
        draw->AddLine(ImVec2(center.x - 15, center.y + 50), ImVec2(center.x + 15, center.y + 50), color, 2.0f); 
    }
}

// Тот самый цикл, который мы повесим на хук
void RenderLoop() {
    while (true) {
        usleep(16000); 

        DrawWatermark();
        RenderESP();

        ImGui::SetNextWindowSize(ImVec2(600, 400), ImGuiCond_FirstUseEver);
        ImGui::Begin("Card0zo ESP", nullptr, ImGuiWindowFlags_NoCollapse);
        
        ImGui::BeginChild("Sidebar", ImVec2(150, 0), true);
        ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "CARD0ZO");
        ImGui::Separator();
        ImGui::Text("ESP");
        ImGui::Spacing();
        ImGui::Checkbox("Enable ESP", &Settings::ESP_Enabled);
        ImGui::Checkbox("Skeleton", &Settings::ESP_Skeleton);
        ImGui::Checkbox("Health", &Settings::ESP_Health);
        
        ImGui::SetCursorPosY(ImGui::GetWindowHeight() - 40);
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.6f, 0.1f, 0.1f, 1.0f));
        if (ImGui::Button("Close", ImVec2(130, 30))) {
            // Скрыть меню
        }
        ImGui::PopStyleColor();
        ImGui::EndChild();

        ImGui::SameLine();

        ImGui::BeginChild("Content", ImVec2(0, 0), true);
        ImGui::TextColored(ImVec4(0.6f, 0.2f, 0.8f, 1.0f), "Visual Settings");
        ImGui::Separator();
        ImGui::Spacing();
        ImGui::Text("Enemy Color");
        ImGui::SameLine();
        ImGui::ColorEdit4("##enemy", Settings::Color_Enemy, ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_NoLabel);
        ImGui::Spacing();
        ImGui::Text("Developer: Card0zo");
        ImGui::Text("License: Active");
        ImGui::EndChild();
        ImGui::End();
    }
}

// Инициализация Titanox и запуск потока
__attribute__((constructor))
void Init() {
    // Очистка переменных (чтобы античит не спалил)
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    SetupPremiumStyle();
    
    // Запускаем цикл отрисовки в отдельном потоке
    std::thread renderThread(RenderLoop);
    renderThread.detach();
}
