TARGET := iphone:clang:latest:10.0
ARCHS = arm64
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = MobileSafari SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Reddirect
Reddirect_FILES = Tweak.x
Reddirect_CFLAGS = -fobjc-arc
Reddirect_FRAMEWORKS = UIKit WebKit SafariServices

include $(THEOS_MAKE_PATH)/tweak.mk
