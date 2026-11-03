ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = CounterFlame

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp
Card0zoEsp_FILES = main.mm
Card0zoEsp_CFLAGS = -fobjc-arc
Card0zoEsp_LDFLAGS = -undefined dynamic_lookup -framework UIKit -framework Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
