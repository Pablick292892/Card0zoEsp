ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Oxide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp
# Добавляем файлы fishhook (проверь названия файлов внутри папки, обычно это fishhook.c)
Card0zoEsp_FILES = main.mm $(wildcard рыболовный\ крючок/*.c) $(wildcard рыболовный\ крючок/*.m)
Card0zoEsp_CFLAGS = -I"рыболовный крючок"
Card0zoEsp_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
