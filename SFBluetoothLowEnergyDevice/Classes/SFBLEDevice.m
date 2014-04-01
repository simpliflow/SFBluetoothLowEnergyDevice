//
//  SFBLEDevice.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import "SFBLEDevice.h"
#import "SFBLEDevicePrivate.h"

#import "DDLog.h"
static const int ddLogLevel = LOG_LEVEL_DEBUG;

#import "SFBLEDeviceFinder.h"
#import "SFBLEDeviceFinderPrivate.h"
#import "SFBLECentralManagerDelegate.h"
#import "SFBLEPeripheralDelegate.h"


#define CONNECT_TIMEOUT 1.5
#define BATTERY_READ_INTERVAL 30

#define DISPATCH_ON_MAIN_QUEUE(statement) do { \
dispatch_async(dispatch_get_main_queue(), ^{ \
statement; \
}); } while(0)
#define DISPATCH_ON_BLE_QUEUE(statement) do { \
dispatch_async(SFBLEDeviceFinder.bleQueue, ^{ \
statement; \
}); } while(0)

// Constants for automatic battery state retrieval
#define kBLEServiceBattery @"180F"
#define kBLECharBatteryLevel @"2A19"




@implementation SFBLEDevice


// Keeps all devices accessable by their peripheral so that when a peripheral
// is discovered in a subsequent find call, the same device is used and not
// a new one is created. Having two devices connected to the same peripheral
// has unknown repercussion.
static NSMutableDictionary* __allDiscoveredDevicesSinceAppStart;
+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    __allDiscoveredDevicesSinceAppStart = [@{} mutableCopy];
  });
}


+ (instancetype)deviceWithPeripheral:(CBPeripheral*)peripheral centralDelegate:(SFBLECentralManagerDelegate*)centralDelegate servicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics
{
  SFBLEDevice* deviceToReturn = __allDiscoveredDevicesSinceAppStart[peripheral];
  
  if (deviceToReturn)
    return deviceToReturn;
  
  deviceToReturn = [[SFBLEDevice alloc] initWithPeripheral:peripheral centralDelegate:centralDelegate servicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics];
  __allDiscoveredDevicesSinceAppStart[peripheral] = deviceToReturn;
  
  return deviceToReturn;
}
- (id)initWithPeripheral:(CBPeripheral*)peripheral centralDelegate:(SFBLECentralManagerDelegate*)centralDelegate servicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics
{
  if (self = [super init]) {
    _peripheral = peripheral;
    _identifier = peripheral.identifier;
    _centralDelegate = centralDelegate;
    _servicesAndCharacteristics = servicesAndCharacteristics;
    _state = SFBLEDeviceStateUnlinked;
  }
  return self;
}


- (dispatch_queue_t)bleQueue
{
  return [SFBLEDeviceFinder bleQueue];
}




#pragma mark -
#pragma mark Linking Control
// These are the methods where the main and BLE thread meet each other
// the three variables shouldLink, linking and linked are used to
// decide what to do.

- (void)link
{
  DDLogDebug(@"BLE-Device: starting link");

  if (self.shouldLink)
    return;
  
  self.shouldLink = YES;
  DISPATCH_ON_BLE_QUEUE(
                        switch (self.state)
                        {
                          case SFBLEDeviceStateUnlinked:
                            self.state = SFBLEDeviceStateLinking;
                            [self connect];
                            break;
                            
                          case SFBLEDeviceStateUnlinking:
                          case SFBLEDeviceStateLinked:
                          case SFBLEDeviceStateLinking:
                            DDLogDebug(@"BLE-Device: state on \"linking\" is %d", self.state);
                            break;
                        }
                        );
}


// Unlinking does not report a successful disconnection to the outside,
// nonetheless it has to keep track of the current state of the link.
- (void)unlink
{
  DDLogDebug(@"BLE-Device: starting unlink");
  
  if (!self.shouldLink)
    return;
  
  self.shouldLink = NO;
  DISPATCH_ON_BLE_QUEUE(
                        switch (self.state)
                        {
                          case SFBLEDeviceStateLinking:
                            [self invalidateConnectTimer];
                            [self.peripheralDelegate invalidateDiscoveryTimer];
                            // break is left out on purpose
                          case SFBLEDeviceStateLinked:
                            self.state = SFBLEDeviceStateUnlinking;
                            [self.centralDelegate cancelConnectionToDevice:self];
                            break;
                            
                          case SFBLEDeviceStateUnlinking:
                          case SFBLEDeviceStateUnlinked:
                            break;
                        }
                        );
}


- (void)linkingComplete
{
  self.state = SFBLEDeviceStateLinked;

  [self checkForAndSubscribeToBatteryCharacteristic];
  
  DISPATCH_ON_MAIN_QUEUE(
                         if (!self.shouldLink) {
                           DISPATCH_ON_BLE_QUEUE(
                                                 self.state = SFBLEDeviceStateUnlinking;
                                                 [self.centralDelegate cancelConnectionToDevice:self];
                                                 );
                         }
                         else {
                           [self.delegate deviceLinkedSuccessfully:self];
                         }
                         );
}


// Errors: connection CBError, connection timeout, discovery timeout,
//            discovery CBError
- (void)linkingFailed:(NSError*)SFError
{
  DDLogDebug(@"BLE-Device: linking failed");

  if (SFError)
    NSAssert([SFError.domain isEqualToString:[SFBLEDeviceFinder error:SFBluetoothSmartErrorUnknown].domain], @"Apple error leaking to outside");

  self.state = SFBLEDeviceStateUnlinked;
  DISPATCH_ON_MAIN_QUEUE(
                         if (self.shouldLink) {
                           self.shouldLink = NO;
                           [self.delegate device:self failedToLink:SFError];
                         }
  );
}


// Callers: no bluetooth, didDisconnectPeripheral,
- (void)disconnected:(NSError*)SFError
{
  DDLogDebug(@"BLE-Device: disconnected");

  if (SFError)
    NSAssert([SFError.domain isEqualToString:[SFBLEDeviceFinder error:SFBluetoothSmartErrorUnknown].domain], @"Apple error leaking to outside");
  
  switch (self.state) {
    case SFBLEDeviceStateLinking:
      self.state = SFBLEDeviceStateUnlinked;
      [self linkingFailed:SFError];
      break;
      
    case SFBLEDeviceStateLinked:
      self.state = SFBLEDeviceStateUnlinked;
      DISPATCH_ON_MAIN_QUEUE(
                             if (!self.shouldLink) {
                               return;
                             }
                             
                             self.shouldLink = NO;
                             [self.delegate device:self unlinked:SFError];
                             );
      break;
      
    case SFBLEDeviceStateUnlinking:
      self.state = SFBLEDeviceStateUnlinked;
      DISPATCH_ON_MAIN_QUEUE(
                             // -unlink has been called, and before the disconnect has been confirmed by the
                             // central manager -link was called.
                             if (self.shouldLink) {
                               DISPATCH_ON_BLE_QUEUE(
                                                     // If the link call that switched shouldLink to YES, happended after
                                                     // unlinking was set to NO. Then the linking already started!
                                                     if (self.state == SFBLEDeviceStateLinking) {
                                                       return;
                                                     }
                                                     else {
                                                       self.state = SFBLEDeviceStateLinking;
                                                       [self connect];
                                                     }
                                                     );
                             }
                             );
      break;
      
    case SFBLEDeviceStateUnlinked:
      break;
  }
}


- (void)bluetoothNotAvailable
{
  [self disconnected:[SFBLEDeviceFinder error:SFBluetoothSmartErrorNoBluetooth]];
//  [self.bleCentral cancelPeripheralConnection:device.peripheral];
}




#pragma mark -
#pragma mark Connecting


- (void)connect
{
  DDLogDebug(@"BLE-Device: starting connect to suitable peripheral: %@", self.peripheral);
  
  [self startConnectTimer];
  [self.centralDelegate connectToDevice:self];
}


- (void)startConnectTimer
{
  _connectTimeoutBlock = perform_block_after_delay(CONNECT_TIMEOUT, self.bleQueue, ^{
    [self connectTimedOut];
  });
}


- (void)invalidateConnectTimer
{
  if (_connectTimeoutBlock) {
    cancel_delayed_block(_connectTimeoutBlock);
    _connectTimeoutBlock = nil;
  }
}


- (void)connectTimedOut
{
  DDLogInfo(@"BLE-Device: connect timed out. Reporting error.");
  [self invalidateConnectTimer];
  // the connection does not time out automatically, we have to do this explicitly
  [self.centralDelegate cancelConnectionToDevice:self];
  
  [self linkingFailed:[SFBLEDeviceFinder error:SFBluetoothSmartErrorProblemsInConnectionProcess]];
}


