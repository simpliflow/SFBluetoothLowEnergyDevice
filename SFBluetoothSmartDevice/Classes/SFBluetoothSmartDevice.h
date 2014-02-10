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





// Will try to connect until device is found, disconnect is called or it is deallocated (Note: do not rely on deallocation).


@interface SFBluetoothSmartDevice : NSObject <CBPeripheralDelegate, SFBluetoothSmartDeviceManagerDelegate>

+ (instancetype)BTSmartDeviceWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services;

@property (nonatomic, assign) NSObject<SFBluetoothSmartDeviceDelegate>* delegate;


/// # Connection management
/// (the connection process to a BLE device is more involved, therefore
/// it is named "link")
- (void)linkWithIdentifier:(NSUUID*)identifier;
- (void)unlink;
/// This is a hacky fix to the problem that the cancelling of the scan takes some time to reach
/// the ble-queue.
// Inside note: Within this time it could happen that "linkWithIdentifier:" has already been called
// again while a scan is still running or a connection is still up (from the link before). So the
// ble-device or the manager may think that the state should be kept unchanged.
// at this time the best idea for a fix is to use a queue for link and unlink commands, and have
// them be acknowledged, before executing the next.
- (void)unlinkWithBlock:(void (^) ())block;


@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSUUID* identifier;
/// Battery level of device in percent (100 is fully charged, 0 is fully discharged)
@property (nonatomic, readonly) UInt8 batteryLevel;

- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID;
- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID;
- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID;

@end




@protocol SFBluetoothSmartDeviceDelegate
- (void)BTSmartDeviceConnectedSuccessfully:(SFBluetoothSmartDevice*)device;
/// Although the error is encountered, search for the device does not stop. If the connection
/// has been lost it is tried to reconnect (again: either to the device with the specified identifier or the nearest one).
- (void)BTSmartDeviceEncounteredError:(NSError*)error;
- (void)BTSmartDevice:(SFBluetoothSmartDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid;
@optional
- (void)noBluetooth;
- (void)fixedNoBluetooth;
@end