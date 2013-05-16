//
//  USBDevice.m
//  USBDeviceFramework
//
//  Created by rms on 5/15/13.
//  Copyright (c) 2013 rms. All rights reserved.
//

#import "USBDevice.h"
#import <assert.h>

@implementation USBDevice
@synthesize deviceFriendlyName, deviceSerialNumber;

#pragma mark - Overrides
-(void)dealloc {
    if(_currentInterfaceInterface) {
        (*_currentInterfaceInterface)->USBInterfaceClose(_currentInterfaceInterface);
        (*_currentInterfaceInterface)->Release(_currentInterfaceInterface);
    }
    if(_currentDeviceInterface) {
        (*_currentDeviceInterface)->USBDeviceClose(_currentDeviceInterface);
        (*_currentDeviceInterface)->Release(_currentDeviceInterface);
    }
    [self resetIvars];
    [super dealloc];
}

#pragma mark - Private methods.

-(void)resetIvars {
    _currentInterface = 0;
    _currentAlternateInterface = 0;
    _currentDeviceInterface = nil;
    _currentInterfaceInterface = nil;
    _currentPid = 0x0000;
    _currentVid = 0x0000;
    return;
}

+(NSString*)stringForSpeed:(uint8_t)deviceSpeed {
    switch(deviceSpeed) {
        case kUSBDeviceSpeedFull:
            return @"Full-Speed";
        case kUSBDeviceSpeedHigh:
            return @"High-Speed";
        case kUSBDeviceSpeedLow:
            return @"Low-Speed";
        case 3:                 // Super-Speed
            return @"Super-Speed";
        default:
            return @"Unknown";
    }
    return nil;
}

+(NSDictionary*)parseConfigurationDescriptor:(IOUSBConfigurationDescriptorPtr)descriptor {
    int descriptorLength;
    uint8_t *currentDescriptor = NULL;
    uint8_t *endingDescriptor = NULL;
    NSMutableDictionary* configurationDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    // The dictionary must EXIST.
    assert(configurationDictionary != NULL);
    
    // Verify object exists.
    assert(descriptor != NULL && "Null device descriptors are not allowed, kind sir.");
    
    // Get length and parse descriptors.
    currentDescriptor = (uint8_t*)descriptor;
    descriptorLength = descriptor->wTotalLength;
    endingDescriptor = ((uint8_t*)descriptor) + descriptorLength;
    
    [configurationDictionary setObject:[NSNumber numberWithInt:descriptor->MaxPower] forKey:@"MaxPower"];
    [configurationDictionary setObject:[NSNumber numberWithInt:descriptor->wTotalLength] forKey:@"TotalLength"];
    
    // This is a horrible horrible thing. But it works for the most part.
    while(currentDescriptor < endingDescriptor) {
        IOUSBConfigurationDescriptor* castedDescriptor = (IOUSBConfigurationDescriptor*)currentDescriptor;
        uint8_t length, type;
        
        assert(castedDescriptor != NULL);
        
        length = castedDescriptor->bLength;
        type = castedDescriptor->bDescriptorType;
        
        // Add the specific type to the dictionary.
        if(length) {
            switch(type) {
                // This is an interface.
                case kUSBInterfaceDesc: {
                    IOUSBInterfaceDescriptorPtr interfaceDescriptor = (IOUSBInterfaceDescriptorPtr)currentDescriptor;
                    NSMutableDictionary* interfaceDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
    
                    assert(interfaceDictionary != NULL);

                    // Add interface crap to subdictionary.
                    [interfaceDictionary setObject:[NSNumber numberWithInt:interfaceDescriptor->bInterfaceNumber] forKey:@"InterfaceNumber"];
                    [interfaceDictionary setObject:[NSNumber numberWithInt:interfaceDescriptor->bInterfaceClass] forKey:@"InterfaceClass"];
                    [interfaceDictionary setObject:[NSNumber numberWithInt:interfaceDescriptor->bInterfaceSubClass] forKey:@"InterfaceSubClass"];
                    [interfaceDictionary setObject:[NSNumber numberWithInt:interfaceDescriptor->bInterfaceProtocol] forKey:@"InterfaceProtocol"];
                    [interfaceDictionary setObject:[NSNumber numberWithInt:interfaceDescriptor->bAlternateSetting] forKey:@"InterfaceAlternateSetting"];
                    
                    [configurationDictionary setObject:interfaceDictionary forKey:[NSString stringWithFormat:@"InterfaceDescriptor-%d", interfaceDescriptor->bInterfaceNumber]];
                    [interfaceDictionary release];
                    break;
                }
                // This is an endpoint.
                case kUSBEndpointDesc: {
                    IOUSBEndpointDescriptorPtr endpointDescriptor = (IOUSBEndpointDescriptorPtr)currentDescriptor;
                    NSMutableDictionary* endpointDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
    
                    assert(endpointDictionary != NULL);

                    // Add interface crap to subdictionary.
                    [endpointDictionary setObject:[NSNumber numberWithInt:endpointDescriptor->bEndpointAddress] forKey:@"EndpointAddress"];
                    [endpointDictionary setObject:[NSNumber numberWithInt:endpointDescriptor->bInterval] forKey:@"EndpointInterval"];
                    [endpointDictionary setObject:[NSNumber numberWithInt:endpointDescriptor->bmAttributes] forKey:@"EndpointAttributes"];
                    [endpointDictionary setObject:[NSNumber numberWithInt:endpointDescriptor->wMaxPacketSize] forKey:@"EndpointMaxPacketSize"];
    
                    [configurationDictionary setObject:endpointDictionary forKey:[NSString stringWithFormat:@"EndpointDescriptor-%d", endpointDescriptor->bEndpointAddress]];
                    [endpointDictionary release];
                    break;
                }
                default:
                    break;
            }
        }
        currentDescriptor += length;
    }
    return configurationDictionary;
}

#pragma mark - Initializer/class methods

+(NSArray*)getAllAttachedDevices {
    mach_port_t iokitPort = kIOMasterPortDefault;
    kern_return_t kernelStatus;
    io_iterator_t deviceIterator;
    io_service_t deviceService;
    io_name_t deviceName;
    
    // Grand dictionary of all time
    NSMutableArray* usbArray = [[NSMutableArray alloc] initWithCapacity:10];
    
    // Create initial request used to get matching services for each usb device in the system.
    // Note: on embedded we have our devices connected to AppleSynopsysEHCI, sort of like how
    // on the desktop platform, we have them on AppleUSBEHCI. Apparently the root hub simulation
    // thing went missing, or I couldn't see it in ioreg last time I checked. Whatever.
    //
    // it works, also IOUSB has gone missing on embedded. SOMEONE SHOULD FIX THAT PLEASE.
    kernelStatus = IOServiceGetMatchingServices(iokitPort, IOServiceMatching(kIOUSBDeviceClassName), &deviceIterator);
    assert(kernelStatus == KERN_SUCCESS && "Failed to get matching service");
    
    while((deviceService = IOIteratorNext(deviceIterator))) {
        SInt32 score;
        IOCFPlugInInterface** plugInInterface;
        
        // Get device name and store it.
        kernelStatus = IORegistryEntryGetName(deviceService, deviceName);
        assert(kernelStatus == KERN_SUCCESS && "Failed to obtain device name");
        
        // Create CF plugin for device, this'll be used to get information.
        kernelStatus = IOCreatePlugInInterfaceForService(deviceService, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        assert(kernelStatus == KERN_SUCCESS && "Failed to get device");
        
        // Release objects
        kernelStatus = IOObjectRelease(deviceService);
        assert(kernelStatus == KERN_SUCCESS && "Failed to release kernel objects");
        
        // Verify object exists.
        if(plugInInterface) {
            uint16_t idVendor, idProduct;
            IOUSBDeviceInterface320** deviceInterface;
            HRESULT resultingStatus;
            NSMutableDictionary* usbDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
            
            // Get device interface
            resultingStatus = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID320), (LPVOID)&deviceInterface);
            assert(resultingStatus == kIOReturnSuccess && "Failed to create plug-in interface for device");
            (*plugInInterface)->Release(plugInInterface);
            
            // Get device VID/PID.
            (*deviceInterface)->GetDeviceProduct(deviceInterface, &idProduct);
            (*deviceInterface)->GetDeviceVendor(deviceInterface, &idVendor);
            
            // Get extra information.
            uint32_t locationId, busPowerAvailable;
            uint8_t deviceSpeed, numberOfConfigurations;
            uint8_t deviceClass;
            
            (*deviceInterface)->GetLocationID(deviceInterface, &locationId);
            (*deviceInterface)->GetDeviceSpeed(deviceInterface, &deviceSpeed);
            (*deviceInterface)->GetNumberOfConfigurations(deviceInterface, &numberOfConfigurations);
            (*deviceInterface)->GetDeviceBusPowerAvailable(deviceInterface, &busPowerAvailable);
            
            (*deviceInterface)->GetDeviceClass(deviceInterface, &deviceClass);

            // Add to dictionary.
            [usbDictionary setObject:[NSNumber numberWithLong:locationId] forKey:@"LocationID"];
            [usbDictionary setObject:[NSNumber numberWithLong:busPowerAvailable] forKey:@"BusPowerAvailable"];
            [usbDictionary setObject:[USBDevice stringForSpeed:deviceSpeed] forKey:@"DeviceSpeed"];
            [usbDictionary setObject:[NSNumber numberWithInt:numberOfConfigurations] forKey:@"NumberOfConfigurations"];
            [usbDictionary setObject:[NSString stringWithUTF8String:deviceName] forKey:@"DeviceFriendlyName"];
            [usbDictionary setObject:[NSNumber numberWithInt:idVendor] forKey:@"VendorID"];
            [usbDictionary setObject:[NSNumber numberWithInt:idProduct] forKey:@"ProductID"];
            [usbDictionary setObject:[NSNumber numberWithInt:deviceClass] forKey:@"DeviceClass"];

            // Add configuration descriptors to dictionary.
            uint8_t iteratorCount;
            for(iteratorCount = 0; iteratorCount <= numberOfConfigurations; iteratorCount++) {
                IOUSBConfigurationDescriptorPtr deviceDescriptor;
                NSDictionary *parsedConfigurationDescriptor = nil;
                
                (*deviceInterface)->GetConfigurationDescriptorPtr(deviceInterface, iteratorCount, &deviceDescriptor);
                
                if(deviceDescriptor)
                    parsedConfigurationDescriptor = [USBDevice parseConfigurationDescriptor:deviceDescriptor];
                
                if(parsedConfigurationDescriptor)
                    [usbDictionary setObject:parsedConfigurationDescriptor forKey:@"ConfigurationDescriptors"];
            }
                        
            // Add to the root array.
            [usbArray addObject:usbDictionary];
            
            // Release the dictionary.
            [usbDictionary release];
            
            // ..and other associated objects.
            (*deviceInterface)->USBDeviceClose(deviceInterface);
            (*deviceInterface)->Release(deviceInterface);
        }
    }
    
    return usbArray;
}