- (void)didFailToConnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  NSAssert(peripheral == self.peripheral, @"Wrong peripheral");
  NSAssert(error, @"No error provided");
  
  DDLogInfo(@"BLE-Device: failed to connect to %@", self.peripheral.name);
  [self invalidateConnectTimer];
  
  NSError* sfError = nil;
  // TODO: filter out apple errors (you should be able to let SFBLEErrors through)
  if (error) {
    NSString* localizedDescription = [NSString stringWithFormat:@"%@: %@", @(error.code), error.localizedDescription];
    sfError = [SFBLEDeviceFinder error:SFBluetoothSmartErrorOtherCBError];
    sfError = [NSError errorWithDomain:sfError.domain code:sfError.code userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
  }
  
  [self linkingFailed:sfError];
}


- (void)didConnectPeripheral:(CBPeripheral*)peripheral
{
  NSAssert(peripheral == self.peripheral, @"Wrong peripheral");
  
  DDLogDebug(@"BLE-Device: connected to %@", self.peripheral.name);
  [self invalidateConnectTimer];
  
  self.peripheralDelegate = [SFBLEPeripheralDelegate peripheralDelegateWithServicesAndCharacteristics:self.servicesAndCharacteristics forDevice:self];
  [self.peripheralDelegate startDiscovering];
}





#pragma mark -
#pragma mark Connected


- (void)completedDiscovery
{
  DDLogInfo(@"BLE-Device: link up and running");
  [self linkingComplete];
}


- (void)discoveryTimedOut
{
  DDLogInfo(@"BLE-Device: discovery timed out. Reporting error.");
  // a connectToPeripheral: does not time out, we have to cancel explicitly
  [self.centralDelegate cancelConnectionToDevice:self];
  
  [self linkingFailed:[SFBLEDeviceFinder error:SFBluetoothSmartErrorProblemsInDiscoveryProcess]];
}


- (void)didDisconnectPeripheral:(CBPeripheral*)peripheral error:(NSError*)error;
{
  NSAssert(peripheral == self.peripheral, @"Wrong peripheral");
  
  // An often seen error, connects to the device and then times out the connection immediately,
  // while the services/characteristics discovery is still in progress
  [self.peripheralDelegate invalidateDiscoveryTimer];
  
  // TODO: filter out apple errors (it should be safe to let SFBLEErrors through)
  NSError* sfError = nil;
  if (error) {
    DDLogInfo(@"BLE-Device: disconnected from %@ with error (%@ %d: %@).", self.peripheral.name, error.domain, error.code, error.localizedDescription);
    
    if (error.code == CBErrorPeripheralDisconnected) {
      sfError = [SFBLEDeviceFinder error:SFBluetoothSmartErrorConnectionClosedByDevice];
    }
    else {
      NSString* localizedDescription = [NSString stringWithFormat:@"%@: %@", @(error.code), error.localizedDescription];
      sfError = [SFBLEDeviceFinder error:SFBluetoothSmartErrorOtherCBError];
      sfError = [NSError errorWithDomain:sfError.domain code:sfError.code userInfo:@{NSLocalizedDescriptionKey: localizedDescription}];
    }
  }
  else {
    DDLogDebug(@"BLE-Device: disconnected from %@", self.peripheral.name);
  }
  
  [self disconnected:sfError];
}




#pragma mark -
#pragma mark # Data Transfer


- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID
{
  DISPATCH_ON_BLE_QUEUE(
                        if (self.state != SFBLEDeviceStateLinked)
                        return;
                        
                        [self.peripheralDelegate readValueForCharacteristic:characteristicUUID];
                        );
}


- (void)writeValue:(NSData*)value forCharacteristic:(CBUUID*)characteristicUUID
{
  DISPATCH_ON_BLE_QUEUE(
                        if (self.state != SFBLEDeviceStateLinked)
                        return;
                        
                        [self.peripheralDelegate writeValue:value forCharacteristic:characteristicUUID];
                        );
}


- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID
{
  DISPATCH_ON_BLE_QUEUE(
                        if (self.state != SFBLEDeviceStateLinked)
                        return;
                        
                        [self.peripheralDelegate subscribeToCharacteristic:characteristicUUID];
                        );
}


- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID
{
  DISPATCH_ON_BLE_QUEUE(
                        if (self.state != SFBLEDeviceStateLinked)
                        return;
                        
                        [self.peripheralDelegate unsubscribeFromCharacteristic:characteristicUUID];
                        );
}


