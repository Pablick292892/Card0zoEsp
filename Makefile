export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

# Используем новый флаг Theos для C++
export ADDITIONAL_CCFLAGS = -std=c++17 -Wno-error=unused-variable

INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoESP
# Прописываем файлы Titanox БЕЗ папки libtitanox, так как build.yml кладет их в корень
Card0zoESP_FILES = main.mm libtitanox/main.mm mempatch/THPatchMem.mm MemX/VMTWrapper.mm static-inline-hook/sih.mm fishhook/fishhook.c ImGui/imgui.cpp ImGui/imgui_draw.cpp ImGui/imgui_tables.cpp ImGui/imgui_widgets.cpp ImGui/backends/imgui_impl_metal.mm
Card0zoESP_CFLAGS = -fobjc-arc -I./ImGui -I./ImGui/backends -I./libtitanox -I./fishhook -I./mempatch -I./MemX -I./static-inline-hook -I.
Card0zoESP_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk
