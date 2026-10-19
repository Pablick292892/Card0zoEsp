export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoESP
Card0zoESP_FILES = main.cpp ImGui/imgui.cpp ImGui/imgui_draw.cpp ImGui/imgui_tables.cpp ImGui/imgui_widgets.cpp ImGui/backends/imgui_impl_metal.mm ImGui/backends/imgui_impl_osx.mm
Card0zoESP_CFLAGS = -fobjc-arc -I./ImGui -I./ImGui/backends -I.
Card0zoESP_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk
