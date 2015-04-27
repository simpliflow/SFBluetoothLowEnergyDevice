//
//  SFBLEPeripheralDelegate.m
//  SFBluetoothLowEnergyDevice
//
//  Created by Thomas Billicsich on 2014-01-13.
//  Copyright (c) 2014 Thomas Billicsich. All rights reserved.


#import "SFBLEPeripheralDelegate.h"
#import "SpacemanBlocks.h"
#import "SFBLELogging.h"
#import "SFBLEDeviceFinder.h"
#import "SFBLEDeviceFinderPrivate.h"
#import "SFBLEDevice.h"
#import "SFBLEDevicePrivate.h"


#define DISCOVERY_TIMEOUT 2.0

// Services
static NSString* kBleServiceHeartRate = @"180D";



@interface SFBLEPeripheralDelegate () {
  __block SMDelayedBlockHandle _discoveryTimeoutBlock;
}

@property (nonatomic, assign) SFBLEDevice* device;
@property (nonatomic) NSDictionary* servicesAndCharacteristics;

@property (nonatomic) NSMutableDictionary* characteristicsByUUID;
@property (nonatomic) NSMutableDictionary* servicesByUUID;

// Used during the linking process
@property (nonatomic) NSArray* discoveredServices;

@end






@implementation SFBLEPeripheralDelegate


+ (instancetype)peripheralDelegateWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics forDevice:(SFBLEDevice*)device
{
  return [[SFBLEPeripheralDelegate alloc] initWithServicesAndCharacteristics:servicesAndCharacteristics forDevice:device];
}
- (id)initWithServicesAndCharacteristics:(NSDictionary*)servicesAndCharacteristics forDevice:(SFBLEDevice*)device
{
  if (self = [super init]) {
    // No need to check here, as it has already been checked on SFBLEDeviceFinder-init
    _servicesAndCharacteristics = servicesAndCharacteristics;
    _device = device;
    device.peripheral.delegate = self;
  }
  return self;
}


- (CBCharacteristic*)characteristic:(CBUUID*)characteristicUUID
{
  return self.characteristicsByUUID[characteristicUUID];
}


- (CBService*)service:(CBUUID*)serviceUUID
{
  return self.servicesByUUID[serviceUUID];
}


- (NSMutableDictionary*) incomingServiceByUUID
{
  return self.servicesByUUID;
}



#pragma mark -
#pragma mark Discovering


- (void)startDiscovering
{
  self.characteristicsByUUID = [@{} mutableCopy];
  self.servicesByUUID = [@{} mutableCopy];
  [self.device.peripheral discoverServices:self.servicesAndCharacteristics.allKeys];
  [self startDiscoveryTimer];
}


- (void)startDiscoveryTimer
{
  _discoveryTimeoutBlock = perform_block_after_delay(DISCOVERY_TIMEOUT, [SFBLEDeviceFinder bleQueue], ^{
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
  DDLogDebug(@"BLE-PeripheralDelegate: discovery timed out");
  [self invalidateDiscoveryTimer];
  [self.device discoveryTimedOut];
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverServices:(NSError*)error
{
  self.discoveredServices = peripheral.services;
  
  for (CBService* service in self.discoveredServices) {
    NSArray* characteristicsToDiscover = self.servicesAndCharacteristics[service.UUID];
//    DDLogDebug(@"BLE-PeripheralDelegate: starting characteristic discovery for service %@: %@", service.UUID, [[characteristicsToDiscover valueForKeyPath:@"description"] componentsJoinedByString:@", "]);
    [peripheral discoverCharacteristics:characteristicsToDiscover forService:service];
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didDiscoverCharacteristicsForService:(CBService*)service error:(NSError*)error
{
  if (error) {
    DDLogInfo(@"BLE-PeripheralDelegate: error in characteristic discovery: %@ %@", [error localizedDescription], error);
    return;
  }
  
//  DDLogDebug(@"BLE-PeripheralDelegate: did discover all characteristics for service %@", service.UUID);

  self.servicesByUUID[service.UUID] = service;
  
  for (CBCharacteristic* characteristic in service.characteristics) {
    self.characteristicsByUUID[characteristic.UUID] = characteristic;
  }
  NSArray* charsOfService = self.servicesAndCharacteristics[service.UUID];
  
  if (charsOfService && charsOfService.count && charsOfService.count > service.characteristics.count) {
    NSArray* missingServices = [charsOfService filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF IN %@)", [service.characteristics valueForKeyPath:@"UUID"]]];
    DDLogWarn(@"BLE-PeripheralDelegate: inconsistency in characteristics discovery for service %@. Searched for %d, discovered only %d (missing: %@)", service.UUID, charsOfService.count, service.characteristics.count, [missingServices componentsJoinedByString:@", "]);
  }
  
  if (self.servicesByUUID.count == self.servicesAndCharacteristics.count) {
    [self completedDiscovery];
  }
  // if the services were provided, but the characterstics were not
  else if (self.servicesByUUID.count == self.servicesAndCharacteristics.count && !charsOfService.count) {
    [self completedDiscovery];
  }
  else if (!self.servicesAndCharacteristics && self.servicesByUUID.count == self.discoveredServices.count) {
    [self completedDiscovery];
  }
  //viiiiva belts do not have battery characteristic => serviceByUUID will only contain heartrate
  else if([self.servicesByUUID.allKeys containsObject:[CBUUID UUIDWithString:kBleServiceHeartRate]] && self.servicesByUUID.count == 1) {
    [self completedDiscovery];
  }
}


- (void)completedDiscovery
{
  [self invalidateDiscoveryTimer];
  [self.device completedDiscovery];
}




#pragma mark -
#pragma mark Data Transmission


- (void)readValueForCharacteristic:(CBUUID*)characteristicUUID
{
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral readValueForCharacteristic:characteristic];
}


- (void)writeValue:(NSData*)value forCharacteristic:(CBUUID*)characteristicUUID
{
  // TODO: allow for both types of writing (w/ and w/o response)
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}

- (void)writeValueWithoutResponse:(NSData*)value forCharacteristic:(CBUUID*)characteristicUUID
{
  // TODO: allow for both types of writing (w/ and w/o response)
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
}


- (void)subscribeToCharacteristic:(CBUUID*)characteristicUUID
{
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral setNotifyValue:YES forCharacteristic:characteristic];
}


- (void)unsubscribeFromCharacteristic:(CBUUID*)characteristicUUID
{
  CBCharacteristic* characteristic = self.characteristicsByUUID[characteristicUUID];
  [self.device.peripheral setNotifyValue:NO forCharacteristic:characteristic];
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (error) {
    DDLogWarn(@"BLE-PeripheralDelegate: updated notification state of %@ with error: %@", characteristic, error);
    return;
  }
}


- (void)peripheral:(CBPeripheral*)peripheral didUpdateValueForCharacteristic:(CBCharacteristic*)characteristic error:(NSError*)error
{
  if (error) {
    DDLogWarn(@"error: %@ %@", [error localizedDescription], error);
    return;
  }
  
  [self.device didUpdateValueForCharacteristic:characteristic error:error];
}


- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral
{
  DDLogDebug(@"peripheralDidUpdateName: %@", peripheral);
}


@end


#undef DISCOVERY_TIMEOUT