+(NSArray*)copyDevicesWithMatchingClass:(int)deviceClass {
    mach_port_t iokitPort = kIOMasterPortDefault;
    kern_return_t kernelStatus;
    io_iterator_t deviceIterator;
    io_service_t deviceService;
    io_name_t deviceName;
    
    // Grand dictionary of all time
    NSMutableArray* usbArray = [[NSMutableArray alloc] initWithCapacity:10];
    
    // Get devices
    kernelStatus = IOServiceGetMatchingServices(iokitPort, IOServiceMatching(kIOUSBDeviceClassName), &deviceIterator);
    assert(kernelStatus == KERN_SUCCESS && "Failed to get matching service");
    
    while((deviceService = IOIteratorNext(deviceIterator))) {
        SInt32 score;
        IOCFPlugInInterface** plugInInterface;
        
        // Get device name and store it.
        kernelStatus = IORegistryEntryGetName(deviceService, deviceName);
        assert(kernelStatus == KERN_SUCCESS && "Failed to obtain device name");
        
        // Create CF plugin for device, this'll be used to get information.
        kernelStatus = IOCreatePlugInInterfaceForService(deviceService, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        assert(kernelStatus == KERN_SUCCESS && "Failed to get device");
        
        // Release objects
        kernelStatus = IOObjectRelease(deviceService);
        assert(kernelStatus == KERN_SUCCESS && "Failed to release kernel objects");
        
        // Verify object exists.
        if(plugInInterface) {
            uint16_t idVendor, idProduct;
            IOUSBDeviceInterface320** deviceInterface;
            HRESULT resultingStatus;
            NSMutableDictionary* usbDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
            
            // Get device interface
            resultingStatus = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID320), (LPVOID)&deviceInterface);
            assert(resultingStatus == kIOReturnSuccess && "Failed to create plug-in interface for device");
            (*plugInInterface)->Release(plugInInterface);
            
            // Get device VID/PID.
            (*deviceInterface)->GetDeviceProduct(deviceInterface, &idProduct);
            (*deviceInterface)->GetDeviceVendor(deviceInterface, &idVendor);
            
            // Get extra information.
            uint32_t locationId, busPowerAvailable;
            uint8_t deviceSpeed, numberOfConfigurations;
            uint8_t __deviceClass;
            
            (*deviceInterface)->GetLocationID(deviceInterface, &locationId);
            (*deviceInterface)->GetDeviceSpeed(deviceInterface, &deviceSpeed);
            (*deviceInterface)->GetNumberOfConfigurations(deviceInterface, &numberOfConfigurations);
            (*deviceInterface)->GetDeviceBusPowerAvailable(deviceInterface, &busPowerAvailable);
            
            (*deviceInterface)->GetDeviceClass(deviceInterface, &__deviceClass);

            // Add to dictionary.
            [usbDictionary setObject:[NSNumber numberWithLong:locationId] forKey:@"LocationID"];
            [usbDictionary setObject:[NSNumber numberWithLong:busPowerAvailable] forKey:@"BusPowerAvailable"];
            [usbDictionary setObject:[USBDevice stringForSpeed:deviceSpeed] forKey:@"DeviceSpeed"];
            [usbDictionary setObject:[NSNumber numberWithInt:numberOfConfigurations] forKey:@"NumberOfConfigurations"];
            [usbDictionary setObject:[NSString stringWithUTF8String:deviceName] forKey:@"DeviceFriendlyName"];
            [usbDictionary setObject:[NSNumber numberWithInt:idVendor] forKey:@"VendorID"];
            [usbDictionary setObject:[NSNumber numberWithInt:idProduct] forKey:@"ProductID"];
            [usbDictionary setObject:[NSNumber numberWithInt:__deviceClass] forKey:@"DeviceClass"];

            // Add configuration descriptors to dictionary.
            uint8_t iteratorCount;
            for(iteratorCount = 0; iteratorCount <= numberOfConfigurations; iteratorCount++) {
                IOUSBConfigurationDescriptorPtr deviceDescriptor;
                NSDictionary *parsedConfigurationDescriptor = nil;
                
                (*deviceInterface)->GetConfigurationDescriptorPtr(deviceInterface, iteratorCount, &deviceDescriptor);
                
                if(deviceDescriptor)
                    parsedConfigurationDescriptor = [USBDevice parseConfigurationDescriptor:deviceDescriptor];
                
                if(parsedConfigurationDescriptor)
                    [usbDictionary setObject:parsedConfigurationDescriptor forKey:@"ConfigurationDescriptors"];
            }
                        
            // Add to the root array. (Only add if it matches.)
            if(__deviceClass == deviceClass)
                [usbArray addObject:usbDictionary];
            
            // Release the dictionary.
            [usbDictionary release];
            
            // ..and other associated objects.
            (*deviceInterface)->USBDeviceClose(deviceInterface);
            (*deviceInterface)->Release(deviceInterface);
        }
    }
    
    return usbArray;
}

#pragma mark - Open device

-(USBDevice*)openDeviceWithVid:(uint16_t)vendorId withPid:(uint16_t)productId {
    mach_port_t iokitPort = kIOMasterPortDefault;
    kern_return_t kernelStatus;
    io_iterator_t deviceIterator;
    io_service_t deviceService;
    io_name_t deviceName;

    // Get devices
    kernelStatus = IOServiceGetMatchingServices(iokitPort, IOServiceMatching(kIOUSBDeviceClassName), &deviceIterator);
    assert(kernelStatus == KERN_SUCCESS && "Failed to get matching service");
    
    while((deviceService = IOIteratorNext(deviceIterator))) {
        SInt32 score;
        IOCFPlugInInterface** plugInInterface;
        
        // Get name.
        kernelStatus = IORegistryEntryGetName(deviceService, deviceName);
        assert(kernelStatus == KERN_SUCCESS && "Failed to obtain device name");
        
        // Get serial.
        CFTypeRef serialNumber = IORegistryEntryCreateCFProperty(deviceService, CFSTR("USB Serial Number"), kCFAllocatorDefault, 0);
        
        // Create CF plugin for device, this'll be used to get information.
        kernelStatus = IOCreatePlugInInterfaceForService(deviceService, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        assert(kernelStatus == KERN_SUCCESS && "Failed to get device");
        
        // Release objects
        kernelStatus = IOObjectRelease(deviceService);
        assert(kernelStatus == KERN_SUCCESS && "Failed to release kernel objects");
        
        // Verify object exists.
        if(plugInInterface) {
            uint16_t idVendor, idProduct;
            IOUSBDeviceInterface320** deviceInterface;
            HRESULT resultingStatus;

            // Get device interface
            resultingStatus = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID320), (LPVOID)&deviceInterface);
            assert(resultingStatus == kIOReturnSuccess && "Failed to create plug-in interface for device");
            (*plugInInterface)->Release(plugInInterface);
            
            // Get device VID/PID.
            (*deviceInterface)->GetDeviceProduct(deviceInterface, &idProduct);
            (*deviceInterface)->GetDeviceVendor(deviceInterface, &idVendor);
            
            if(idVendor == vendorId && idProduct == productId) {
                (*deviceInterface)->USBDeviceOpen(deviceInterface);
                
                [self resetIvars];
                
                _currentVid = vendorId;
                _currentPid = productId;
                
                deviceFriendlyName = [NSString stringWithUTF8String:deviceName];
                deviceSerialNumber = serialNumber;
                
                _currentDeviceInterface = deviceInterface;
                
                return self;
            }
    
            // Release associated objects.
            (*deviceInterface)->USBDeviceClose(deviceInterface);
            (*deviceInterface)->Release(deviceInterface);
        }
    }
    
    return self;
}

-(int)setInterface:(int)interface withAlternateInterface:(int)altInterface {
    IOReturn deviceError;
    SInt32 score;
    IOUSBFindInterfaceRequest interfaceRequest;
    io_iterator_t interfaceIterator;
    io_service_t usbInterface;
    
    // Construct request
    interfaceRequest.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    interfaceRequest.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    interfaceRequest.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    interfaceRequest.bAlternateSetting = kIOUSBFindInterfaceDontCare;

    deviceError = (*_currentDeviceInterface)->CreateInterfaceIterator(_currentDeviceInterface, &interfaceRequest, &interfaceIterator);
    assert(deviceError == kIOReturnSuccess && "Failed to create interface iterator");
    
    // Release current interface if it exists
    if(_currentInterfaceInterface != nil) {
        (*_currentInterfaceInterface)->USBInterfaceClose(_currentInterfaceInterface);
        (*_currentInterfaceInterface)->Release(_currentInterfaceInterface);
    }
    
    // Go through iterators
    while((usbInterface = IOIteratorNext(interfaceIterator))) {
        IOCFPlugInInterface **plugInInterface;
        IOUSBInterfaceInterface197 **__interface;
        UInt8 num;
        
        // Create CF plugin interface
        deviceError = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        assert(deviceError == kIOReturnSuccess && "Failed to create CF Plug-In interface");
        
        // Release objects.
        IOObjectRelease(usbInterface);

        assert(plugInInterface != NULL);
        
        // Get interface.
        deviceError = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID)&__interface);
        assert(deviceError == kIOReturnSuccess && "Failed to query interface");
        
        // Check to make sure interface is valid.
        assert(__interface != NULL);
        
        // Release objects.
        (*plugInInterface)->Release(plugInInterface);
        
        // Get interface number and match it.
        deviceError = (*__interface)->GetInterfaceNumber(__interface, &num);
        assert(deviceError == kIOReturnSuccess && "Failed to get interface number");
        
        if(__interface && interface == num) {
            deviceError = (*__interface)->USBInterfaceOpen(__interface);
            assert(deviceError == kIOReturnSuccess && "Failed to open device interface");
            _currentInterfaceInterface = __interface;
        }
    }
    
    // Set alternate interface
    deviceError = (*_currentInterfaceInterface)->SetAlternateInterface(_currentInterfaceInterface, (uint8_t)altInterface);
    assert(deviceError == kIOReturnSuccess && "Failed to set alternate interface");
    
    _currentInterface = interface;
    _currentAlternateInterface = (uint8_t)interface;

    return kUSBDeviceErrorSuccess;
}

-(int)resetDevice {
    IOReturn status;
    status = (*_currentDeviceInterface)->ResetDevice(_currentDeviceInterface);
    assert(status != kIOReturnSuccess);
    return kUSBDeviceErrorSuccess;
}

-(int)setConfiguration:(int)configuration {
    IOReturn status;
    status = (*_currentDeviceInterface)->SetConfiguration(_currentDeviceInterface, (uint8_t)configuration);
    assert(status != kIOReturnSuccess);
    return kUSBDeviceErrorSuccess;
}

-(int)bulkTransfer:(uint8_t)endpoint withData:(uint8_t *)data withLength:(int)length withTimeout:(uint32_t)timeout {
    IOReturn status;
    status = (*_currentInterfaceInterface)->WritePipeTO(_currentInterfaceInterface, endpoint, data, (uint32_t)length, timeout, timeout);
    if(status != kIOReturnSuccess) {
        status = (*_currentInterfaceInterface)->ClearPipeStallBothEnds(_currentInterfaceInterface, endpoint);
        assert(status != kIOReturnSuccess);
    }
    return kUSBDeviceErrorSuccess;
}

-(int)controlTransfer:(controlPacketRef)packet withTimeout:(uint32_t)timeout {
    IOReturn status;
    IOUSBDevRequestTO deviceRequest;
    
    assert(packet != NULL);
    
    deviceRequest.bmRequestType = packet->bmRequestType;
    deviceRequest.bRequest = packet->bRequest;
    deviceRequest.wValue = packet->wValue;
    deviceRequest.wIndex = packet->wIndex;
    deviceRequest.wLength = packet->wLength;
    deviceRequest.pData = packet->data;
    deviceRequest.noDataTimeout = timeout;
    deviceRequest.completionTimeout = timeout;

    status = (*_currentInterfaceInterface)->ControlRequestTO(_currentInterfaceInterface, _currentAlternateInterface, &deviceRequest);
    assert(status != kIOReturnSuccess);
    
    return (int)deviceRequest.wLenDone;
}

-(int)reenumerateDevice {
    IOReturn errorStatus;
    errorStatus = (*_currentDeviceInterface)->USBDeviceReEnumerate(_currentDeviceInterface, 0);
    assert(errorStatus != kIOReturnSuccess);
    return kUSBDeviceErrorSuccess;
}

-(NSDictionary*)enumerateDeviceInformation {
    uint16_t idProduct, idVendor;
    uint32_t locationId, busPowerAvailable;
    uint8_t deviceSpeed, numberOfConfigurations;
    uint8_t __deviceClass;
    NSMutableDictionary* usbDictionary = [[NSMutableDictionary alloc] initWithCapacity:10];
    
    // Ensure device is open.
    assert(usbDictionary != NULL);
    assert(_currentDeviceInterface != NULL);
    
    // Get device VID/PID.
    (*_currentDeviceInterface)->GetDeviceProduct(_currentDeviceInterface, &idProduct);
    (*_currentDeviceInterface)->GetDeviceVendor(_currentDeviceInterface, &idVendor);
    
    // Get extra information.
    (*_currentDeviceInterface)->GetLocationID(_currentDeviceInterface, &locationId);
    (*_currentDeviceInterface)->GetDeviceSpeed(_currentDeviceInterface, &deviceSpeed);
    (*_currentDeviceInterface)->GetNumberOfConfigurations(_currentDeviceInterface, &numberOfConfigurations);
    (*_currentDeviceInterface)->GetDeviceBusPowerAvailable(_currentDeviceInterface, &busPowerAvailable);
    
    (*_currentDeviceInterface)->GetDeviceClass(_currentDeviceInterface, &__deviceClass);
    
    // Add to dictionary.
    [usbDictionary setObject:[NSNumber numberWithLong:locationId] forKey:@"LocationID"];
    [usbDictionary setObject:[NSNumber numberWithLong:busPowerAvailable] forKey:@"BusPowerAvailable"];
    [usbDictionary setObject:[USBDevice stringForSpeed:deviceSpeed] forKey:@"DeviceSpeed"];
    [usbDictionary setObject:[NSNumber numberWithInt:numberOfConfigurations] forKey:@"NumberOfConfigurations"];
    [usbDictionary setObject:deviceFriendlyName forKey:@"DeviceFriendlyName"];
    [usbDictionary setObject:[NSNumber numberWithInt:idVendor] forKey:@"VendorID"];
    [usbDictionary setObject:[NSNumber numberWithInt:idProduct] forKey:@"ProductID"];
    [usbDictionary setObject:[NSNumber numberWithInt:__deviceClass] forKey:@"DeviceClass"];
    
    // Add configuration descriptors to dictionary.
    uint8_t iteratorCount;
    for(iteratorCount = 0; iteratorCount <= numberOfConfigurations; iteratorCount++) {
        IOUSBConfigurationDescriptorPtr deviceDescriptor;
        NSDictionary *parsedConfigurationDescriptor = nil;
        
        (*_currentDeviceInterface)->GetConfigurationDescriptorPtr(_currentDeviceInterface, iteratorCount, &deviceDescriptor);
        
        if(deviceDescriptor)
            parsedConfigurationDescriptor = [USBDevice parseConfigurationDescriptor:deviceDescriptor];
        
        if(parsedConfigurationDescriptor)
            [usbDictionary setObject:parsedConfigurationDescriptor forKey:@"ConfigurationDescriptors"];
    }
    
    return usbDictionary;
}

-(int)isochronousWrite:(uint8_t)pipeRef withData:(uint8_t*)data withFrameStart:(uint64_t)frameStart withNumberOfFrames:(uint32_t)numFrames withFrameList:(IOUSBIsocFrame*)isocFrame {
    IOReturn errorStatus;
    errorStatus = (*_currentInterfaceInterface)->WriteIsochPipeAsync(_currentInterfaceInterface, pipeRef, data, frameStart, numFrames, isocFrame, nil, nil);
    assert(errorStatus != kIOReturnSuccess);
    return kUSBDeviceErrorSuccess;
}

-(int)isochronousRead:(uint8_t)pipeRef withData:(uint8_t*)data withFrameStart:(uint64_t)frameStart withNumberOfFrames:(uint32_t)numFrames withFrameList:(IOUSBIsocFrame*)isocFrame {
    IOReturn errorStatus;
    errorStatus = (*_currentInterfaceInterface)->ReadIsochPipeAsync(_currentInterfaceInterface, pipeRef, data, frameStart, numFrames, isocFrame, nil, nil);
    assert(errorStatus != kIOReturnSuccess);
    return kUSBDeviceErrorSuccess;
}

-(int)bulkTransferRead:(uint8_t)endpoint withData:(uint8_t *)data withLengthOutput:(uint32_t*)lengthOutput withTimeout:(uint32_t)timeout {
    IOReturn status;
    
    status = (*_currentInterfaceInterface)->ReadPipeTO(_currentInterfaceInterface, endpoint, data, lengthOutput, timeout, timeout);
    if(status != kIOReturnSuccess) {
        status = (*_currentInterfaceInterface)->ClearPipeStallBothEnds(_currentInterfaceInterface, endpoint);
        assert(status != kIOReturnSuccess);
    }
    return kUSBDeviceErrorSuccess;
}

@end
