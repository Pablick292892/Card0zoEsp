TARGET = Card0zoESP
ARCHS = arm64
INSTALL_TARGET_PROCESSES = OXIDE

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = $(TARGET)
$(TARGET)_FILES = main.cpp
$(TARGET)_CFLAGS = -fobjc-arc -I./imgui -I./keyauth
$(TARGET)_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
$(TARGET)_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk
