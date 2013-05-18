THEOS=theos

include $(THEOS)/makefiles/common.mk

SUBPROJECTS=USBDeviceFramework USBDeviceDrivers USBDeviceFrameworkTestTool
include $(THEOS)/makefiles/aggregate.mk

