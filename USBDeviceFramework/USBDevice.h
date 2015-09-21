//
//  USBDevice.h
//  USBDeviceFramework
//
//  Created by rms on 5/15/13.
//  Copyright (c) 2013 rms. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOCFPlugIn.h>

typedef struct __controlPacket {
    uint8_t bmRequestType;
    uint8_t bRequest;
    uint16_t wValue;
    uint16_t wIndex;
    uint8_t* data;
    uint16_t wLength;
} controlPacket, *controlPacketRef;

#define MakeRequest(packet, _bmRequestType, _bRequest, _wValue, _wIndex, _data, _wLength) \
    do {                                        \
        packet.bmRequestType = _bmRequestType;  \
        packet.bRequest = _bRequest;            \
        packet.wValue = _wValue;                \
        packet.wIndex = _wIndex;                \
        packet.data = _data;                    \
        packet.wLength = _wLength;              \
    } while(0);

typedef enum {
    kUSBDeviceErrorSuccess = 0,
    kUSBDeviceErrorIO,
    kUSBDeviceErrorUnsuccessful,
    kUSBDeviceErrorUnsupported
} kUSBDeviceErrorStatus;

/**
 The USBDevice class provides low level USB primitives (control, bulk, interrupt and isochronous) for transfers
 for any arbitrary device.
 
 To use the class, use the `-openDeviceWithVid:` method on an allocated USBDevice object.
 You may then send transfers when you wish on the specified object.
 
 Note that if the device fails to be opened, an assertion will be thrown in USBDeviceFramework.
 */
@interface USBDevice : NSObject {
    int _currentVid;
    int _currentPid;
    int _currentConfiguration;
    int _currentInterface;
    uint8_t _currentAlternateInterface;
    IOCFPlugInInterface** _currentPlugInInterface;
    IOUSBDeviceInterface320** _currentDeviceInterface;
    IOUSBInterfaceInterface197** _currentInterfaceInterface;
}
#pragma mark - class methods
/**
 Copy out a NSDictionary containing classes matched to a specific device class.
 
 Device class constants come from the `bDeviceClass` member of the device USB descriptor. 
 A list can be found in IOKit/usb/USBSpec.h.
 
 @param deviceClass Specified device class.
 */
+(NSArray*)copyDevicesWithMatchingClass:(int)deviceClass;

/**
 Copy out an NSArray of all attached devices on the system.
 
 This array includes device name, vendor/product ID, available bus power, parsed configuration descriptors and more.
 */
+(NSArray*)getAllAttachedDevices;

#pragma mark - initializers
/**
 Open a specified device based on its product and vendor identifier.
 
 This device is opened for exclusive access. Deallocate the class to remove all active handles on the device.
 
 @param vendorId Specified device vendor identifier. (example: 0x05AC is Apple.)
 @param productId Specified product device identifier. (example: 0x1227 is an iPhone in DFU mode.)
 */
-(USBDevice*)openDeviceWithVid:(uint16_t)vendorId withPid:(uint16_t)productId;

#pragma mark - transfer routines
/**
 Send a control transfer to the device with a specified timeout.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param packet Specified control transfer packet.
 @param timeout Specified timeout for packet.
 @param transferred Bytes transferred during operation.
 */
-(int)controlTransfer:(controlPacketRef)packet withTimeout:(uint32_t)timeout withTransferred:(uint32_t*)transferred;

/**
 Write to the device using a bulk/interrupt endpoint.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param endpoint Device endpoint for communication.
 @param data Buffer containing data to send.
 @param length Size of the buffer containing data.
 @param timeout Specified timeout for packet.
 */
-(int)bulkTransfer:(uint8_t)endpoint withData:(uint8_t *)data withLength:(int)length withTimeout:(uint32_t)timeout;

/**
 Read from the device using a bulk/interrupt endpoint.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param endpoint Device endpoint for communication.
 @param data Buffer containing data to be read.
 @param lengthOutput Length read from the device. The length of the buffer should be greater or equal to than the length read.
 @param timeout Specified timeout for packet.
 */
-(int)bulkTransferRead:(uint8_t)endpoint withData:(uint8_t *)data withLengthOutput:(uint32_t*)lengthOutput withTimeout:(uint32_t)timeout;

/**
 Send an isochronous packet to the device.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param pipeRef Specified USB endpoint for communication.
 @param data Data buffer to send.
 @param frameStart Specified frame to start from.
 @param numFrames Number of frames to send.
 @param isocFrame A pointer to the IOUSBIsocFrame structure for the packet.
 */
-(int)isochronousWrite:(uint8_t)pipeRef withData:(uint8_t*)data withFrameStart:(uint64_t)frameStart withNumberOfFrames:(uint32_t)numFrames withFrameList:(IOUSBIsocFrame*)isocFrame;

/**
 Read an isochronous packet from the device.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param pipeRef Specified USB endpoint for communication.
 @param data Data buffer to read.
 @param frameStart Specified frame to start from.
 @param numFrames Number of frames to send.
 @param isocFrame A pointer to the IOUSBIsocFrame structure for the packet.
 */
-(int)isochronousRead:(uint8_t)pipeRef withData:(uint8_t*)data withFrameStart:(uint64_t)frameStart withNumberOfFrames:(uint32_t)numFrames withFrameList:(IOUSBIsocFrame*)isocFrame;

/**
 Set device configuration for specified device.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param configuration Specified configuration to set.
 */
-(int)setConfiguration:(int)configuration;

/**
 Set device interface endpoint/alternate interface for specified device.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 
 @param interface Specified interface to set.
 @param altInterface Alternate interface to set.
 */
-(int)setInterface:(int)interface withAlternateInterface:(int)altInterface;

/**
 Reset the device.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 */
-(int)resetDevice;

/**
 Reenumerate the device. This simulates an unplug and enumerates the device again as if it had been plugged in.
 
 @return See the `kUSBDeviceErrorStatus` enum.
 */
-(int)reenumerateDevice;

#pragma mark - information

/**
 Returns an NSDictionary containing device information similar to `+getAllAttachedDevices` but only for the
 currently opened device.
 */
-(NSDictionary*)enumerateDeviceInformation;

#pragma mark - properties
/**
 Opened device serial number as per the `USB Serial Number` property in the I/O registry.
 */
@property(copy, nonatomic) NSString* deviceSerialNumber;

/**
 Opened device friendly name as per its owner node in the I/O registry.
 */
@property(copy, nonatomic) NSString* deviceFriendlyName;

#pragma mark - properties

/**
 Monitor connected/disconnected devices.
 */
+ (void) monitorConnected:(void(^)(NSDictionary *device))connected
                  removed:(void(^)(NSDictionary *device))removed;

@end
