export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

export ADDITIONAL_CCFLAGS = -std=c++17 -Wno-error=unused-variable -Wno-deprecated-declarations

INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = Card0zoESP

# УБРАЛИ ВСЕ ImGui ФАЙЛЫ — собираем только байпас
Card0zoESP_FILES = main.mm fishhook/fishhook.c
Card0zoESP_CFLAGS = -fobjc-arc -I./fishhook -I.
Card0zoESP_FRAMEWORKS = UIKit Foundation
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/library.mk
