//
// USBDeviceFrameworkTestTool
//

#import <USBDeviceFramework/USBDevice.h>

int main(int argc, char* argv[])
{
    NSLog(@"%@", [USBDevice getAllAttachedDevices]);
    return 0;
}
