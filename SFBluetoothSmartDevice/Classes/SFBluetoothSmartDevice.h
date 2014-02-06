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



// Error codes for NSErrors, domain is "SFBluetoothSmartDevice"
typedef NS_ENUM(NSInteger, SFBluetoothSmartError) {
  SFBluetoothSmartErrorUnableToDistinguishClosestDevice = 0,
  // TODO: should only be sent when searching for specific device
  SFBluetoothSmartErrorProblemsInConnectionProcess,
  // TODO: should only be sent when searching for specific device
  SFBluetoothSmartErrorProblemsInDiscoveryProcess,
  SFBluetoothSmartErrorConnectionClosedByDevice,
  SFBluetoothSmartErrorUnknown
};






// Will try to connect until device is found, disconnect is called or it is deallocated (Note: do not rely on deallocation).


@interface SFBluetoothSmartDevice : NSObject <CBPeripheralDelegate, SFBluetoothSmartDeviceManagerDelegate>

+ (instancetype)withTheseServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services andIdentifyingItselfWith:(NSUUID*)identifier;

@property (nonatomic, assign) NSObject<SFBluetoothSmartDeviceDelegate>* delegate;


@property (nonatomic, readonly) BOOL connected;

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
- (void)BTSmartDeviceConnectedSuccessfully:(SFBluetoothSmartDevice*)device;
/// Although the error is encountered, search for the device does not stop. If the connection
/// has been lost it is tried to reconnect (again: either to the device with the specified identifier or the nearest one).
- (void)BTSmartDeviceEncounteredError:(NSError*)error;
- (void)BTSmartDevice:(SFBluetoothSmartDevice*)device receivedData:(NSData*)data fromCharacteristic:(CBUUID*)uuid;
@optional
- (void)noBluetooth;
- (void)fixedNoBluetooth;
@end