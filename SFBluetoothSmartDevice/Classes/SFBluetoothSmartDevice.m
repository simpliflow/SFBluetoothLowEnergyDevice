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
});

#define FIND_TIME_OUT_INTERVAL 10.0
#define BATTERY_CHECK_TIME_INTERVAL 300.0



#import "SFBluetoothSmartDevice.h"

#import "ARAnalytics.h"


static NSString* kSFBluetoothSmartServiceBatteryUUID = @"180F";
static NSString* kSFBluetoothSmartCharacteristicBatteryLevelUUID = @"2A19";



@interface SFBluetoothSmartDevice ()
@property (readwrite) BOOL connected;
@property (readwrite) NSUUID* identifier;
@property (readwrite) NSError* error;
@property (readwrite) UInt8 batteryLevel;

@property (nonatomic) NSMutableDictionary* characteristicsByUUID;
@property (nonatomic) NSMutableDictionary* servicesByUUID;
@property (nonatomic) NSArray* advertisingServices;
@property (nonatomic) NSDictionary* servicesAndCharacteristics;
@property (nonatomic) CBPeripheral* peripheral;

@property (nonatomic) NSTimer* discoveryTimer;
@property (nonatomic) NSTimer* batteryTimer;

@property (atomic) BOOL shouldConnect;
@end




@implementation SFBluetoothSmartDevice


#pragma Class Variables and Methods

static SFBluetoothSmartDeviceManager* __deviceManager;
static dispatch_queue_t __bleManagerQueue;

+ (void)initialize
{
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    __deviceManager = [SFBluetoothSmartDeviceManager deviceManager];
    [ARAnalytics setupGoogleAnalyticsWithID:@"UA-45282609-2"];
  });
}

+ (instancetype)withTheseServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services andIdentifyingItselfWith:(NSUUID*)identifier
{
  return [[SFBluetoothSmartDevice alloc] initWithServicesAndCharacteristics:servicesAndCharacteristics advertising:services andIdentifier:identifier];
}




#pragma Public Methods


- (id)initWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics advertising:(NSArray*)services andIdentifier:(NSUUID*)identifier
{
  if (self = [super init]) {
    
    // Check
    //   * the keys of servicesAndCharacteristics
    //   * the elements within the arrays that are the values of servicesAndCharacteristics
    //   * the services that are expected to be advertised
    //  to be of the clas CBUUID.
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
    
    self.identifier = identifier;
    self.advertisingServices = services;
    _servicesAndCharacteristics = servicesAndCharacteristics;
    [__deviceManager find:self.identifier advertising:self.advertisingServices for:self];
    
    self.servicesByUUID = [@{} mutableCopy];
    self.characteristicsByUUID = [@{} mutableCopy];
    self.shouldConnect = YES;
  }
  return self;
}


- (void)disconnect
{
  NSLog(@"BLE-device is disconnecting");
  self.shouldConnect = NO;
  [__deviceManager cancelPeripheralConnection:self.peripheral];
}


- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID
{
  if (!self.connected)
    return;
  
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.peripheral readValueForCharacteristic:characteristic];
}


- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID
{
  if (!self.connected)
    return;
  
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.peripheral setNotifyValue:YES forCharacteristic:characteristic];
}


- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID
{
  if (!self.connected)
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




#pragma Private Methods


- (void)dealloc
{
  NSLog(@"Deallocating BLE device");
  if (self.connected)
    [self disconnect];
}


- (void)setConnected:(BOOL)connected
{
  _connected = connected;
  
  if (!connected) {
    [self stopBatteryTimer];
    self.servicesByUUID = [@{} mutableCopy];
    self.characteristicsByUUID = [@{} mutableCopy];
    self.identifier = nil;
  }
  else {
    self.identifier = self.peripheral.identifier;
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
        [self readBatteryLevel:nil];
        [self startBatteryTimer];
      }
    }
  }
}


- (void)startDiscoveryTimer
{
  DISPATCH_ON_MAIN_QUEUE(self.discoveryTimer = [NSTimer scheduledTimerWithTimeInterval:FIND_TIME_OUT_INTERVAL target:self selector:@selector(discoveryTimedOut:) userInfo:nil repeats:NO])
}


