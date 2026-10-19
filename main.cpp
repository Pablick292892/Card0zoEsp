#include <iostream>
#include <vector>
#include <string>
#include <dlfcn.h>
#include <unistd.h>
#include <thread>
#include <cstdlib>
#include "imgui.h"
#include "imgui_impl_metal.h"

namespace Settings {
    bool Authenticated = true; // Временно true, так как KeyAuth отключен
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
    colors[ImGuiCol_SliderGrab] = ImVec4(0.6f, 0.2f, 0.8f, 1.0f);
    colors[ImGuiCol_SliderGrabActive] = ImVec4(0.7f, 0.3f, 0.9f, 1.0f);
}

bool ToggleSwitch(const char* label, bool* v) {
    ImGuiWindow* window = ImGui::GetCurrentWindow();
    if (window->SkipItems) return false;

    ImGuiContext& g = *GImGui;
    const ImGuiStyle& style = g.Style;
    const ImGuiID id = window->GetID(label);
    const ImVec2 label_size = ImGui::CalcTextSize(label, NULL, true);

    const float height = ImGui::GetFrameHeight();
    const float width = height * 1.8f;
    const float radius = height * 0.50f;

    const ImVec2 pos = window->DC.CursorPos;
    const ImRect total_bb(pos, ImVec2(pos.x + width + (label_size.x > 0.0f ? style.ItemInnerSpacing.x + label_size.x : 0.0f), pos.y + label_size.y + style.FramePadding.y * 2.0f));
    
    ImGui::ItemSize(total_bb, style.FramePadding.y);
    if (!ImGui::ItemAdd(total_bb, id)) return false;

    bool hovered, held;
    bool pressed = ImGui::ButtonBehavior(total_bb, id, &hovered, &held);
    if (pressed) {
        *v = !(*v);
        ImGui::MarkItemEdited(id);
    }

    const float t = *v ? 1.0f : 0.0f; 
    const ImU32 col_bg = ImGui::GetColorU32((hovered && held) ? ImGuiCol_FrameBgActive : hovered ? ImGuiCol_FrameBgHovered : ImGuiCol_FrameBg);
    const ImU32 col_knob = ImGui::GetColorU32(*v ? ImVec4(0.6f, 0.2f, 0.8f, 1.0f) : ImVec4(0.4f, 0.4f, 0.4f, 1.0f));

    window->DrawList->AddRectFilled(pos, ImVec2(pos.x + width, pos.y + height), col_bg, height * 0.5f);
    window->DrawList->AddCircleFilled(ImVec2(pos.x + radius + t * (width - radius * 2.0f), pos.y + radius), radius - 2.0f, col_knob);

    if (label_size.x > 0.0f) {
        ImGui::GetWindowDrawList()->AddText(ImGui::GetFont(), ImGui::GetFontSize(), ImVec2(pos.x + width + style.ItemInnerSpacing.x, pos.y + style.FramePadding.y), ImGui::GetColorU32(ImGuiCol_Text), label);
    }

    return pressed;
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
    
    // Это заглушка. Позже мы заменим её на реальное чтение памяти по твоим оффсетам.
    if (Settings::ESP_Skeleton) {
        ImU32 color = ImGui::ColorConvertFloat4ToU32(*(ImVec4*)Settings::Color_Enemy);
        draw->AddLine(ImVec2(center.x, center.y - 50), ImVec2(center.x, center.y + 50), color, 2.0f); 
        draw->AddLine(ImVec2(center.x - 20, center.y - 30), ImVec2(center.x + 20, center.y - 30), color, 2.0f); 
        draw->AddLine(ImVec2(center.x - 15, center.y + 50), ImVec2(center.x + 15, center.y + 50), color, 2.0f); 
    }
}

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
        ToggleSwitch("Enable ESP", &Settings::ESP_Enabled);
        ToggleSwitch("Skeleton", &Settings::ESP_Skeleton);
        ToggleSwitch("Health", &Settings::ESP_Health);
        
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

void InitStealth() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
}

__attribute__((constructor))
void Init() {
    InitStealth();
    SetupPremiumStyle();
    std::thread renderThread(RenderLoop);
    renderThread.detach();
}
