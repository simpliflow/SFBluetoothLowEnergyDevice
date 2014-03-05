//
//  SFBLEDeviceManager.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <Foundation/Foundation.h>
#import "SFBLEDevice.h"


// Error codes for NSErrors, domain is "SFBluetoothSmartDevice"
typedef NS_ENUM(NSInteger, SFBluetoothSmartError) {
  SFBluetoothSmartErrorNoBluetooth = 1,
  SFBluetoothSmartErrorNoDeviceFound,
  SFBluetoothSmartErrorSpecificDeviceNotFound,
  SFBluetoothSmartErrorProblemsInConnectionProcess,
  SFBluetoothSmartErrorProblemsInDiscoveryProcess,
  SFBluetoothSmartErrorConnectionClosedByDevice,
  SFBluetoothSmartErrorOtherCBError,
  SFBluetoothSmartErrorUnknown
};

@protocol SFBLEDeviceManagerDelegate;




@interface SFBLEDeviceManager : NSObject

+ (NSError*)error:(SFBluetoothSmartError)errorCode;

@property (nonatomic, assign) NSObject<SFBLEDeviceManagerDelegate>* delegate;

+ (instancetype)managerForDevicesWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)advertisedServices;

/// Followed by managerFoundDevices: or managerAbortedScanWithError
- (void)scanFor:(NSUUID*)identifier timeout:(NSTimeInterval)timeout;
- (void)stopScan;


@end




@protocol SFBLEDeviceManagerDelegate

// called at the end of the timeout, with all devices that have been found (may be an
// empty array)
- (void)managerFoundDevices:(NSArray*)bleDevices;
// called at the end of the timeout if the specific
// device has not been found or in between if an error surfaced.
// If Bluetooth goes to off while scanning, you will get managerStoppedScanWithError: with
// a no bluetooth error and bluetoothNotAvailable will also be called.
- (void)managerStoppedScanWithError:(NSError*)error;

// Called every time the Bluetooth state goes from On to Off, Unavailable, etc.
- (void)bluetoothNotAvailable;
// Called every time the Bluetooth state goes from Off, Unavailable, Unsupported, etc to On. Will not
// be called at application start.
- (void)bluetoothAvailableAgain;

@end


/*
Things to test:
 * what happens to connecting/connected devices when Bluetooth is switched off? The Pod explicitly cancels the connections. Is this necessary (or would they not resume connection on Bluetooth-back-on anyway)? Do they get a response for the cancel call? (Remove the note in SFBLECentralManagerDelegate if this question has been answered)
 * check
*/