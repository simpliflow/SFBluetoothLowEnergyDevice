//
//  SFBluetoothSmartDevice.m
//  SFBluetoothSmartDevice
//
//  Created by Thomas Billicsich on 14.01.14.
//  Copyright (c) 2014 SimpliFlow. All rights reserved.
//


#define DISPATCH_ON_MAIN_QUEUE(statement) \
dispatch_async(dispatch_get_main_queue(), ^{ \
statement; \
})
#define DISPATCH_ON_BLE_QUEUE(statement) \
dispatch_async(self.bleManagerQueue, ^{ \
statement; \
})

#define DISCOVERY_TIMEOUT 2.0
#define BATTERY_CHECK_TIME_INTERVAL 300.0



#import "SFBluetoothSmartDevice.h"
#import "SpacemanBlocks.h"

#import "ARAnalytics.h"


static NSString* kSFBluetoothSmartServiceBatteryUUID = @"180F";
static NSString* kSFBluetoothSmartCharacteristicBatteryLevelUUID = @"2A19";



@interface SFBluetoothSmartDevice () {
  __block SMDelayedBlockHandle _discoveryTimeoutBlock;
}

@property (nonatomic) BOOL linked;
@property (readwrite) NSUUID* identifier;
@property (readwrite) NSError* error;
@property (readwrite) UInt8 batteryLevel;

@property (nonatomic) SFBluetoothSmartDeviceManager* BLEManager;
@property (nonatomic, readonly) dispatch_queue_t bleManagerQueue;

@property (nonatomic) NSMutableDictionary* characteristicsByUUID;
@property (nonatomic) NSMutableDictionary* servicesByUUID;
@property (nonatomic) NSArray* advertisingServices;
@property (nonatomic) NSDictionary* servicesAndCharacteristics;
@property (nonatomic) CBPeripheral* peripheral;

@property (nonatomic) NSTimer* batteryTimer;

// This variable is set by the "outside" on the main thread
// it is the indication for the ble-queue to know if it should
// scan. Having this variable may lead to problems if it is YES
// and then set to NO and back to YES within a short time, as the
// shutting down of a scanning or connect process may not yet have
// finished.
// Currently this is mitigated by using unlinkWithBlock.
@property (atomic) BOOL shouldLink;
@end




@implementation SFBluetoothSmartDevice


#pragma Class Variables and Methods

static dispatch_queue_t __bleManagerQueue;

+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    [ARAnalytics setupGoogleAnalyticsWithID:@"UA-45282609-2"];
  });
}

+ (instancetype)BTSmartDeviceWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services
{
  return [[SFBluetoothSmartDevice alloc] initWithServicesAndCharacteristics:servicesAndCharacteristics advertising:services];
}




#pragma Public Methods


