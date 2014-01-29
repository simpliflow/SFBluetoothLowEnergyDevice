//
//  SFBLEDevice.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


@protocol SFBLEDeviceDelegate;
@class SFBLEDeviceManager, SFBLECentralManagerDelegate;




@interface SFBLEDevice : NSObject

@property (nonatomic, assign) NSObject<SFBLEDeviceDelegate>* delegate;

// do not forget to set the delegate before calling
- (void)link;
- (void)unlink;

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) NSUUID* identifier;
/// Battery level of device in percent (100 is fully charged, 0 is fully discharged)
@property (nonatomic, readonly) NSNumber* batteryLevel;

- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID;
- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID;
- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID;


// # Private
// SFBLEDeviceManager
+ (instancetype)deviceWithPeripheral:(CBPeripheral*)peripheral centralDelegate:(SFBLECentralManagerDelegate*)centralDelegate servicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics;

// SFBLECentralManagerDelegate
@property (nonatomic) CBPeripheral* peripheral;
- (void)didConnectPeripheral:(CBPeripheral*)peripheral;
- (void)didFailToConnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error;
- (void)didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error;
- (void)bluetoothNotAvailable;

// SFBLEPeripheralDelegate
- (void)completedDiscovery;
- (void)discoveryTimedOut;
- (void)didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error;

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
