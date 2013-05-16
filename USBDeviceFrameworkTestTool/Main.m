//
// USBDeviceFrameworkTestTool
//

#import <USBDeviceFramework/USBDevice.h>

int main(int argc, char* argv[])
{
    USBDevice *mouse = [[USBDevice alloc] openDeviceWithVid:1133 withPid:49164];
    NSLog(@"Friendly name: %@", [mouse deviceFriendlyName]);
    NSLog(@"Serial: %@", [mouse deviceSerialNumber]);
    return 0;
}