ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Oxide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp

# Собираем наш код и все исходники Dobby
Card0zoEsp_FILES = main.mm $(wildcard Dobby/source/*.cc) $(wildcard Dobby/source/*.c) $(wildcard Dobby/source/*.cpp) $(wildcard Dobby/builtin-plugin/*.cc) $(wildcard Dobby/builtin-plugin/*.cpp)

# Указываем ВСЕ возможные пути к заголовкам, включая вложенные папки
Card0zoEsp_CFLAGS = -I./Dobby/include -I./Dobby/source -I./Dobby/source/dobby -I./Dobby/source/external -I./Dobby/builtin-plugin -I./Dobby/external -I./Dobby/third_party -I./fishhook -Wno-module-import-in-extern-c

Card0zoEsp_LDFLAGS = -undefined dynamic_lookup -framework UIKit -framework Foundation -framework Security

include $(THEOS_MAKE_PATH)/tweak.mk
