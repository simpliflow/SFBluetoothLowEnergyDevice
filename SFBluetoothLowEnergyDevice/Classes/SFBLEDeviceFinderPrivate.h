//
//  SFBLEDeviceFinderPrivate.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-03-05.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <Foundation/Foundation.h>
#import "SpacemanBlocks.h"
#import "SFBLECentralManagerDelegate.h"




@interface SFBLEDeviceFinder () {
  __block SMDelayedBlockHandle _scanTimeoutBlock;
}

@property (nonatomic) NSMutableDictionary* discoveredDevices;
@property (nonatomic, copy) NSUUID* identifierToScanFor;
@property (nonatomic, copy) NSString* nameToScanFor;
@property (nonatomic) BOOL stopAfterFirstDevice;
@property (atomic) BOOL shouldScan;
@property (nonatomic) NSTimeInterval scanTimeout;

@property (nonatomic) NSDictionary* servicesAndCharacteristics;
@property (nonatomic, copy) NSArray* advertisedServices;
@property (nonatomic) SFBLECentralManagerDelegate* centralDelegate;

@property (atomic) BOOL bluetoothIsNotAvailable;




// Private Methods for Pod-Internal Use
// ====================================


+ (dispatch_queue_t)bleQueue;
// SFBLECentralManagerDelegate
- (void)didDiscoverPeripheral:(CBPeripheral*)peripheral RSSI:(NSNumber*)RSSI;
- (void)bluetoothNotAvailable;
- (void)bluetoothAvailableAgain;


@end
