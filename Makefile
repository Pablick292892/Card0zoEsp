ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Oxide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Card0zoEsp

Card0zoEsp_FILES = main.mm $(wildcard Dobby/source/*.cc) $(wildcard Dobby/source/*.c) $(wildcard Dobby/source/*.cpp) $(wildcard Dobby/source/common/*.cc) $(wildcard Dobby/source/common/*.c) $(wildcard Dobby/builtin-plugin/*.cc) $(wildcard Dobby/builtin-plugin/*.cpp) $(wildcard Dobby/external/logging/*.cc) $(wildcard Dobby/external/logging/*.c) $(wildcard Dobby/external/osbase/*.cc) $(wildcard Dobby/external/osbase/*.c)

Card0zoEsp_CFLAGS = -I./Dobby/include -I./Dobby/source -I./Dobby/source/dobby -I./Dobby/source/common -I./Dobby/external -I./Dobby/external/logging -I./Dobby/external/logging/logging -I./Dobby/external/osbase -I./Dobby/external/TINYSTL -I./fishhook -Wno-module-import-in-extern-c

Card0zoEsp_LDFLAGS = -undefined dynamic_lookup -framework UIKit -framework Foundation -framework Security

include $(THEOS_MAKE_PATH)/tweak.mk
