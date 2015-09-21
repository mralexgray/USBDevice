//
// USBDeviceFrameworkTestTool
//

@import USBDeviceFramework;
@import AppKit;

int main()
{
    [NSApplication sharedApplication];

    NSLog(@"%@", [USBDevice.getAllAttachedDevices valueForKey:@"DeviceFriendlyName"]);

    [JGRUSBDeviceMonitor.new monitorForUSBDevicesWithConnectedBlock:^(NSDictionary *device) {

      NSLog(@"connected: %@", device);

    } removedBlock:^(NSDictionary *device) {

      NSLog(@"disconnected: %@", device);

    }];

    return [NSApp run], 0;
}
