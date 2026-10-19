export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

export ADDITIONAL_CCFLAGS = -std=c++17 -Wno-error=unused-variable -Wno-deprecated-declarations

INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = Card0zoESP

Card0zoESP_FILES = main.mm fishhook/fishhook.c ImGui/imgui.cpp ImGui/imgui_draw.cpp ImGui/imgui_tables.cpp ImGui/imgui_widgets.cpp ImGui/backends/imgui_impl_metal.mm
Card0zoESP_CFLAGS = -fno-objc-arc -I./ImGui -I./ImGui/backends -I./fishhook -I.
Card0zoESP_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/library.mk
