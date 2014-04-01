//
//  SFBLECentralManagerDelegate.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import "SFBLECentralManagerDelegate.h"

#import "DDLog.h"
static const int ddLogLevel = LOG_LEVEL_DEBUG;

#import "SFBLEDeviceFinder.h"
#import "SFBLEDeviceManagerPrivate.h"
#import "SFBLEDevice.h"
#import "SFBLEDevicePrivate.h"




@interface SFBLECentralManagerDelegate ()

@property (nonatomic, assign) SFBLEDeviceFinder* deviceManager;

@property (nonatomic) CBCentralManager* bleCentral;

@property (nonatomic) NSMutableDictionary* devicesByPeripheral;

// Indicates if the central manager should scan
// Necessary because at the time the scanning should be started
// the central may not yet be ready
// Altered internally depending on if a device should be found and
// has been found
@property (atomic) BOOL shouldScan;
@property (nonatomic) NSArray* servicesToScanFor;


// State of Bluetooth
@property (nonatomic) BOOL bluetoothWasUnavailable;

@end







@implementation SFBLECentralManagerDelegate


static NSArray* __managerStateStrings;
+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    if (self == [SFBLECentralManagerDelegate class]) {
      __managerStateStrings = @[
                                @"Unknown",
                                @"Resetting",
                                @"Unsupported",
                                @"Unauthorized",
                                @"PoweredOff",
                                @"PoweredOn"
                                ];
    }
  });
}


+ (instancetype)centralDelegateForDeviceManager:(SFBLEDeviceFinder*)deviceManager withBLEQueue:(dispatch_queue_t)bleQueue
{
  return [[SFBLECentralManagerDelegate alloc] initForDeviceManager:(SFBLEDeviceFinder*)deviceManager withBLEQueue:(dispatch_queue_t)bleQueue];
}
- (id)initForDeviceManager:(SFBLEDeviceFinder*)deviceManager withBLEQueue:(dispatch_queue_t)bleQueue
{
  if (self = [super init]) {
    _deviceManager = deviceManager;
    _bleCentral = [[CBCentralManager alloc] initWithDelegate:self queue:bleQueue];
    _devicesByPeripheral = [@{} mutableCopy];
  }
  return self;
}




#pragma mark -
#pragma mark SFBLEDeviceManager


- (void)scanForPeripheralsAdvertising:(NSArray*)advertisedServices
{
  NSAssert(self.bleCentral.state != CBCentralManagerStatePoweredOff, @"Call should not come through in this state");
  NSAssert(self.bleCentral.state != CBCentralManagerStateUnsupported, @"Call should not come through in this state");
  NSAssert(self.bleCentral.state != CBCentralManagerStateUnauthorized, @"Call should not come through in this state");

  NSString* servicesString = [[advertisedServices valueForKeyPath:@"@unionOfObjects.description"] componentsJoinedByString:@", "];
  DDLogDebug(@"BLE-CentralDelegate: will start scanning for devs advertising: %@", servicesString);

  self.servicesToScanFor = advertisedServices;

  self.shouldScan = YES;
  [self startScan];
}


- (void)startScan
{
  if (self.shouldScan && self.bleCentral.state == CBCentralManagerStatePoweredOn) {
    DDLogDebug(@"BLE-CentralDelegate: starting scan");
    [self.bleCentral scanForPeripheralsWithServices:self.servicesToScanFor options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
  }
}


- (void)stopScan
{
  if (self.shouldScan) {
    self.shouldScan = NO;
    if (self.bleCentral.state == CBCentralManagerStatePoweredOn)
      [self.bleCentral stopScan];
  }
}




#pragma mark -
#pragma mark SFBLEDevice


// the central delegate keeps a reference to the BLEDevice in devicesByPeripheral starting from
// the call to connectToDevice: as long as it is in the connection process or connected
- (void)connectToDevice:(SFBLEDevice*)device
{
  NSAssert(!self.devicesByPeripheral[device.peripheral], @"Connect call although is already connected or connecting");

  self.devicesByPeripheral[device.peripheral] = device;
  [self.bleCentral connectPeripheral:device.peripheral options:nil];
}


- (void)cancelConnectionToDevice:(SFBLEDevice*)device
{
  NSAssert(self.devicesByPeripheral[device.peripheral], @"Cancel connection call although is not connected or connecting");
  
  [self.bleCentral cancelPeripheralConnection:device.peripheral];
}




#pragma mark -
#pragma mark CBCentralManagerDelegate


- (void)centralManagerDidUpdateState:(CBCentralManager*)central
{
  DDLogDebug(@"BLE-CentralDelegate: central updated state to %@", __managerStateStrings[central.state]);
  
  if (central.state == CBCentralManagerStatePoweredOn)
  {
    [self startScan];
    
    if (self.bluetoothWasUnavailable)
      [self.deviceManager bluetoothAvailableAgain];
  }
  
  else if (central.state == CBCentralManagerStatePoweredOff ||
           central.state == CBCentralManagerStateUnsupported ||
           central.state == CBCentralManagerStateUnauthorized)
  {
    for (SFBLEDevice* device in self.devicesByPeripheral.allValues) {
      [device bluetoothNotAvailable];
    }
    [self.devicesByPeripheral removeAllObjects];
    
    [self.deviceManager bluetoothNotAvailable];
    self.bluetoothWasUnavailable = YES;
  }
}




#pragma mark For SFBLEDeviceManager


- (void)centralManager:(CBCentralManager*)central didDiscoverPeripheral:(CBPeripheral*)peripheral advertisementData:(NSDictionary*)advertisementData RSSI:(NSNumber*)RSSI
{
  if (!self.shouldScan)
    return;
  
  [self.deviceManager didDiscoverPeripheral:peripheral RSSI:RSSI];
}




#pragma mark For SFBLEDevice


- (void)centralManager:(CBCentralManager*)central didConnectPeripheral:(CBPeripheral*)peripheral
{
  DDLogDebug(@"BLE-CentralDelegate: connected peripheral %@", peripheral.name);
  SFBLEDevice* device = self.devicesByPeripheral[peripheral];
  NSAssert(device, @"No device found although there should be one");
  [device didConnectPeripheral:peripheral];
}


- (void)centralManager:(CBCentralManager*)central didFailToConnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  DDLogDebug(@"BLE-CentralDelegate: failed to connect peripheral %@", peripheral.name);
  SFBLEDevice* device = self.devicesByPeripheral[peripheral];
  // Note: In case of Bluetooth going to off every peripheral is sent a cancel call. If the
  //    central answers this with a disconnect call it is to be expected that the device
  //    is no longer in the list and the assert will be triggered. If this is so, find a solution.
  NSAssert(device, @"No device found although there should be one");
  [device didFailToConnectPeripheral:peripheral error:error];
  [self.devicesByPeripheral removeObjectForKey:peripheral];
}


- (void)centralManager:(CBCentralManager*)central didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  SFBLEDevice* device = self.devicesByPeripheral[peripheral];
  // Note: In case of Bluetooth going to off every peripheral is sent a cancel call. If the
  //    central answers this with a disconnect call it is to be expected that the device
  //    is no longer in the list and the assert will be triggered. If this is so, find a solution.
  NSAssert(device, @"No device found although there should be one");
  [device didDisconnectPeripheral:peripheral error:error];
  [self.devicesByPeripheral removeObjectForKey:peripheral];
}


@end
