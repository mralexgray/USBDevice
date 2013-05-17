//
//  iBootDevice.m
//  USBDeviceFramework
//
//  Created by rms on 5/16/13.
//  Copyright (c) 2013 rms. All rights reserved.
//

#import "iBootDevice.h"
#include <assert.h>

@implementation iBootDevice

-(int)sendCommand:(const char*)command {
    uint16_t length = (uint16_t)strlen(command);
    controlPacket packet;
    uint32_t transferredAmount = 0;
    
    if(_currentPid == kUSBAppleiBootDevice)
        return kUSBDeviceErrorUnsupported;
    
    if(length >= 0x100)
        length = 0xFF;
    
    if(length) {
        MakeRequest(packet, 0x40, 0, 0, 0, (uint8_t*)command, length + 1);
        [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
    }
    
    return kUSBDeviceErrorSuccess;
}

-(int)sendBuffer:(uint8_t*)buffer withSize:(uint32_t)size notifyDfu:(int)notify {
    boolean_t isRecoveryDevice = false;
    uint32_t packetSize = 0x800;                 // could be changed to 32kB
    uint32_t lastPacket = size % packetSize;
    uint32_t packets = size / packetSize;
    uint32_t i;
    uint32_t transferredAmount;
    int errorStatus;
    controlPacket packet;
    
    // Set packet sizes
    if(lastPacket)
        packets++;
    else
        lastPacket = packetSize;
    
    // Verify recovery mode
    if(self->_currentPid == kUSBAppleiBootDevice)
        isRecoveryDevice = true;
    
    // Start transfer
    if(isRecoveryDevice == true) {
        MakeRequest(packet, 0x41, 0, 0, 0, nil, 0);
        errorStatus = [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
        assert(errorStatus == kUSBDeviceErrorSuccess);
    } else {
        MakeRequest(packet, 0x21, 4, 0, 0, nil, 0);
        errorStatus = [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
        assert(errorStatus == kUSBDeviceErrorSuccess);
    }
    
    // Send packets
    for(i = 0; i < packets; i++) {
        uint32_t __size = (i + 1) < packets ? packetSize : lastPacket;
        uint32_t status;
        
        // Use bulk transfer if an iBoot device
        if(isRecoveryDevice) {
            errorStatus = [self bulkTransfer:0x04 withData:&buffer[i * packetSize] withLength:(int)__size withTimeout:1000];
            assert(errorStatus == kUSBDeviceErrorSuccess);
        } else {
            MakeRequest(packet, 0x21, 1, 0, 0, &buffer[i * packetSize], (uint16_t)__size);
            errorStatus = [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
            assert(errorStatus == kUSBDeviceErrorSuccess);
        }
        
        if(transferredAmount != __size)
            NSLog(@"Failed to transmit all bytes, transmitted %d out of %d", transferredAmount, __size);
        
        // Get status
        if(isRecoveryDevice == false) {
            uint8_t buf[6];
            memset(buf, 0, 6);
            MakeRequest(packet, 0xA1, 3, 0, 0, buf, 6);
            errorStatus = [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
            assert(errorStatus == kUSBDeviceErrorSuccess);
            if(transferredAmount != 6)
                status = 0;
            status = buf[4];
        }
        
        // Get it again..
        if((isRecoveryDevice == false) && (status != 5)) {
            NSLog(@"Failed to transmit, status %d", status);
            return kUSBDeviceErrorIO;
        }
    }
    
    if(notify && (isRecoveryDevice == false)) {
        MakeRequest(packet, 0x21, 1, 0, 0, (uint8_t*)buffer, 0);
        errorStatus = [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
        assert(errorStatus == kUSBDeviceErrorSuccess);
        for(i = 0; i < 3; i++) {
            uint8_t buf[6];
            memset(buf, 0, 6);
            MakeRequest(packet, 0xA1, 3, 0, 0, buf, 6);
            errorStatus = [self controlTransfer:&packet withTimeout:1000 withTransferred:&transferredAmount];
            assert(errorStatus == kUSBDeviceErrorSuccess);
        }
        errorStatus = [self resetDevice];
        assert(errorStatus == kUSBDeviceErrorSuccess);
    }
    
    return kUSBDeviceErrorSuccess;
}


@end
