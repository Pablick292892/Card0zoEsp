export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoESP
# Ищем main.mm и fishhook.c ТОЛЬКО внутри папки libtitanox
Card0zoESP_FILES = main.mm $(shell find libtitanox -name "main.mm") $(shell find libtitanox -name "fishhook.c") ImGui/imgui.cpp ImGui/imgui_draw.cpp ImGui/imgui_tables.cpp ImGui/imgui_widgets.cpp ImGui/backends/imgui_impl_metal.mm
Card0zoESP_CFLAGS = -fobjc-arc -std=c++17 -I./ImGui -I./ImGui/backends -I./libtitanox -I./libtitanox/fishhook -I./libtitanox/libtitanox -I.
Card0zoESP_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk
