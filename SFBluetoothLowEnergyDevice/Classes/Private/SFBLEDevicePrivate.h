//
//  SFBLEDevicePrivate.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-03-05.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <Foundation/Foundation.h>
#import "SpacemanBlocks.h"
#import "SFBLECentralManagerDelegate.h"
#import "SFBLEPeripheralDelegate.h"


typedef NS_ENUM(NSInteger, SFBLEDeviceState) {
  SFBLEDeviceStateUnlinked = 0,
  SFBLEDeviceStateLinking,
  SFBLEDeviceStateLinked,
  SFBLEDeviceStateUnlinking
};


@interface SFBLEDevice () {
  __block SMDelayedBlockHandle _connectTimeoutBlock;
  __block SMDelayedBlockHandle _batteryReadBlock;
}


// Private Vars
@property (nonatomic, readonly) dispatch_queue_t bleQueue;

@property (nonatomic, assign) SFBLECentralManagerDelegate* centralDelegate;
@property (nonatomic) SFBLEPeripheralDelegate* peripheralDelegate;
@property (nonatomic) NSDictionary* servicesAndCharacteristics;

@property (atomic) BOOL shouldLink;
@property (atomic) SFBLEDeviceState state;

@property (atomic) BOOL automaticBatteryNotify;

// Public Vars
@property (readwrite) NSNumber* batteryLevel;




// Private Methods for Pod-Internal Use
// ====================================


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
