//
//  SFBluetoothSmartDevice.h
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 SimpliFlow. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SFBluetoothSmartDeviceManager.h"


@protocol SFBluetoothSmartDeviceDelegate;

// Will try to connect as long as it is in existence

@interface SFBluetoothSmartDevice : NSObject <CBPeripheralDelegate, SFBluetoothSmartDeviceManagerDelegate>

+ (instancetype)withTheseServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services andIdentifyingItselfWith:(NSUUID*)identifier;

@property (nonatomic, assign) NSObject<SFBluetoothSmartDeviceDelegate>* delegate;
@property (nonatomic, readonly) NSDictionary* servicesWithCharacteristics;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly) NSError* error;
@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSUUID* identifier;
/// Battery level of device in percent (100 is fully charged, 0 is fully discharged)
@property (nonatomic, readonly) UInt8 batteryLevel;

- (void)disconnect;

- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID;
- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID;
- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID;

@end




@protocol SFBluetoothSmartDeviceDelegate
- (void)BTSmartDevice:(SFBluetoothSmartDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid;
@optional
- (BOOL)shouldContinueSearch;
- (void)noBluetooth;
- (void)fixedNoBluetooth;
@end