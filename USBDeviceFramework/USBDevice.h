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

typedef enum {
    kUSBDeviceErrorSuccess = 0,
    kUSBDeviceErrorIO,
    kUSBDeviceErrorUnsuccessful
} kUSBDeviceErrorStatus;

@interface USBDevice : NSObject {
    int _currentVid;
    int _currentPid;
    int _currentConfiguration;
    int _currentInterface;
    int _currentAlternateInterface;
    IOCFPlugInInterface** _currentPlugInInterface;
    IOUSBDeviceInterface320** _currentDeviceInterface;
    IOUSBInterfaceInterface197** _currentInterfaceInterface;
}
#pragma mark - class methods
+(NSArray*)copyDevicesWithMatchingClass:(int)deviceClass;
+(NSArray*)getAllAttachedDevices;

#pragma mark - initializers
-(USBDevice*)openDeviceWithVid:(uint16_t)vendorId withPid:(uint16_t)productId;

#pragma mark - transfer routines
-(int)controlTransfer:(controlPacketRef)packet withTimeout:(uint32_t)timeout;
-(int)bulkTransfer:(uint8_t)endpoint withData:(uint8_t *)data withLength:(int)length withTimeout:(uint32_t)timeout;
-(int)setConfiguration:(int)configuration;
-(int)setInterface:(int)interface withAlternateInterface:(int)altInterface;
-(int)resetDevice;

#pragma mark - information
-(NSDictionary*)enumerateDeviceInformation;

#pragma mark - properties
@property(copy, nonatomic) NSString* deviceSerialNumber;
@property(copy, nonatomic) NSString* deviceFriendlyName;

@end
