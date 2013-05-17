//
//  iBootDevice.h
//  USBDeviceFramework
//
//  Created by rms on 5/16/13.
//  Copyright (c) 2013 rms. All rights reserved.
//

#import <USBDeviceFramework/USBDeviceFramework.h>

#define kUSBAppleVendor         0x05AC
#define kUSBAppleDFUDevice      0x1227
#define kUSBAppleiBootDevice    0x1281

/**
 This class implements DFU file transfer for iBoot devices. These devices include
 the iPhone, iPad and iPod touch.
 
 iBootDevice is used as an example to show off the powers of the USBDeviceFramework application
 framework.
 */
@interface iBootDevice : USBDevice {
}

/**
 Send a file buffer to the specified DFU device.
 
 This function works on both DFU/iBoot devices (conforming to protocols past iBoot in iPhone OS version 3.0 and onwards).
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param buffer User specified buffer for file transfer. This buffer can contain an Image3 file or other arbitrary data.
 @param size Size of the buffer for file transfer.
 @param notify Notify device to finish DFU transfer. (This does not apply for iBoot mode.)
 @warning Please note, the specified mode of file transfer is automatically detected based on the opened device. Close and re-open the device on a change of VID/PID.
 */
-(int)sendBuffer:(uint8_t*)buffer withSize:(uint32_t)size notifyDfu:(int)notify;

/**
 Send a command to the specified iBoot device.
 
 This function works only iBoot devices (conforming to protocols past iBoot in iPhone OS version 3.0 and onwards).
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param command User-specified command to send to device.
 @warning This method does not work on DFU devices, it will return `kUSBDeviceErrorUnsupported` on call.
 */
-(int)sendCommand:(const char*)command;

@end
