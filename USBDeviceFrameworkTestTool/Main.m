//
// USBDeviceFrameworkTestTool
//

#import <USBDeviceFramework/USBDevice.h>
#import <USBDeviceDrivers/iBootDevice.h>

int main(int argc, char* argv[])
{
    iBootDevice *ibootDevice = (iBootDevice*)[[iBootDevice alloc] openDeviceWithVid:0x5AC withPid:0x1281];
    [ibootDevice setConfiguration:1];
    [ibootDevice setInterface:0 withAlternateInterface:0];
    [ibootDevice sendCommand:"reboot"];
    return 0;
}
