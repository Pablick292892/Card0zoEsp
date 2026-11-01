ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Oxide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp

# Указываем путь к fishhook.c
Card0zoEsp_FILES = main.mm fishhook/fishhook.c

# Указываем компилятору искать заголовки в папке fishhook
Card0zoEsp_CFLAGS = -I./fishhook

Card0zoEsp_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