- (void)stopDiscoveryTimer
{
  DISPATCH_ON_MAIN_QUEUE([self.discoveryTimer invalidate]; self.discoveryTimer = nil;)
}


- (void)discoveryTimedOut:(NSTimer*)timer
{
  [self stopDiscoveryTimer];
}


- (void)startBatteryTimer
{
  DISPATCH_ON_MAIN_QUEUE(self.batteryTimer = [NSTimer scheduledTimerWithTimeInterval:BATTERY_CHECK_TIME_INTERVAL target:self selector:@selector(readBatteryLevel:) userInfo:nil repeats:YES])
}


- (void)stopBatteryTimer
{
  DISPATCH_ON_MAIN_QUEUE([self.batteryTimer invalidate];self.batteryTimer = nil;)
}


- (void)readBatteryLevel:(NSTimer*)timer
{
  if (!self.connected) {
    [self stopBatteryTimer];
    return;
  }
  
  [self readValueForCharacteristic:[CBUUID UUIDWithString:kSFBluetoothSmartCharacteristicBatteryLevelUUID]];
}



#pragma mark SFBluetoothSmartDeviceManagerDelegate


- (void)manager:(SFBluetoothSmartDeviceManager*)manager connectedToSuitablePeripheral:(CBPeripheral*)peripheral
{
  self.peripheral = peripheral;
  self.peripheral.delegate = self;
  [self.peripheral discoverServices:[self.servicesAndCharacteristics allKeys]];
  [self startDiscoveryTimer];
}


- (void)managerFailedToConnectToSuitablePeripheral:(SFBluetoothSmartDeviceManager*)manager
{
  DISPATCH_ON_MAIN_QUEUE(
                         self.connected = NO;
                         if (self.shouldConnect &&
                             (![self.delegate respondsToSelector:@selector(shouldContinueSearch)] || [self.delegate shouldContinueSearch])) {
                           [__deviceManager find:self.identifier advertising:self.advertisingServices for:self];
                         }
                         ) 
  NSLog( @"BLE-Device: manager failed to connect");
}


- (void)manager:(SFBluetoothSmartDeviceManager*)manager disconnectedFromPeripheral:(CBPeripheral*)peripheral
{
  DISPATCH_ON_MAIN_QUEUE(self.connected = NO);
  [self stopDiscoveryTimer];
  
  if (self.shouldConnect) {
    // TODO: refine error statement
    DISPATCH_ON_MAIN_QUEUE(self.error = [NSError errorWithDomain:@"BLEError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Error happened"}])
    [__deviceManager find:self.identifier advertising:self.advertisingServices for:self];
  }
}




#pragma mark CBPeripheralDelegate


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error
{
  NSArray* services = peripheral.services;
  
  for (CBService* service in services) {
    self.servicesByUUID[service.UUID] = service;
    NSArray* characteristicsToDiscover = self.servicesAndCharacteristics[service.UUID];
    [peripheral discoverCharacteristics:characteristicsToDiscover forService:service];
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error
{
  if (error) {
    NSLog(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
  
  for (CBCharacteristic* characteristic in service.characteristics) {
    self.characteristicsByUUID[characteristic.UUID] = characteristic;
  }
  
  if (self.servicesByUUID.count == self.servicesAndCharacteristics.count &&
      self.characteristicsByUUID.count == ((NSArray*)[self.servicesAndCharacteristics.allValues valueForKeyPath:@"@unionOfArrays.self"]).count) {
    [self stopDiscoveryTimer];
    NSLog(@"Connect and discovery complete");
    DISPATCH_ON_MAIN_QUEUE(self.connected = YES;)
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (error) {
    NSLog(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (error) {
    NSLog(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
  
  NSData* incomingData = characteristic.value;
  
  if (self.batteryTimer && [characteristic.UUID isEqual:[CBUUID UUIDWithString:kSFBluetoothSmartCharacteristicBatteryLevelUUID]]) {
    UInt8 batteryLevel = 0;
    [incomingData getBytes:&batteryLevel length:sizeof(batteryLevel)];
    DISPATCH_ON_MAIN_QUEUE(self.batteryLevel = batteryLevel)
  }
  else {
    DISPATCH_ON_MAIN_QUEUE([self.delegate BTSmartDevice:self receivedData:incomingData fromCharacteristic:characteristic.UUID];)
  }
}


@end