- (void)didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (self.state != SFBLEDeviceStateLinked)
    return;
  
  NSData* incomingData = characteristic.value;
  if ( (_batteryReadBlock || self.automaticBatteryNotify) && [characteristic.UUID isEqual:[CBUUID UUIDWithString:kBLECharBatteryLevel]]) {
    UInt8 batteryLevel = 0;
    [incomingData getBytes:&batteryLevel length:sizeof(batteryLevel)];
    DDLogDebug(@"BLE-Device: incoming battery level %d%%", batteryLevel);
    NSNumber* batteryLevelNum = @(batteryLevel);
    DISPATCH_ON_MAIN_QUEUE(if (self.shouldLink) self.batteryLevel = batteryLevelNum);
  }
  else {
    DDLogDebug(@"BLE-Device: incoming data via %@: %@", characteristic.UUID, incomingData);
    DISPATCH_ON_MAIN_QUEUE(
                           if (self.shouldLink) {
                             [self.delegate device:self receivedData:incomingData fromCharacteristic:characteristic.UUID];
                           }
                           );
  }
}


- (NSString*)name
{
  if (self.peripheral)
    return self.peripheral.name;
  else
    return nil;
}




# pragma mark -
# pragma mark Battery


- (void)checkForAndSubscribeToBatteryCharacteristic
{
  self.automaticBatteryNotify = NO;

  CBUUID* batteryServiceUUID = [CBUUID UUIDWithString:kBLEServiceBattery];
  CBUUID* batteryLevelCharacteristicUUID = [CBUUID UUIDWithString:kBLECharBatteryLevel];
  
  BOOL hasBatteryService = [self.servicesAndCharacteristics.allKeys containsObject:batteryServiceUUID];
  BOOL hasBatteryLevelCharacteristic = [self.servicesAndCharacteristics[batteryServiceUUID] containsObject:batteryLevelCharacteristicUUID];
  
  if (hasBatteryService && hasBatteryLevelCharacteristic)
  {
    CBCharacteristic* batteryLevelCharacteristic = [self.peripheralDelegate characteristic:batteryLevelCharacteristicUUID];
    
    BOOL batteryLevelCharacteristicSupportsIndication = (batteryLevelCharacteristic.properties & CBCharacteristicPropertyIndicate) != 0;
    BOOL batteryLevelCharacteristicSupportsNotification = (batteryLevelCharacteristic.properties & CBCharacteristicPropertyNotify) != 0;
    
    if (batteryLevelCharacteristicSupportsIndication || batteryLevelCharacteristicSupportsNotification)
    {
      DDLogInfo(@"BLE-Device: subscribing to battery characteristic");
      self.automaticBatteryNotify = YES;
      [self subscribeToCharacteristic:batteryLevelCharacteristicUUID];
      [self readValueForCharacteristic:[CBUUID UUIDWithString:kBLECharBatteryLevel]];
    }
    else {
      DDLogInfo(@"BLE-Device: beginning regular read of battery level");
      [self readBatteryLevelAndScheduleNext];
    }
  }
}


- (void)scheduleBatteryTimer
{
  _batteryReadBlock = perform_block_after_delay(BATTERY_READ_INTERVAL, self.bleQueue, ^{
    [self readBatteryLevelAndScheduleNext];
  });
}


- (void)invalidateBatteryTimer
{
  if (_batteryReadBlock) {
    cancel_delayed_block(_batteryReadBlock);
    _batteryReadBlock = nil;
  }
}


- (void)readBatteryLevelAndScheduleNext
{
  [self invalidateBatteryTimer];
  
  if (self.state == SFBLEDeviceStateLinked) {
    DDLogDebug(@"BLE-Device: scheduling battery level read");
    [self readValueForCharacteristic:[CBUUID UUIDWithString:kBLECharBatteryLevel]];
    [self scheduleBatteryTimer];
  }
}


/*
 TIMEOUT ERROR
 
 
 // TODO: this is copied from the manager, has to be adapted for here
 if (error) {
 // in case of a timeout, try a second time before reporting a failed attempt
 //    if (error.code == CBErrorConnectionTimeout && !self.connectionAttemptHasTimedOutBefore) {
 //      [self invalidateConnectTimer];
 //      NSLog(@"BLE-Manager: Connection has timed out. Trying a second time");
 //      self.connectionAttemptHasTimedOutBefore = YES;
 //      [self connectToSuitablePeripheral];
 //      return;
 //    }
 }
 
 
 */


@end


#undef DISPATCH_ON_MAIN_QUEUE
#undef DISPATCH_ON_BLE_QUEUE
#undef CONNECT_TIMEOUT



