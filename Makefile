ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IG444FullScreen

IG444FullScreen_FILES = Tweak.xm
IG444FullScreen_FRAMEWORKS = UIKit
IG444FullScreen_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function

include $(THEOS_MAKE_PATH)/tweak.mk
