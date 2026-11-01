ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Oxide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp
# Добавляем main.mm и fishhook.c
Card0zoEsp_FILES = main.mm fishhook.c
# Говорим компилятору искать заголовки в текущей директории
Card0zoEsp_CFLAGS = -I.
Card0zoEsp_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
