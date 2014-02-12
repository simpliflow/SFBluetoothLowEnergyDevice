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
  SFBluetoothSmartErrorNoBluetooth = 1,
  SFBluetoothSmartErrorUnableToDistinguishClosestDevice,
  SFBluetoothSmartErrorProblemsInConnectionProcess,
  SFBluetoothSmartErrorProblemsInDiscoveryProcess,
  SFBluetoothSmartErrorConnectionClosedByDevice,
  SFBluetoothSmartErrorOtherCBError,
  SFBluetoothSmartErrorUnknown
};




@protocol SFBluetoothSmartDeviceManagerDelegate;



// * no method of this class is supposed to be called on the main thread

// # Flow

// -- start scan (shouldScan == YES)

// possible breaks while scanning
//  * scan can be cancelled
//  * bluetooth can become unavailable
//  * two devices near to each other
//
//  implications
//  * stop scan
//  * invalidate scanForAlternativesTimer

// on success
//  * stop scan
//  * invalidate scanForAlternativesTimer
// -->

// -- connectToSuitablePeripheral (suitablePeripheral != nil)

// possible breaks while connecting
//  * scan can be cancelled
//  * Bluetooth can become unavailable
//  * error from device (centralManagerDidFailToConnect)
//
// implications
//  * invalidate connect timer
//  *
@interface SFBluetoothSmartDeviceManager : NSObject <CBCentralManagerDelegate>

@property (nonatomic, assign) NSObject<SFBluetoothSmartDeviceManagerDelegate>* delegate;
@property (nonatomic, readonly) dispatch_queue_t bleManagerQueue;

+ (NSError*)error:(SFBluetoothSmartError)errorCode;

+ (instancetype)deviceManager;

/// Starts the search cycle.
/// Does not start:
///  * when Bluetooth is not available
///
/// Ends when:
///  * cancelConnection is called
///  * Suitable device is found and connection successful
///  * Suitable device is found and connection fails
- (void)search:(NSUUID*)identifier advertising:(NSArray*)services;

/// Cancels the find cycle or disconnects from the peripheral
- (void)cancelConnection;
@end




@protocol SFBluetoothSmartDeviceManagerDelegate
- (void)managerConnectedToSuitablePeripheral:(CBPeripheral*)peripheral;
- (void)managerFailedToConnectToSuitablePeripheral:(CBPeripheral*)manager error:(NSError*)error;
- (void)managerDisconnectedFromPeripheral:(CBPeripheral*)peripheral error:(NSError*)error;
- (void)bluetoothNotAvailable;
- (void)bluetoothAvailableAgain;
@end
