//
// USBDeviceFrameworkTestTool
//

@import USBDeviceFramework;
@import AppKit;

#define LOG_EVENT(event) printf( "" #event " device: %s\n", device.description.UTF8String);

int main()
{
    [NSApplication sharedApplication];

    NSLog(@"%@", [USBDevice.getAllAttachedDevices valueForKey:@"DeviceFriendlyName"]);

    [USBDevice monitorConnected:^(NSDictionary *device){ LOG_EVENT(CONNECTED); }
                        removed:^(NSDictionary *device){ LOG_EVENT(REMOVED);   }];

    return [NSApp run], 0;
}
