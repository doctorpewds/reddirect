TARGET := iphone:clang:latest:10.0
export ARCHS = arm64
FINALPACKAGE = 1
INSTALL_TARGET_PROCESSES = MobileSafari SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Reddirect
Reddirect_FILES = Tweak.x
Reddirect_CFLAGS = -fobjc-arc
Reddirect_FRAMEWORKS = UIKit WebKit

include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += ReddirectPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