- (id)initWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services
{
  if (self = [super init]) {

    // Check
    //   * the keys of servicesAndCharacteristics
    //   * the elements within the arrays that are the values of servicesAndCharacteristics
    //   * the services that are expected to be advertised
    //  to be of the class CBUUID.
    NSArray* characteristics = [servicesAndCharacteristics.allValues valueForKeyPath:@"@unionOfArrays.self"];
    for (NSArray* shouldBeUUIDs in @[servicesAndCharacteristics.allKeys, characteristics, services]) {
      for (id shouldBeUUID in servicesAndCharacteristics.allKeys) {
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
    
    self.advertisingServices = services;
    _servicesAndCharacteristics = servicesAndCharacteristics;

    self.BLEManager = [SFBluetoothSmartDeviceManager deviceManager];
    self.BLEManager.delegate = self;
  }
  return self;
}




#pragma mark -
#pragma mark # Linking


#pragma mark -
#pragma mark General


- (void)linkWithIdentifier:(NSUUID*)identifier
{
  NSLog(@"BLE-Device: linking");
  self.identifier = identifier;
  DISPATCH_ON_BLE_QUEUE(self.shouldLink = YES; [self executeConnectDuties]);
}
- (void)executeConnectDuties
{
  self.servicesByUUID = [@{} mutableCopy];
  self.characteristicsByUUID = [@{} mutableCopy];
  [self.BLEManager search:self.identifier advertising:self.advertisingServices];
}


- (void)unlink
{
  NSLog(@"BLE-Device: unlinking");
  self.shouldLink = NO;
  DISPATCH_ON_BLE_QUEUE([self executeDisconnectDuties]);
}
- (void)unlinkWithBlock:(void (^) ())block
{
  [self unlink];
  dispatch_async(self.bleManagerQueue, block);
}
- (void)executeDisconnectDuties
{
  NSLog(@"BLE-Device: cancelling connection");
  [self.BLEManager cancelConnection];
  
  self.linked = NO;
}


- (void)setLinked:(BOOL)linked
{
  _linked = linked;
  
  if (!linked) {
    //    [self stopBatteryTimer];
    self.servicesByUUID = [@{} mutableCopy];
    self.characteristicsByUUID = [@{} mutableCopy];
    self.identifier = nil;
  }
  else {
    self.identifier = self.peripheral.identifier;
    _linked = linked;

    CBUUID* batteryServiceUUID = [CBUUID UUIDWithString:kSFBluetoothSmartServiceBatteryUUID];
    CBUUID* batteryLevelCharacteristicUUID = [CBUUID UUIDWithString:kSFBluetoothSmartCharacteristicBatteryLevelUUID];
    BOOL hasBatteryService = [self.servicesAndCharacteristics.allKeys containsObject:batteryServiceUUID];
    BOOL hasBatteryLevelCharacteristic = [self.servicesAndCharacteristics[batteryServiceUUID] containsObject:batteryLevelCharacteristicUUID];
    if (hasBatteryService && hasBatteryLevelCharacteristic) {
      CBCharacteristic* batteryLevelCharacteristic = self.characteristicsByUUID[batteryLevelCharacteristicUUID];
      BOOL batteryLevelCharacteristicSupportsIndication = (batteryLevelCharacteristic.properties & CBCharacteristicPropertyIndicate) != 0;
      if (batteryLevelCharacteristicSupportsIndication) {
        [self subscribeToCharacteristic:batteryLevelCharacteristicUUID];
      }
      else {
        //        [self readBatteryLevel:nil];
        //        [self startBatteryTimer];
      }
    }
    
    DISPATCH_ON_MAIN_QUEUE([self.delegate BTSmartDeviceConnectedSuccessfully:self]);
  }
}




#pragma mark -
#pragma mark Connecting


- (void)managerFailedToConnectToSuitablePeripheral:(CBPeripheral*)peripheral error:(NSError*)error
{
  NSLog(@"BLE-Device: central failed to connect");
  self.linked = NO;
  
  if (error.code == SFBluetoothSmartErrorUnableToDistinguishClosestDevice) {
    DISPATCH_ON_MAIN_QUEUE([self.delegate BTSmartDeviceEncounteredError:error]);
  }
  else {
    DISPATCH_ON_MAIN_QUEUE([self.delegate BTSmartDeviceEncounteredError:[SFBluetoothSmartDeviceManager error:SFBluetoothSmartErrorProblemsInConnectionProcess]]);
  }
}


- (void)managerConnectedToSuitablePeripheral:(CBPeripheral*)peripheral
{
  self.peripheral = peripheral;
  self.peripheral.delegate = self;
  [self startToDiscover];
}




#pragma mark -
#pragma mark Discovering


- (void)startToDiscover
{
  [self.peripheral discoverServices:[self.servicesAndCharacteristics allKeys]];
  [self startDiscoveryTimer];

}


- (void)startDiscoveryTimer
{
  _discoveryTimeoutBlock = perform_block_after_delay(DISCOVERY_TIMEOUT, self.bleManagerQueue, ^{
    [self discoveryTimedOut];
  });
}


- (void)invalidateDiscoveryTimer
{
  if (_discoveryTimeoutBlock) {
    cancel_delayed_block(_discoveryTimeoutBlock);
    _discoveryTimeoutBlock = nil;
  }
}


- (void)discoveryTimedOut
{
  NSLog(@"BLE-Device: Discovery timed out");
  [self invalidateDiscoveryTimer];
  [self executeDisconnectDuties];
}


- (void)peripheralDidDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error
{
  if (error) {
    NSLog(@"Error in characteristic disovery: %@ %@", [error localizedDescription], error);
    // TODO: Abort
    return;
  }
  
  self.servicesByUUID[service.UUID] = service;

  for (CBCharacteristic* characteristic in service.characteristics) {
    self.characteristicsByUUID[characteristic.UUID] = characteristic;
  }
  NSArray* charsOfService = self.servicesAndCharacteristics[service.UUID];
  if (charsOfService.count != service.characteristics.count) {
    // TODO: abort, inconsistency between discovered and prescribed characteristics in service
  }
  
  if (self.servicesByUUID.count == self.servicesAndCharacteristics.count) {
    [self completedDiscovery];
  }
}


- (void)completedDiscovery
{
  NSLog(@"BLE-Device: connect and discovery complete");
  [self invalidateDiscoveryTimer];
  self.linked = YES;
}


- (void)managerDisconnectedFromPeripheral:(CBPeripheral*)peripheral error:(NSError *)error
{
  NSLog(@"BLE-Device: central disconnected from peripheral");
  self.linked = NO;
  [self invalidateDiscoveryTimer];
  
  // TODO: this is copied from the manager, has to be adapted for here
  if (error) {
    // in case of a timeout, try a second time before reporting a failed attempt
//    if (error.code == 6 && !self.connectionAttemptHasTimedOutBefore) {
//      [self invalidateConnectTimer];
//      NSLog(@"BLE-Manager: Connection has timed out. Trying a second time");
//      self.connectionAttemptHasTimedOutBefore = YES;
//      [self connectToSuitablePeripheral];
//      return;
//    }
  }
  
  DISPATCH_ON_MAIN_QUEUE([self.delegate BTSmartDeviceEncounteredError:[SFBluetoothSmartDeviceManager error:SFBluetoothSmartErrorConnectionClosedByDevice]]);
}




#pragma mark -
#pragma mark # Data Transfer


# pragma mark -
# pragma mark General


- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID
{
  if (!self.linked)
    return;
  
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.peripheral readValueForCharacteristic:characteristic];
}


- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID
{
  if (!self.linked)
    return;
  
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
}


- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID
{
  if (!self.linked)
  return;
  
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.peripheral setNotifyValue:NO forCharacteristic:characteristic];
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


//- (void)startBatteryTimer
//{
//  DISPATCH_ON_MAIN_QUEUE(self.batteryTimer = [NSTimer scheduledTimerWithTimeInterval:BATTERY_CHECK_TIME_INTERVAL target:self selector:@selector(readBatteryLevel:) userInfo:nil repeats:YES])
//}
//
//
//- (void)stopBatteryTimer
//{
//  DISPATCH_ON_MAIN_QUEUE([self.batteryTimer invalidate];self.batteryTimer = nil;)
//}
//
//
//- (void)readBatteryLevel:(NSTimer*)timer
//{
//  if (!self.connected) {
//    [self stopBatteryTimer];
//    return;
//  }
//
//  [self readValueForCharacteristic:[CBUUID UUIDWithString:kSFBluetoothSmartCharacteristicBatteryLevelUUID]];
//}




#pragma Private Methods


- (dispatch_queue_t)bleManagerQueue
{
  return self.BLEManager.bleManagerQueue;
}


- (void)dealloc
{
  NSLog(@"BLE-Device: deallocating");
  if (self.linked)
    [self unlink];
}


#pragma mark SFBluetoothSmartDeviceManagerDelegate


- (void)bluetoothNotAvailable
{
  NSLog(@"BLE-Device: Bluetooth not available");
  if ([self.delegate respondsToSelector:@selector(noBluetooth)])
    DISPATCH_ON_MAIN_QUEUE([self.delegate noBluetooth]);
  
  [self executeDisconnectDuties];
}


- (void)bluetoothAvailableAgain
{
  NSLog(@"BLE-Device: Bluetooth no longer not available.");
  if ([self.delegate respondsToSelector:@selector(fixedNoBluetooth)])
    DISPATCH_ON_MAIN_QUEUE([self.delegate fixedNoBluetooth]);
}




#pragma mark -
#pragma mark CBPeripheralDelegate


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error
{
  NSAssert(self.shouldLink, @"Race condition");
  
  NSArray* services = peripheral.services;
  
  for (CBService* service in services) {
    NSArray* characteristicsToDiscover = self.servicesAndCharacteristics[service.UUID];
    [peripheral discoverCharacteristics:characteristicsToDiscover forService:service];
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error
{
  NSAssert(self.shouldLink, @"Race condition");
  
  [self peripheralDidDiscoverCharacteristicsForService:service error:error];
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  NSAssert(self.shouldLink, @"Race condition");
  
  if (error) {
    NSLog(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (!self.shouldLink)
    return;
  
  if (error) {
    NSLog(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
  
  NSData* incomingData = characteristic.value;
  
  if (self.batteryTimer && [characteristic.UUID isEqual:[CBUUID UUIDWithString:kSFBluetoothSmartCharacteristicBatteryLevelUUID]]) {
    UInt8 batteryLevel = 0;
    [incomingData getBytes:&batteryLevel length:sizeof(batteryLevel)];
    DISPATCH_ON_MAIN_QUEUE(self.batteryLevel = batteryLevel);
  }
  else {
    DISPATCH_ON_MAIN_QUEUE([self.delegate BTSmartDevice:self receivedData:incomingData fromCharacteristic:characteristic.UUID]);
  }
}


@end




#undef DISCOVERY_TIMEOUT
