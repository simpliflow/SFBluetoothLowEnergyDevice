//
//  SFBLEPeripheralDelegate.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class SFBLEDeviceFinder, SFBLEDevice;




@interface SFBLEPeripheralDelegate : NSObject <CBPeripheralDelegate>

+ (instancetype)peripheralDelegateWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics forDevice:(SFBLEDevice*)device;

- (void)startDiscovering;
- (void)invalidateDiscoveryTimer;

- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID;
- (void)writeValue:(NSData*)value forCharacteristic:(CBUUID*)characteristicUUID;
- (void)writeValueWithoutResponse:(NSData*)value forCharacteristic:(CBUUID*)characteristicUUID;
- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID;
- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID;

- (CBCharacteristic*)characteristic:(CBUUID*)characteristicUUID;
- (CBService*)service:(CBUUID*)serviceUUID;
- (NSMutableDictionary*) incomingServiceByUUID;

@end
