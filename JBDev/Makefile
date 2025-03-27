THEOS_DEVICE_IP 	= 127.0.0.1
THEOS_DEVICE_PORT 	= 22
TARGET 				= iphone:clang:latest
ARCHS 				= arm64 arm64e

JBROOT				= $(shell echo ${THEOS_PACKAGE_INSTALL_PREFIX} | sed 's/\//\\\//g')

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = jbdev_tweak
${TWEAK_NAME}_FILES = jbdev_tweak.mm utils.mm
${TWEAK_NAME}_CFLAGS = -fobjc-arc -std=c++11
include $(THEOS_MAKE_PATH)/tweak.mk

TOOL_NAME = jbdev_daemon
${TOOL_NAME}_FILES = jbdev_daemon.mm utils.mm
${TOOL_NAME}_CFLAGS = -fobjc-arc -std=c++11
${TOOL_NAME}_LDFLAGS = -framework CoreServices
${TOOL_NAME}_CODESIGN_FLAGS = -Sjbdev_daemon.plist
${TOOL_NAME}_INSTALL_PATH = /usr/bin
include $(THEOS_MAKE_PATH)/tool.mk

before-stage::
	cp -rfp layout_template/* layout/
	sed -i '' "s/@@JBROOT@@/${JBROOT}/g" $(wildcard layout/DEBIAN/*)
	sed -i '' "s/@@JBROOT@@/${JBROOT}/g" $(wildcard layout/Library/LaunchDaemons/*)

