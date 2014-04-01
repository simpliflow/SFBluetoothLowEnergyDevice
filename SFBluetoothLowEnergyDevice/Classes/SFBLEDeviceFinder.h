//
//  SFBLEDeviceFinder.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <Foundation/Foundation.h>
#import "SFBLEDevice.h"

@protocol SFBLEDeviceFinderDelegate;




// Error codes for NSErrors, domain is "SFBluetoothSmartDevice"
typedef NS_ENUM(NSInteger, SFBluetoothSmartError) {
  SFBluetoothSmartErrorNoBluetooth = 1,
  SFBluetoothSmartErrorNoDeviceFound,
  SFBluetoothSmartErrorDeviceForIdentifierNotFound,
  SFBluetoothSmartErrorDeviceForNameNotFound,
  SFBluetoothSmartErrorProblemsInConnectionProcess,
  SFBluetoothSmartErrorProblemsInDiscoveryProcess,
  SFBluetoothSmartErrorConnectionClosedByDevice,
  SFBluetoothSmartErrorOtherCBError,
  SFBluetoothSmartErrorUnknown
};

extern NSString* const kSFBluetoothLowEnergyErrorDomain;





@interface SFBLEDeviceFinder : NSObject

+ (NSError*)error:(SFBluetoothSmartError)errorCode;

@property (nonatomic, assign) NSObject<SFBLEDeviceFinderDelegate>* delegate;

+ (instancetype)finderForDevicesWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)advertisedServices;

// All three of the following methods trigger either a finderFoundDevices:error: or a
// finderStoppedFindWithError: call.
// findDevices: is a convenience method to a nil identifier or name.
- (void)findDevices:(NSTimeInterval)timeout;
- (void)findDeviceWithIdentifier:(NSUUID*)identifier timeout:(NSTimeInterval)timeout;
- (void)findDeviceWithName:(NSString*)name timeout:(NSTimeInterval)timeout;

- (void)stopFind;

@end




@protocol SFBLEDeviceFinderDelegate

// Called at the end of the timeout, with all devices that have been found (may be an
// empty array) or an error.
- (void)finderFoundDevices:(NSArray*)bleDevices error:(NSError*)error;

// Called if no Bluetooth is available, if Bluetooth becomes unavailable during the scan
// this method will be called and bluetoothNotAvailable too.
- (void)finderStoppedFindWithError:(NSError*)error;

// Called every time the Bluetooth state goes from On to Off, Unavailable, etc.
- (void)bluetoothNotAvailable;
// Called every time the Bluetooth state goes from Off, Unavailable, Unsupported, etc to On. Will not
// be called at application start.
- (void)bluetoothAvailableAgain;

@end


/*
Things to test:
 * what happens to connecting/connected devices when Bluetooth is switched off? The Pod explicitly cancels the connections. Is this necessary (or would they not resume connection on Bluetooth-back-on anyway)? Do they get a response for the cancel call? (Remove the note in SFBLECentralManagerDelegate if this question has been answered)
*/