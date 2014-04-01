//
//  SFBLECentralManagerDelegate.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


@class SFBLEDeviceFinder, SFBLEDevice;




@interface SFBLECentralManagerDelegate : NSObject <CBCentralManagerDelegate>

// SFBLEDeviceFinder
+ (instancetype)centralDelegateForDeviceManager:(SFBLEDeviceFinder*)deviceManager withBLEQueue:(dispatch_queue_t)bleQueue;

- (void)scanForPeripheralsAdvertising:(NSArray*)advertisedServices;
- (void)stopScan;


// SFBLEDevice
- (void)connectToDevice:(SFBLEDevice*)device;
- (void)cancelConnectionToDevice:(SFBLEDevice*)device;

@end
