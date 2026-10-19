export TARGET = iphone:clang:latest:14.0
export ARCHS = arm64

export ADDITIONAL_CCFLAGS = -std=c++17 -Wno-error=unused-variable

INSTALL_TARGET_PROCESSES = CounterFlame

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoESP
Card0zoESP_FILES = main.mm
Card0zoESP_CFLAGS = -fobjc-arc -I.
Card0zoESP_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
Card0zoESP_LDFLAGS = -lstdc++

include $(THEOS_MAKE_PATH)/tweak.mk
