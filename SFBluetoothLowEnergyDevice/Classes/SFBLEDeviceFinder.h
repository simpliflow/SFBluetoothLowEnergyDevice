//
//  SFBLEDeviceFinder.h
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import <Foundation/Foundation.h>
#import "SFBLEDevice.h"

@protocol SFBLEDeviceFinderDelegate;




// Error codes for NSErrors, domain is kSFBluetoothLowEnergyErrorDomain
typedef NS_ENUM(NSInteger, SFBluetoothLowEnergyError) {
  SFBluetoothLowEnergyErrorNoBluetooth = 1,
  SFBluetoothLowEnergyErrorNoDeviceFound,
  SFBluetoothLowEnergyErrorDeviceForIdentifierNotFound,
  SFBluetoothLowEnergyErrorDeviceForNameNotFound,
  SFBluetoothLowEnergyErrorLinkingCancelled,
  SFBluetoothLowEnergyErrorProblemsInConnectionProcess,
  SFBluetoothLowEnergyErrorProblemsInDiscoveryProcess,
  SFBluetoothLowEnergyErrorConnectionClosedByDevice,
  SFBluetoothLowEnergyErrorOtherCBError,
  SFBluetoothLowEnergyErrorUnknown
};

extern NSString* const kSFBluetoothLowEnergyErrorDomain;





@interface SFBLEDeviceFinder : NSObject

+ (NSError*)error:(SFBluetoothLowEnergyError)errorCode;

@property (nonatomic, assign) NSObject<SFBLEDeviceFinderDelegate>* delegate;

+ (instancetype)finderForDevicesWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)advertisedServices;

// All three of the following methods trigger either a finderFoundDevices:error: or a
// finderStoppedFindWithError: call.
// findDevices: is a convenience method to a nil identifier or name.
- (void)findDevices:(NSTimeInterval)timeout;
// These two search for a specific device
// * if the device is found within the timeout, bleDevices of finderFoundDevices:error:
//    contains only the specific device and no error
// * if the device is not found within the timeout, bleDevices of finderFoundDevices:error:
//    contains all devices that have been found (advertising the services as defined
//    by the init method of this class of course), and an error (code is either
//    SFBluetoothLowEnergyErrorDeviceForIdentifierNotFound or SFBluetoothLowEnergyErrorDeviceForNameNotFound).
// * if nil has been provided for name or identifier and if one or more devices have
//    been found they are contained in bleDevices of finderFoundDevices:error: and the
//    error is nil
// * if nil has been provided for name or identifier and no devices have been found
//    bleDevices of finderFoundDevices:error: is an empty array and the error's code
//    is SFBluetoothLowEnergyErrorNoDeviceFound.
- (void)findDeviceWithIdentifier:(NSUUID*)identifier timeout:(NSTimeInterval)timeout;
- (void)findDeviceWithName:(NSString*)name timeout:(NSTimeInterval)timeout;

// Stops a find, does nothing if no find is in progress.
- (void)stopFind;

@end




@protocol SFBLEDeviceFinderDelegate

// Called at the end of the timeout or if the specific device has been found. See
// above for details.
- (void)finderFoundDevices:(NSArray*)bleDevices error:(NSError*)error;

// Called if Bluetooth is or becomes unavailable. If Bluetooth becomes unavailable
// during the scan this method will be called and bluetoothNotAvailable too.
- (void)finderStoppedFindWithError:(NSError*)error;

// Called every time the Bluetooth state goes from On to Off, Unavailable, etc.
- (void)bluetoothNotAvailable;

// Called every time the Bluetooth state goes from Off, Unavailable, Unsupported,
// etc to On. Will not be called at application start.
- (void)bluetoothAvailableAgain;

@end


/*
Things to test:
 * what happens to connecting/connected devices when Bluetooth is switched off? The Pod explicitly cancels the connections. Is this necessary (or would they not resume connection on Bluetooth-back-on anyway)? Do they get a response for the cancel call? (Remove the note in SFBLECentralManagerDelegate if this question has been answered)
*/