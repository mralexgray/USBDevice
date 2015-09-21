//
// USBDeviceFrameworkTestTool
//

@import USBDeviceFramework;
@import AppKit;

int main()
{
    [NSApplication sharedApplication];

//    NSLog(@"%@", [USBDevice.getAllAttachedDevices valueForKey:@"DeviceFriendlyName"]);

    JGRUSBDeviceMonitor *usbDeviceMonitor = JGRUSBDeviceMonitor.new;

    [usbDeviceMonitor monitorForUSBDevicesWithConnectedBlock:^(NSDictionary *device) {
      NSLog(@"connected: %@", device);

    } removedBlock:^(NSDictionary *device) {
            NSLog(@"disconnected: %@", device);

    }];
    [NSApp run];
    return 0;
}
