TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES = CF

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = Card0zoEsp
Card0zoEsp_FILES = main.mm
Card0zoEsp_CFLAGS = -fobjc-arc -I./fishhook
Card0zoEsp_FRAMEWORKS = UIKit Foundation
Card0zoEsp_LIBRARIES = substrate
Card0zoEsp_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/library.mk
