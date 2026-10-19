export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

export ADDITIONAL_CCFLAGS = -std=c++17 -Wno-error=unused-variable

INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoESP
# Оставляем только наш код и Titanox
Card0zoESP_FILES = main.mm $(shell find libtitanox -name "*.mm" -o -name "*.cpp" -o -name "*.c") ImGui/backends/imgui_impl_metal.mm ImGui/imgui.cpp ImGui/imgui_draw.cpp ImGui/imgui_tables.cpp ImGui/imgui_widgets.cpp
Card0zoESP_CFLAGS = -fobjc-arc -I./ImGui -I./ImGui/backends -I. -I./libtitanox -I./fishhook -I./mempatch -I./MemX -I./static-inline-hook
Card0zoESP_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk
