//
//  SFBLEDevice.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@protocol SFBLEDeviceDelegate;
@class SFBLEDeviceFinder;




@interface SFBLEDevice : NSObject

@property (nonatomic, assign) NSObject<SFBLEDeviceDelegate>* delegate;

// do not forget to set the delegate before calling
- (void)link;
// If the device is still in the linking process you will be sent
// device:failedToLink: (with an error SFBluetoothSmartErrorLinkingCancelled)
// otherwise device:unliked:
- (void)unlink;

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSUUID*   identifier;
/// Battery level of device in percent (100 is fully charged, 0 is fully discharged)
@property (nonatomic, readonly) NSNumber* batteryLevel;

- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID;
- (void)writeValue:(NSData*)value forCharacteristic:(CBUUID*)characteristicUUID;
- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID;
- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID;

@end




@protocol SFBLEDeviceDelegate
- (void)deviceLinkedSuccessfully:(SFBLEDevice*)device;
// The device encountered an error, which prohibits a continuation of the linking process.
- (void)device:(SFBLEDevice*)SFBLEDevice failedToLink:(NSError*)error;

// This method can only be called if deviceLinkedSuccessfully has
// been called before. Then it signifies that:
//  * the device broke the link (e.g. out of range, powered down, error)
//  * the link has been canceled by the unlink method
//  * bluetooth has gone from on to off/unavailable/…
- (void)device:(SFBLEDevice*)SFBLEDevice unlinked:(NSError*)error;

- (void)device:(SFBLEDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid;
@end
