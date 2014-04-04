//
//  SFBLEDeviceFinder.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.

#import "SFBLEDeviceFinder.h"
#import "SFBLEDeviceFinderPrivate.h"

#import "SFBLELogging.h"
#import "DDTTYLogger.h"
#import "SFConsoleLogFormat.h"

#import "SFBLEDevice.h"
#import "SFBLEDevicePrivate.h"
#import "SFBLECentralManagerDelegate.h"




#define DISPATCH_ON_MAIN_QUEUE(statement) do { \
dispatch_async(dispatch_get_main_queue(), ^{ \
statement; \
}); } while(0)
#define DISPATCH_ON_BLE_QUEUE(statement) do { \
dispatch_async(SFBLEDeviceFinder.bleQueue, ^{ \
statement; \
}); } while(0)

NSString* const kSFBluetoothLowEnergyErrorDomain = @"SFBluetoothLowEnergyError";




@implementation SFBLEDeviceFinder

static dispatch_queue_t __bleQueue;
+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    __bleQueue = dispatch_queue_create("com.simpliflow_ble.queue", DISPATCH_QUEUE_SERIAL);
    [[DDTTYLogger sharedInstance] setLogFormatter:[[SFConsoleLogFormat alloc] init]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
  });
}


+ (dispatch_queue_t)bleQueue
{
  return __bleQueue;
}


+ (NSError*)error:(SFBluetoothSmartError)errorCode
{
  NSString* description = nil;
  switch (errorCode) {
    case SFBluetoothSmartErrorNoBluetooth:
      description = @"Bluetooth not available";
      break;
    case SFBluetoothSmartErrorNoDeviceFound:
      description = @"No device found";
      break;
    case SFBluetoothSmartErrorDeviceForIdentifierNotFound:
    case SFBluetoothSmartErrorDeviceForNameNotFound:
      description = @"Specific device not found";
      break;
    case SFBluetoothSmartErrorProblemsInConnectionProcess:
      description = @"Problems in connection process";
      break;
    case SFBluetoothSmartErrorProblemsInDiscoveryProcess:
      description = @"Problems in discovery process";
      break;
    case SFBluetoothSmartErrorConnectionClosedByDevice:
      description = @"Connection closed by device";
      break;
    case SFBluetoothSmartErrorOtherCBError:
      description = @"Other CoreBluetooth error";
      break;
    case SFBluetoothSmartErrorUnknown:
      description = @"Unknown error";
      break;
  }
  
  return [NSError errorWithDomain:kSFBluetoothLowEnergyErrorDomain
                             code:errorCode
                         userInfo:@{
                                    NSLocalizedDescriptionKey:description
                                    }];
}


+ (instancetype)finderForDevicesWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)advertisedServices
{
  return [[SFBLEDeviceFinder alloc] initWithServicesAndCharacteristics:servicesAndCharacteristics advertising:advertisedServices];
}
- (id)initWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)advertisedServices
{
  if (self = [super init]) {
    // Check
    //   * the keys of servicesAndCharacteristics
    //   * the elements within the arrays that are the values of servicesAndCharacteristics
    //   * the services that are expected to be advertised
    //  to be of the class CBUUID.
    NSArray* characteristics = [servicesAndCharacteristics.allValues valueForKeyPath:@"@unionOfArrays.self"];
    
    // advertisedServices may be nil
    NSArray* toBeTested;
    if (advertisedServices)
      toBeTested = @[servicesAndCharacteristics.allKeys, characteristics, advertisedServices];
    else
      toBeTested = @[servicesAndCharacteristics.allKeys, characteristics];
    
    for (NSArray* shouldBeUUIDs in toBeTested) {
      for (id shouldBeUUID in shouldBeUUIDs) {
        if (![shouldBeUUID isKindOfClass:[CBUUID class]])
          return nil;
      }
    }
    // Check
    //   * if the characteristics are unique
    NSMutableArray* characteristicsCheck = [@[] mutableCopy];
    for (CBUUID* maybeUniqueUUID in characteristics) {
      if ([characteristicsCheck indexOfObject:maybeUniqueUUID] != NSNotFound) {
        return nil;
      }
      [characteristicsCheck addObject:maybeUniqueUUID];
    }
    
    self.advertisedServices = advertisedServices;
    self.servicesAndCharacteristics = servicesAndCharacteristics;
    
    _centralDelegate = [SFBLECentralManagerDelegate centralDelegateForDeviceManager:self withBLEQueue:SFBLEDeviceFinder.bleQueue];
  }
  return self;
}




#pragma mark -
#pragma mark Scanning


- (void)findDevices:(NSTimeInterval)timeout
{
  [self findDeviceWithIdentifier:nil timeout:timeout];
}


- (void)findDeviceWithIdentifier:(NSUUID*)identifier timeout:(NSTimeInterval)timeout
{
  if (self.shouldScan)
    return;
  
  if (self.bluetoothIsNotAvailable) {
    DISPATCH_ON_MAIN_QUEUE([self.delegate finderStoppedFindWithError:[SFBLEDeviceFinder error:SFBluetoothSmartErrorNoBluetooth]]);
    return;
  }
  
  self.shouldScan = YES;
  DISPATCH_ON_BLE_QUEUE(
                        if (timeout > 0) {
                          self.scanTimeout = timeout;
                          [self startScanTimer];
                        }
                        self.identifierToScanFor = identifier;
                        self.nameToScanFor = nil;
                        self.discoveredDevices = [@{} mutableCopy];
                        [self logScanStart];
                        [self.centralDelegate scanForPeripheralsAdvertising:self.advertisedServices];
  );
}


- (void)findDeviceWithName:(NSString*)name timeout:(NSTimeInterval)timeout
{
  if (self.shouldScan)
    return;
  
  if (self.bluetoothIsNotAvailable) {
    DISPATCH_ON_MAIN_QUEUE([self.delegate finderStoppedFindWithError:[SFBLEDeviceFinder error:SFBluetoothSmartErrorNoBluetooth]]);
    return;
  }
  
  self.shouldScan = YES;
  DISPATCH_ON_BLE_QUEUE(
                        if (timeout > 0) {
                          self.scanTimeout = timeout;
                          [self startScanTimer];
                        }
                        self.nameToScanFor = name;
                        self.identifierToScanFor = nil;
                        self.discoveredDevices = [@{} mutableCopy];
                        [self logScanStart];
                        [self.centralDelegate scanForPeripheralsAdvertising:self.advertisedServices];
                        );
}



- (void)startScanTimer
{
  _scanTimeoutBlock = perform_block_after_delay(self.scanTimeout, SFBLEDeviceFinder.bleQueue, ^{
    [self scanTimedOut];
  });
}


- (void)invalidateScanTimer
{
  if (_scanTimeoutBlock) {
    cancel_delayed_block(_scanTimeoutBlock);
    _scanTimeoutBlock = nil;
  }
}


- (void)scanTimedOut
{
  NSAssert(self.shouldScan, @"Raise condition");

  [self executeStoppingScanDuties];
  
  if (self.identifierToScanFor || self.nameToScanFor)
  {
    DDLogInfo(@"BLE-Finder: scan timed out. Specific device not found");
    
    NSError* SFBLEError;
    SFBluetoothSmartError errorCode = self.identifierToScanFor ? SFBluetoothSmartErrorDeviceForIdentifierNotFound : SFBluetoothSmartErrorDeviceForNameNotFound;
    SFBLEError = [SFBLEDeviceFinder error:errorCode];
    
    DISPATCH_ON_MAIN_QUEUE(self.shouldScan = NO; [self.delegate finderFoundDevices:self.discoveredDevices.allValues error:SFBLEError]);
  }
  else
  {
    DDLogInfo(@"BLE-Finder: scan timed out. Found %d device(s).", self.discoveredDevices.count);
    
    NSError* SFBLEError;
    if (!self.discoveredDevices.count)
      SFBLEError = [SFBLEDeviceFinder error:SFBluetoothSmartErrorNoDeviceFound];
    
    DISPATCH_ON_MAIN_QUEUE(self.shouldScan = NO; [self.delegate finderFoundDevices:self.discoveredDevices.allValues error:SFBLEError]);
  }
}


- (void)didDiscoverPeripheral:(CBPeripheral*)peripheral RSSI:(NSNumber*)RSSI;
{
  NSAssert(self.shouldScan, @"Peripheral discovered altough should not scan");
  if (!self.shouldScan)
    return;
  
  // An RSSI value of 127 is not valid, but it has been encountered regularly
  if (RSSI.integerValue == 127)
    return;
  
  if (![self.discoveredDevices.allKeys containsObject:peripheral.identifier]) {
    DDLogInfo(@"BLE-Finder: new suitable peripheral %p (%@, %@). RSSI: %@", peripheral, peripheral.identifier, peripheral.name, RSSI);
    self.discoveredDevices[peripheral.identifier] = [SFBLEDevice deviceWithPeripheral:peripheral centralDelegate:self.centralDelegate servicesAndCharacteristics:self.servicesAndCharacteristics];
  }

  if ( (self.identifierToScanFor && [self.identifierToScanFor isEqual:peripheral.identifier]) ||
      (self.nameToScanFor && [self.nameToScanFor isEqualToString:peripheral.name]) )
  {
    DDLogDebug(@"BLE-Finder: did discover specific peripheral: %@", peripheral);
    [self executeStoppingScanDuties];
    
    SFBLEDevice* suitableDevice = [SFBLEDevice deviceWithPeripheral:peripheral centralDelegate:self.centralDelegate servicesAndCharacteristics:self.servicesAndCharacteristics];
    DISPATCH_ON_MAIN_QUEUE(self.shouldScan = NO; [self.delegate finderFoundDevices:@[suitableDevice] error:nil]);
  }
}


- (void)stopFind
{
  self.shouldScan = NO;
  DISPATCH_ON_BLE_QUEUE([self executeStoppingScanDuties]);
}
- (void)executeStoppingScanDuties
{
  [self.centralDelegate stopScan];
  [self invalidateScanTimer];
}




#pragma mark -
#pragma mark Bluetooth State


- (void)bluetoothNotAvailable
{
  self.bluetoothIsNotAvailable = YES;
  if (self.shouldScan) {
    [self executeStoppingScanDuties];
    DISPATCH_ON_MAIN_QUEUE(
                           self.shouldScan = NO;
                           [self.delegate finderStoppedFindWithError:[SFBLEDeviceFinder error:SFBluetoothSmartErrorNoBluetooth]];
    );
  }
  
  if ([self.delegate respondsToSelector:@selector(bluetoothNotAvailable)]) {
    [self.delegate bluetoothNotAvailable];
  }
}


- (void)bluetoothAvailableAgain
{
  self.bluetoothIsNotAvailable = NO;
  if ([self.delegate respondsToSelector:@selector(bluetoothAvailableAgain)]) {
    [self.delegate bluetoothAvailableAgain];
  }
}




#pragma mark -
#pragma mark Helper Methods


- (void)logScanStart
{
  NSString* servicesString = [[self.advertisedServices valueForKeyPath:@"@unionOfObjects.description"] componentsJoinedByString:@", "];
  
  if (self.identifierToScanFor)
    DDLogDebug(@"BLE-Finder: will scan for dvc with name \"%@\" advertising: %@", self.identifierToScanFor, servicesString);
  else if (self.nameToScanFor)
    DDLogDebug(@"BLE-Finder: will scan for dvc with id \"%@\" advertising: %@", self.nameToScanFor, servicesString);
  else
    DDLogDebug(@"BLE-Finder: will scan for all dvcs advertising: %@", servicesString);
}


@end


#undef DISPATCH_ON_MAIN_QUEUE
#undef DISPATCH_ON_BLE_QUEUE
