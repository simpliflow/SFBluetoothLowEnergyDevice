//
//  SFBluetoothSmartDeviceManager.h
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 SimpliFlow. All rights reserved.




#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>


// Error codes for NSErrors, domain is "SFBluetoothSmartDevice"
typedef NS_ENUM(NSInteger, SFBluetoothSmartError) {
  SFBluetoothSmartErrorUnableToDistinguishClosestDevice = 0,
  SFBluetoothSmartErrorProblemsInConnectionProcess,
  SFBluetoothSmartErrorProblemsInDiscoveryProcess,
  SFBluetoothSmartErrorConnectionClosedByDevice,
  SFBluetoothSmartErrorUnknown
};






@protocol SFBluetoothSmartDeviceManagerDelegate;




@interface SFBluetoothSmartDeviceManager : NSObject <CBCentralManagerDelegate>

@property (nonatomic, assign) NSObject<SFBluetoothSmartDeviceManagerDelegate>* delegate;

+ (NSError*)error:(SFBluetoothSmartError)errorCode;

+ (instancetype)deviceManager;

/// Starts the find cycle that only ends if a device is successfully found or if it is cancelled
- (void)find:(NSUUID*)identifier advertising:(NSArray*)services;

/// Cancels the find cycle
- (void)cancelConnection;
@end




@protocol SFBluetoothSmartDeviceManagerDelegate
- (void)manager:(SFBluetoothSmartDeviceManager*)manager connectedToSuitablePeripheral:(CBPeripheral*)peripheral;
- (void)managerFailedToConnectToSuitablePeripheral:(SFBluetoothSmartDeviceManager*)manager error:(NSError*)error;
- (void)manager:(SFBluetoothSmartDeviceManager*)manager disconnectedFromPeripheral:(CBPeripheral*)peripheral;
- (void)bluetoothNotAvailable;
- (void)bluetoothAvailableAgain;
@end
