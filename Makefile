THEOS=theos

include $(THEOS)/makefiles/common.mk

SUBPROJECTS=USBDeviceFramework USBDeviceFrameworkTestTool
include $(THEOS)/makefiles/aggregate.mk

