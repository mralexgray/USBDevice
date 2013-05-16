GO_EASY_ON_ME=1
THEOS=../theos

include $(THEOS)/makefiles/common.mk

TOOL_NAME=USBDeviceFrameworkTestTool
USBDeviceFrameworkTestTool_FILES=Main.m
USBDeviceFrameworkTestTool_CFLAGS=-I../
USBDeviceFrameworkTestTool_LDFLAGS=-F../USBDeviceFramework/obj
USBDeviceFrameworkTestTool_FRAMEWORKS=Foundation CoreFoundation IOKit USBDeviceFramework

include $(THEOS)/makefiles/tool.mk
