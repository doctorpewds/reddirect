TARGET := iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ReddirectPrefs

ReddirectPrefs_FILES = ReddirectPrefsRootListController.m
ReddirectPrefs_FRAMEWORKS = UIKit
ReddirectPrefs_PRIVATE_FRAMEWORKS = Preferences
ReddirectPrefs_INSTALL_PATH = /Library/PreferenceBundles
ReddirectPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
