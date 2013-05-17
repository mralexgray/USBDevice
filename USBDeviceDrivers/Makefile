GO_EASY_ON_ME=1
THEOS=../theos

include $(THEOS)/makefiles/common.mk

FRAMEWORK_NAME=USBDeviceDrivers
USBDeviceDrivers_FILES=iBootDevice.m
USBDeviceDrivers_FRAMEWORKS=Foundation CoreFoundation IOKit USBDeviceFramework
USBDeviceDrivers_LDFLAGS=-F../USBDeviceFramework/obj
USBDeviceDrivers_CFLAGS=-I..

include $(THEOS)/makefiles/framework.mk

