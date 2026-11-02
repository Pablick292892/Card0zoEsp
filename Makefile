ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Oxide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp

# Добавляем исходники Dobby и наш main
Card0zoEsp_FILES = main.mm $(wildcard Dobby/source/*.cc) $(wildcard Dobby/source/*.c) $(wildcard Dobby/builtin-plugin/*.cc)

# Указываем компилятору, где искать заголовки (dobby.h)
Card0zoEsp_CFLAGS = -I./Dobby/include -I./fishhook

Card0zoEsp_LDFLAGS = -undefined dynamic_lookup -framework UIKit -framework Foundation -framework Security

include $(THEOS_MAKE_PATH)/tweak.mk
